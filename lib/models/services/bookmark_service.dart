import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/discussion_post.dart';
import '../entities/student_proposal.dart';

class BookmarkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> addBookmark({
    required String userId,
    required String itemId,
    required String itemType,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('bookmarks')
            .doc(itemId)
            .set({
          'itemId': itemId,
          'type': itemType,
          'dateBookmarked': FieldValue.serverTimestamp(),
        });
        return;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          retryCount++;
          if (retryCount == maxRetries) {
            rethrow; // Rethrow after max retries for bookmarking
          }
          
          await Future.delayed(Duration(seconds: 1 << (retryCount - 1)));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> removeBookmark({
    required String userId,
    required String itemId,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('bookmarks')
            .doc(itemId)
            .delete();
        return;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          retryCount++;
          if (retryCount == maxRetries) {
            rethrow; // Rethrow after max retries for unbookmarking
          }
          
          await Future.delayed(Duration(seconds: 1 << (retryCount - 1)));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<bool> isBookmarked({
    required String userId,
    required String itemId,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('bookmarks')
            .doc(itemId)
            .get();
        
        return doc.exists;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          retryCount++;
          if (retryCount == maxRetries) {
            // If we've exhausted all retries, return false as a safe default
            return false;
          }
          
          // Wait with exponential backoff before retrying
          // 1st retry: 1 second, 2nd retry: 2 seconds, 3rd retry: 4 seconds
          final waitTime = Duration(seconds: 1 << (retryCount - 1));
          await Future.delayed(waitTime);
          continue;
        }
        
        // For other Firebase errors, rethrow
        rethrow;
      } catch (e) {
        // For non-Firebase errors, rethrow
        rethrow;
      }
    }
    
    // If we somehow get here, return false as a safe default
    return false;
  }

  Stream<List<Map<String, dynamic>>> getUserBookmarks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .snapshots()
        .handleError((error) {
          if (error is FirebaseException && error.code == 'unavailable') {
            // For streams, we'll retry with a delay using Stream.periodic
            return Stream.periodic(const Duration(seconds: 2))
              .take(3) // Try 3 times
              .asyncExpand((_) {
                return _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('bookmarks')
                    .snapshots();
              });
          }
          throw error; // Rethrow other errors
        })
        .asyncMap((snapshot) async {
          final bookmarks = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final itemId = data['itemId'] as String;
            final type = data['type'] as String;
            final dateBookmarked = (data['dateBookmarked'] as Timestamp).toDate();

            // Add retry mechanism for fetching individual items
            int retryCount = 0;
            const maxRetries = 3;
            
            while (retryCount < maxRetries) {
              try {
                // Fetch the actual item based on type
                if (type == 'discussion') {
                  final discussionDoc = await _firestore
                      .collection('discussions')
                      .doc(itemId)
                      .get();
                  
                  if (discussionDoc.exists) {
                    final discussion = DiscussionPost.fromMap(discussionDoc);
                    
                    bookmarks.add({
                      'type': type,
                      'item': discussion,
                      'dateBookmarked': dateBookmarked,
                    });
                  }
                  break; // Success, exit retry loop
                } else if (type == 'proposal') {
                  final proposalDoc = await _firestore
                      .collection('proposals')
                      .doc(itemId)
                      .get();
                  
                  if (proposalDoc.exists) {
                    final proposal = StudentProposal.fromMap({
                      'id': proposalDoc.id,
                      ...proposalDoc.data() ?? {},
                    });
                    
                    bookmarks.add({
                      'type': type,
                      'item': proposal,
                      'dateBookmarked': dateBookmarked,
                    });
                  }
                  break; // Success, exit retry loop
                }
              } on FirebaseException catch (e) {
                if (e.code == 'unavailable') {
                  retryCount++;
                  if (retryCount == maxRetries) break; // Skip this item after max retries
                  
                  await Future.delayed(Duration(seconds: 1 << (retryCount - 1)));
                  continue;
                }
                rethrow;
              }
            }
          }

          return bookmarks;
        });
  }
}