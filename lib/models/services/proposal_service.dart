import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter/foundation.dart';
import '../entities/student_proposal.dart';
import 'sentiment_analysis_service.dart';

class ProposalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SentimentAnalysisService _sentimentService = SentimentAnalysisService();

  Future<String> createProposal({
    required String authorId,
    required String title,
    required Delta content,
    required String plainContent,
    required String authorName,
    required String authorClass,
    required String authorAvatar,
    required ProposalTier tier,
  }) async {
    try {
      // Analyze sentiment
      Map<String, dynamic>? sentimentData;
      try {
        final response = await _sentimentService.analyzeSentiment(plainContent);
        final documentSentiment = response['documentSentiment'];
        sentimentData = {
          'sentimentScore': documentSentiment['score'],
          'sentimentMagnitude': documentSentiment['magnitude'],
        };
      } catch (e) {
        if (kDebugMode) {
          print('Failed to analyze sentiment: $e');
        }
        // Continue without sentiment data
      }

      final proposalDoc = await _firestore.collection('proposals').add({
        'authorId': authorId,
        'authorName': authorName,
        'authorClass': authorClass,
        'authorAvatar': authorAvatar,
        'title': title,
        'content': content.toJson(),
        'plainContent': plainContent,
        'datePosted': FieldValue.serverTimestamp(),
        'currentSignatures': 0,
        'requiredSignatures': tier.requiredSignatures,
        'commentCount': 0,
        'endorserIds': [],
        'tier': tier.name,
        if (sentimentData != null) ...sentimentData,
      });

      return proposalDoc.id;
    } catch (e) {
      throw Exception('Failed to create proposal: $e');
    }
  }

  Stream<List<StudentProposal>> getProposals({int limit = 10, DocumentSnapshot? startAfter}) {
    Query query = _firestore
        .collection('proposals')
        .where('deleted', isEqualTo: null)  // Only get non-deleted proposals
        .orderBy('datePosted', descending: true)
        .limit(limit);
        
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentProposal.fromMap({
          'id': doc.id,
          ...data, // Now we know it's a Map<String, dynamic>
        });
      }).toList();
    });
  }

  Future<StudentProposal?> getProposal(String id) async {
    final doc = await _firestore.collection('proposals').doc(id).get();
    if (!doc.exists) return null;
    
    final data = doc.data() as Map<String, dynamic>;
    return StudentProposal.fromMap({
      'id': doc.id,
      ...data,
    });
  }

  Future<void> endorseProposal(String proposalId, String userId) async {
    final proposalRef = _firestore.collection('proposals').doc(proposalId);

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(proposalRef);
        if (!doc.exists) throw Exception('Proposal not found');

        final endorserIds = List<String>.from(doc.data()?['endorserIds'] ?? []);
        if (endorserIds.contains(userId)) {
          throw Exception('Already endorsed');
        }

        endorserIds.add(userId);
        transaction.update(proposalRef, {
          'endorserIds': endorserIds,
          'currentSignatures': FieldValue.increment(1),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Handle offline case
        debugPrint('Offline: Endorsement will be synced when back online');
        
        // Get the proposal from cache if possible
        final doc = await proposalRef.get(const GetOptions(source: Source.cache));
        if (!doc.exists) {
          throw Exception('Cannot endorse while offline: Proposal not found in cache');
        }

        final endorserIds = List<String>.from(doc.data()?['endorserIds'] ?? []);
        if (endorserIds.contains(userId)) {
          throw Exception('Already endorsed');
        }
        
        // The actual update will happen when back online via Firebase's offline persistence
        await proposalRef.update({
          'endorserIds': FieldValue.arrayUnion([userId]),
          'currentSignatures': FieldValue.increment(1),
        });
      } else {
        throw Exception('Failed to endorse proposal: $e');
      }
    }
  }

  Future<void> removeEndorsement(String proposalId, String userId) async {
    final proposalRef = _firestore.collection('proposals').doc(proposalId);

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(proposalRef);
        if (!doc.exists) throw Exception('Proposal not found');

        final endorserIds = List<String>.from(doc.data()?['endorserIds'] ?? []);
        if (!endorserIds.contains(userId)) {
          throw Exception('Not endorsed yet');
        }

        endorserIds.remove(userId);
        transaction.update(proposalRef, {
          'endorserIds': endorserIds,
          'currentSignatures': FieldValue.increment(-1),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Handle offline case
        debugPrint('Offline: Endorsement removal will be synced when back online');
        
        // Get the proposal from cache if possible
        final doc = await proposalRef.get(const GetOptions(source: Source.cache));
        if (!doc.exists) {
          throw Exception('Cannot remove endorsement while offline: Proposal not found in cache');
        }

        final endorserIds = List<String>.from(doc.data()?['endorserIds'] ?? []);
        if (!endorserIds.contains(userId)) {
          throw Exception('Not endorsed yet');
        }
        
        // The actual update will happen when back online via Firebase's offline persistence
        await proposalRef.update({
          'endorserIds': FieldValue.arrayRemove([userId]),
          'currentSignatures': FieldValue.increment(-1),
        });
      } else {
        throw Exception('Failed to remove endorsement: $e');
      }
    }
  }

  Future<void> deleteProposal(String proposalId) async {
    try {
      final proposalRef = _firestore.collection('proposals').doc(proposalId);
      
      // For regular users deleting their own proposals
      await _firestore.runTransaction((transaction) async {
        // Get proposal to check if it exists
        final doc = await transaction.get(proposalRef);
        if (!doc.exists) {
          throw Exception('Proposal not found');
        }

        // Delete the proposal document
        transaction.delete(proposalRef);

        // Get and delete comments
        final commentsDocs = await proposalRef.collection('comments').get();
        for (var commentDoc in commentsDocs.docs) {
          transaction.delete(commentDoc.reference);
        }
      });
    } catch (e) {
      throw Exception('Failed to delete proposal: $e');
    }
  }

  Future<void> voteComment(String proposalId, String commentId, bool isUpvote, String userId) async {
    final commentRef = _firestore
        .collection('proposals')
        .doc(proposalId)
        .collection('comments')
        .doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(commentRef);
      if (!doc.exists) throw Exception('Comment not found');

      final upvoterIds = List<String>.from(doc.data()?['upvoterIds'] ?? []);
      final downvoterIds = List<String>.from(doc.data()?['downvoterIds'] ?? []);

      // Remove existing vote if any
      upvoterIds.remove(userId);
      downvoterIds.remove(userId);

      // Add new vote
      if (isUpvote) {
        upvoterIds.add(userId);
      } else {
        downvoterIds.add(userId);
      }

      transaction.update(commentRef, {
        'upvoterIds': upvoterIds,
        'downvoterIds': downvoterIds,
        'upvotes': upvoterIds.length,
        'downvotes': downvoterIds.length,
      });
    });
  }

  Future<void> addComment(
    String proposalId, 
    String comment, 
    String userId, 
    String userName, 
    String userClass, 
    String userAvatar
  ) async {
    final commentsRef = _firestore.collection('proposals').doc(proposalId).collection('comments');
    final proposalRef = _firestore.collection('proposals').doc(proposalId);

    try {
      // Analyze sentiment
      final sentimentData = await _sentimentService.analyzeSentiment(comment);
      final documentSentiment = sentimentData['documentSentiment'];
      final score = documentSentiment['score']?.toDouble() ?? 0.0;
      final magnitude = documentSentiment['magnitude']?.toDouble() ?? 0.0;

      await _firestore.runTransaction((transaction) async {
        await commentsRef.add({
          'authorId': userId,
          'authorName': userName,
          'authorClass': userClass,
          'authorAvatar': userAvatar,
          'content': comment,
          'datePosted': FieldValue.serverTimestamp(),
          'upvotes': 0,
          'downvotes': 0,
          'upvoterIds': [],
          'downvoterIds': [],
          'sentimentScore': score,
          'sentimentMagnitude': magnitude,
        });

        transaction.update(proposalRef, {
          'commentCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      // If sentiment analysis fails, still add the comment without sentiment data
      await _firestore.runTransaction((transaction) async {
        await commentsRef.add({
          'authorId': userId,
          'authorName': userName,
          'authorClass': userClass,
          'authorAvatar': userAvatar,
          'content': comment,
          'datePosted': FieldValue.serverTimestamp(),
          'upvotes': 0,
          'downvotes': 0,
          'upvoterIds': [],
          'downvoterIds': [],
        });

        transaction.update(proposalRef, {
          'commentCount': FieldValue.increment(1),
        });
      });
    }
  }

  // Add method to get comment count
  Stream<int> getCommentCount(String proposalId) {
    return _firestore
        .collection('proposals')
        .doc(proposalId)
        .collection('comments')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<void> deleteComment(String proposalId, String commentId) async {
    await _firestore
        .collection('proposals')
        .doc(proposalId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // Get all proposals for admin view
  Future<List<StudentProposal>> getAllProposals() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('proposals')
          .orderBy('datePosted', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentProposal.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to load proposals: $e');
    }
  }

  // Answer a proposal (admin only)
  Future<void> answerProposal({
    required String proposalId,
    required Delta answer,
    required String plainAnswer,
    required String adminId,
    required String adminName,
  }) async {
    try {
      final proposalRef = _firestore.collection('proposals').doc(proposalId);
      
      await proposalRef.update({
        'answer': {'ops': answer.toJson()},
        'plainAnswer': plainAnswer,
        'answeredAt': FieldValue.serverTimestamp(),
        'answeredBy': adminId,
        'answeredByName': adminName,
      });
    } catch (e) {
      throw Exception('Failed to answer proposal: $e');
    }
  }
}
