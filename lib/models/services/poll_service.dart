import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../entities/poll.dart';
import 'package:rxdart/rxdart.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'polls';

  // Helper function to map snapshot to List<Poll>
  List<Poll> _mapSnapshotToPolls(QuerySnapshot snapshot) {
    try {
      return snapshot.docs
          .map((doc) {
            try {
              return Poll.fromFirestore(doc);
            } catch (e) {
              if (kDebugMode) {
                print('Error converting poll doc ${doc.id}: $e');
              }
              return null;
            }
          })
          .whereType<Poll>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error processing poll snapshot: $e');
      }
      return <Poll>[];
    }
  }

  // Create a new poll
  Future<String> createPoll(Poll poll) async {
    final docRef = await _firestore.collection(_collection).add(poll.toMap());
    return docRef.id;
  }

  // Get all polls (conditionally scoped)
  Stream<List<Poll>> getAllPolls({
    List<String>? classScopes,
    bool fetchAllForAdmin = false, // New parameter
  }) {
    try {
      Query baseQuery = _firestore.collection(_collection); // No orderBy here initially

      Stream<List<Poll>> resultStream;

      if (fetchAllForAdmin) {
        // Admin: Fetch all polls, no class scoping
        resultStream = baseQuery.snapshots().map(_mapSnapshotToPolls);
      } else {
        // Non-admin (mobile user): Apply class scoping
        Query queryForAllClasses = baseQuery.where('isAllClasses', isEqualTo: true);

        if (classScopes != null && classScopes.isNotEmpty) {
          Query queryForSpecificClasses = baseQuery
              .where('isAllClasses', isEqualTo: false)
              .where('classScopes', arrayContainsAny: classScopes);

          resultStream = Rx.combineLatest2(
            queryForAllClasses.snapshots().map(_mapSnapshotToPolls),
            queryForSpecificClasses.snapshots().map(_mapSnapshotToPolls),
            (List<Poll> allClassPolls, List<Poll> specificClassPolls) {
              // Combine and deduplicate
              final Map<String, Poll> pollMap = {};
              for (var poll in allClassPolls) {
                pollMap[poll.id] = poll;
              }
              for (var poll in specificClassPolls) {
                pollMap[poll.id] = poll; 
              }
              return pollMap.values.toList();
            },
          );
        } else {
          // User has no specific classes, or classScopes is null/empty,
          // so only fetch polls marked 'isAllClasses = true'
          resultStream = queryForAllClasses.snapshots().map(_mapSnapshotToPolls);
        }
      }

      return resultStream
          .map((polls) {
            // Sort all polls by expiresAt descending before returning
            polls.sort((a, b) => b.expiresAt.compareTo(a.expiresAt)); 
            return polls;
          })
          .handleError((e) {
            if (kDebugMode) {
              print('Error in poll stream processing: $e');
            }
            return <Poll>[];
          });

    } catch (e) {
      if (kDebugMode) {
        print('Error setting up poll stream: $e');
      }
      return Stream.value(<Poll>[]);
    }
  }

  // Get all polls (legacy, might be used elsewhere - keep for now or refactor usage)
  Stream<List<Poll>> getPolls({List<String>? classScopes}) {
    Query query = _firestore.collection(_collection)
        .orderBy('createdAt', descending: true);
    
    if (classScopes != null && classScopes.isNotEmpty) {
      query = query.where('isAllClasses', isEqualTo: false)
                  .where('classScopes', arrayContainsAny: classScopes);
      // This original getPolls method doesn't correctly fetch 'isAllClasses = true' polls
      // when classScopes are provided. It should ideally use logic similar to getAllPolls.
      // For now, leaving as is, but flagging for potential review if it's still used.
    } else {
      // If no classScopes, it might implicitly fetch all or only those with isAllClasses=true
      // depending on Firestore rules or lack of isAllClasses filter.
      // The new getAllPolls is more explicit.
    }

    return query.snapshots().map(_mapSnapshotToPolls).handleError((e) {
      if (kDebugMode) { print('Error in getPolls stream: $e'); }
      return <Poll>[];
    });
  }

  // Get active polls
  Stream<List<Poll>> getActivePolls({List<String>? classScopes}) {
    // This method also needs to be updated to use the fetchAllForAdmin logic if it's intended
    // to be used by both admin and user contexts with different scoping.
    // For now, assuming it uses user-specific scoping.
    Query query = _firestore.collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()));
        // No orderBy here, will be applied after potential merge

    Query queryForAllClasses = query.where('isAllClasses', isEqualTo: true);
    
    Stream<List<Poll>> resultStream;

    if (classScopes != null && classScopes.isNotEmpty) {
      Query queryForSpecificClasses = query
          .where('isAllClasses', isEqualTo: false)
          .where('classScopes', arrayContainsAny: classScopes);
      
      resultStream = Rx.combineLatest2(
        queryForAllClasses.snapshots().map(_mapSnapshotToPolls),
        queryForSpecificClasses.snapshots().map(_mapSnapshotToPolls),
        (List<Poll> allClassPolls, List<Poll> specificClassPolls) {
          final Map<String, Poll> pollMap = {};
          for (var poll in allClassPolls) { pollMap[poll.id] = poll; }
          for (var poll in specificClassPolls) { pollMap[poll.id] = poll; }
          return pollMap.values.toList();
        },
      );
    } else {
      resultStream = queryForAllClasses.snapshots().map(_mapSnapshotToPolls);
    }
    
    return resultStream.map((polls) {
      polls.sort((a, b) => a.expiresAt.compareTo(b.expiresAt)); // Active polls sorted by soonest expiry
      return polls;
    }).handleError((e) {
      if (kDebugMode) { print('Error in getActivePolls stream: $e'); }
      return <Poll>[];
    });
  }

  // Get a specific poll
  Stream<Poll?> getPoll(String pollId) {
    return _firestore.collection(_collection)
        .doc(pollId)
        .snapshots()
        .map((doc) => doc.exists ? Poll.fromFirestore(doc) : null);
  }

  // Vote in a poll
  Future<void> vote(String pollId, String userId, String optionId) async {
    await _firestore.collection(_collection).doc(pollId).update({
      'votes.$userId': {
        'optionId': optionId,
        'timestamp': FieldValue.serverTimestamp(),
      },
    });
  }

  // Unvote in a poll
  Future<void> unvote(String pollId, String userId) async {
    await _firestore.collection(_collection).doc(pollId).update({
      'votes.$userId': FieldValue.delete(),
    });
  }

  // Toggle real-time results visibility
  Future<void> toggleRealTimeResults(String pollId, bool showResults) async {
    await _firestore.collection(_collection).doc(pollId).update({
      'showRealTimeResults': showResults,
    });
  }

  // Toggle results visibility after poll ends
  Future<void> toggleResultsAfterEnd(String pollId, bool showResults) async {
    await _firestore.collection(_collection).doc(pollId).update({
      'showResultsAfterEnd': showResults,
    });
  }

  // Update poll expiry date
  Future<void> updatePollExpiryDate(String pollId, DateTime newExpiryDate) async {
    await _firestore.collection(_collection).doc(pollId).update({
      'expiresAt': Timestamp.fromDate(newExpiryDate),
    });
  }

  // Delete a poll
  Future<void> deletePoll(String pollId) async {
    await _firestore.collection(_collection).doc(pollId).delete();
  }

  // Get active polls as a one-time snapshot
  Future<QuerySnapshot> getActivePollsSnapshot({List<String>? classScopes}) async {
    Query query = _firestore.collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt');

    // First get all polls that are available to all classes
    final allClassesQuery = query.where('isAllClasses', isEqualTo: true);
    
    // If user has classes, also get polls specific to those classes
    if (classScopes != null && classScopes.isNotEmpty) {
      final classSpecificQuery = query
          .where('isAllClasses', isEqualTo: false)
          .where('classScopes', arrayContainsAny: classScopes);
      
      // Get both snapshots
      final allClassesSnapshot = await allClassesQuery.get();
      final classSpecificSnapshot = await classSpecificQuery.get();
      
      // Merge the results
      return QuerySnapshotMerger.merge([allClassesSnapshot, classSpecificSnapshot]);
    }
    
    // If no classes, just return polls available to all
    return allClassesQuery.get();
  }

  Stream<Poll?> getPollStream(String pollId) {
    return _firestore.collection(_collection)
        .doc(pollId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          try {
            return Poll.fromMap(doc.data()!..['id'] = doc.id);
          } catch (e) {
            if (kDebugMode) {
              print('Error converting single poll doc ${doc.id}: $e');
            }
            return null;
          }
        });
  }
}

// Helper class to merge QuerySnapshots
class QuerySnapshotMerger {
  static QuerySnapshot merge(List<QuerySnapshot> snapshots) {
    final allDocs = snapshots.expand((s) => s.docs).toList();
    return _MergedQuerySnapshot(allDocs);
  }
}

class _MergedQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;
  
  _MergedQuerySnapshot(this._docs);
  
  @override
  List<QueryDocumentSnapshot<Object?>> get docs => _docs;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}