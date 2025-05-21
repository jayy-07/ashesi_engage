import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../entities/discussion_post.dart';
import '../entities/discussion_comment.dart';
import 'sentiment_analysis_service.dart';

class DiscussionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _sentimentService = SentimentAnalysisService();

  Future<String> createDiscussion({
    required String authorId,
    required String content,
    required Delta contentDelta,
    required String authorName,
    required String authorClass,
    required String authorAvatar,
  }) async {
    try {
      // Analyze sentiment
      Map<String, dynamic>? sentimentData;
      try {
        final response = await _sentimentService.analyzeSentiment(content);
        final documentSentiment = response['documentSentiment'];
        sentimentData = {
          'sentimentScore': documentSentiment['score'],
          'sentimentMagnitude': documentSentiment['magnitude'],
        };
      } catch (e) {
        debugPrint('Failed to analyze sentiment: $e');
        // Continue without sentiment data
      }

      final discussionDoc = await _firestore.collection('discussions').add({
        'authorId': authorId,
        'authorName': authorName,
        'authorClass': authorClass,
        'authorAvatar': authorAvatar,
        'content': contentDelta.toJson(),
        'plainContent': content,
        'datePosted': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'downvotes': 0,
        'replyCount': 0,
        'upvoterIds': [],
        'downvoterIds': [],
        if (sentimentData != null) ...sentimentData,
      });

      return discussionDoc.id;
    } catch (e) {
      throw Exception('Failed to create discussion: $e');
    }
  }

  Stream<List<DiscussionPost>> getDiscussions({int limit = 10, DocumentSnapshot? startAfter}) {
    Query query = _firestore
        .collection('discussions')
        .orderBy('datePosted', descending: true)
        .limit(limit);
        
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DiscussionPost.fromMap(doc)).toList();
    });
  }

  Future<void> voteDiscussion(String discussionId, bool isUpvote, String userId) async {
    final discussionRef = _firestore.collection('discussions').doc(discussionId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(discussionRef);
      if (!doc.exists) throw Exception('Discussion not found');

      final upvoterIds = List<String>.from(doc.data()?['upvoterIds'] ?? []);
      final downvoterIds = List<String>.from(doc.data()?['downvoterIds'] ?? []);

      // Remove existing votes
      upvoterIds.remove(userId);
      downvoterIds.remove(userId);

      // Add new vote
      if (isUpvote) {
        upvoterIds.add(userId);
      } else {
        downvoterIds.add(userId);
      }

      transaction.update(discussionRef, {
        'upvoterIds': upvoterIds,
        'downvoterIds': downvoterIds,
      });
    });
  }

  Future<void> deleteDiscussion(String discussionId) async {
    try {
      // Delete all comments associated with this discussion first
      final commentsQuery = await _firestore
          .collection('comments')
          .where('discussionId', isEqualTo: discussionId)
          .get();
      
      for (final doc in commentsQuery.docs) {
        await doc.reference.delete();
      }

      // Then delete the discussion itself
      await _firestore.collection('discussions').doc(discussionId).delete();
    } catch (e) {
      throw Exception('Failed to delete discussion: $e');
    }
  }

  Future<String> createComment({
    required String discussionId,
    required String content,
    required String authorId,
    String? parentId,
    String? threadParentId,
  }) async {
    try {
      // Get user data from users collection
      final userDoc = await _firestore.collection('users').doc(authorId).get();
      if (!userDoc.exists) throw Exception('User not found');
      
      final userData = userDoc.data()!;
      
      // Ensure we have a valid threadParentId if there's a parentId
      String? effectiveThreadParentId = threadParentId;
      if (parentId != null && effectiveThreadParentId == null) {
        // If replying to a comment but no thread parent specified,
        // use a transaction to look up the thread parent
        final parentCommentDoc = await _firestore.collection('comments').doc(parentId).get();
        if (parentCommentDoc.exists) {
          effectiveThreadParentId = parentCommentDoc.data()?['threadParentId'] ?? parentId;
        } else {
          // If parent comment doesn't exist yet (rare case), use parentId as threadParentId
          effectiveThreadParentId = parentId;
        }
      }

      // Analyze sentiment
      Map<String, dynamic>? sentimentData;
      try {
        final response = await _sentimentService.analyzeSentiment(content);
        final documentSentiment = response['documentSentiment'];
        sentimentData = {
          'sentimentScore': documentSentiment['score'],
          'sentimentMagnitude': documentSentiment['magnitude'],
        };
      } catch (e) {
        debugPrint('Failed to analyze sentiment: $e');
        // Continue without sentiment data
      }
      
      // Create the comment in the flat structure
      final commentDoc = await _firestore.collection('comments').add({
        'discussionId': discussionId,
        'parentId': parentId,
        'threadParentId': effectiveThreadParentId,
        'authorId': authorId,
        'authorName': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
        'authorClass': userData['classYear'] ?? '',
        'authorAvatar': userData['photoURL'] ?? '',
        'content': content,
        'datePosted': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'downvotes': 0,
        'upvoterIds': [],
        'downvoterIds': [],
        if (sentimentData != null) ...sentimentData,
      });

      // Also update discussion reply count
      await _firestore.collection('discussions').doc(discussionId).update({
        'replyCount': FieldValue.increment(1),
      });

      // If this is a reply, increment the parent comment's reply count
      if (parentId != null) {
        await _firestore.collection('comments').doc(parentId).update({
          'replyCount': FieldValue.increment(1),
        });
      }

      return commentDoc.id;
    } catch (e) {
      throw Exception('Failed to create comment: $e');
    }
  }

  Stream<List<DiscussionComment>> getComments(String discussionId) {
    return _firestore
        .collection('comments')
        .where('discussionId', isEqualTo: discussionId)
        .orderBy('datePosted', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DiscussionComment.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  Future<List<DiscussionComment>> getCommentsSync(String discussionId) async {
    try {
      final snapshot = await _firestore
        .collection('comments')
        .where('discussionId', isEqualTo: discussionId)
        .orderBy('datePosted', descending: false)
        .get();

      return snapshot.docs.map((doc) {
        return DiscussionComment.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<void> voteComment(String discussionId, String commentId, bool isUpvote, String userId) async {
    // Updated to use the correct path for comments (top-level collection)
    final commentRef = _firestore
        .collection('comments')  // Comments are in a top-level collection
        .doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(commentRef);
      if (!doc.exists) throw Exception('Comment not found');

      final upvoterIds = List<String>.from(doc.data()?['upvoterIds'] ?? []);
      final downvoterIds = List<String>.from(doc.data()?['downvoterIds'] ?? []);

      upvoterIds.remove(userId);
      downvoterIds.remove(userId);

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

  Future<void> deleteComment(String discussionId, String commentId) async {
    try {
      // Start a transaction to handle all updates atomically
      await _firestore.runTransaction((transaction) async {
        // Get the comment doc first to check if it exists and get its data
        final commentDoc = await transaction.get(
          _firestore.collection('comments').doc(commentId)
        );

        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        // Get parent comment if this is a reply
        final parentId = commentDoc.data()?['parentId'];
        if (parentId != null) {
          // Update parent comment's reply count
          final parentRef = _firestore.collection('comments').doc(parentId);
          final parentDoc = await transaction.get(parentRef);
          
          if (parentDoc.exists) {
            transaction.update(parentRef, {
              'replyCount': FieldValue.increment(-1),
            });
          }
        }

        // Update discussion's reply count
        final discussionRef = _firestore.collection('discussions').doc(discussionId);
        transaction.update(discussionRef, {
          'replyCount': FieldValue.increment(-1),
        });

        // Delete the comment document
        transaction.delete(_firestore.collection('comments').doc(commentId));
      });

      debugPrint('Comment deleted successfully: $commentId');
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Get comments specific to a single thread
  Future<List<DiscussionComment>> getThreadComments(String discussionId, String threadParentId) async {
    try {
      // First, get the initial comment to ensure we have it
      final initialComment = await _firestore
          .collection('comments')
          .doc(threadParentId)
          .get();

      if (!initialComment.exists) {
        return [];
      }

      // Get all comments that might be part of this thread
      final snapshot = await _firestore
          .collection('comments')
          .where('discussionId', isEqualTo: discussionId)
          .orderBy('datePosted', descending: false)
          .get();

      // Filter comments to include only those that are part of this thread
      final allComments = snapshot.docs.map((doc) => 
        DiscussionComment.fromMap(doc.id, doc.data())
      ).toList();

      // Build a map of comments by their IDs for quick lookup
      final commentMap = {for (var c in allComments) c.id: c};
      
      // Helper function to check if a comment is part of the thread
      bool isPartOfThread(DiscussionComment comment) {
        var currentComment = comment;
        while (currentComment.parentId != null) {
          // If we've reached the thread parent, this comment is part of the thread
          if (currentComment.parentId == threadParentId) {
            return true;
          }
          // Move up to the parent comment
          currentComment = commentMap[currentComment.parentId]!;
        }
        return false;
      }

      // Filter to only include comments that are part of this thread
      final threadComments = allComments.where((comment) =>
        comment.id != threadParentId && // Exclude the parent comment itself
        (comment.parentId == threadParentId || // Direct replies
         isPartOfThread(comment)) // Or nested replies
      ).toList();

      debugPrint('Found ${threadComments.length} comments in thread $threadParentId');
      return threadComments;
    } catch (e) {
      debugPrint('Error fetching thread comments: $e');
      return [];
    }
  }

  // Get comments specific to a single parent (for thread view)
  Future<List<DiscussionComment>> getDirectReplies(String discussionId, String parentId) async {
    try {
      debugPrint('Fetching direct replies to: $parentId in discussion: $discussionId');
      
      // Get only comments that are direct replies to this specific parent
      final snapshot = await _firestore
          .collection('comments')
          .where('discussionId', isEqualTo: discussionId)
          .where('parentId', isEqualTo: parentId)
          .orderBy('datePosted', descending: false)
          .get();

      final replies = snapshot.docs.map((doc) {
        return DiscussionComment.fromMap(doc.id, doc.data());
      }).toList();
      
      debugPrint('Found ${replies.length} direct replies');
      return replies;
    } catch (e) {
      debugPrint('Error fetching direct replies: $e');
      return [];
    }
  }

  // Report content (discussion or comment)
  Future<void> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      await _firestore.collection('reports').add({
        'contentType': contentType,
        'contentId': contentId,
        'reporterId': user.uid,
        'reason': reason,
        'additionalInfo': additionalInfo,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('Content reported: $contentType/$contentId');
    } catch (e) {
      debugPrint('Error reporting content: $e');
      throw Exception('Failed to submit report: $e');
    }
  }

  Stream<DiscussionPost?> getDiscussionStream(String discussionId) {
    return FirebaseFirestore.instance
      .collection('discussions')
      .doc(discussionId)
      .snapshots()
      .map((doc) => doc.exists ? DiscussionPost.fromMap(doc) : null);
  }

  Future<DiscussionPost?> getDiscussion(String discussionId) async {
    try {
      final doc = await FirebaseFirestore.instance
        .collection('discussions')
        .doc(discussionId)
        .get();
        
      if (!doc.exists) return null;
      
      return DiscussionPost.fromMap(doc);
    } catch (e) {
      debugPrint('Error fetching discussion: $e');
      return null;
    }
  }

  Future<List<DiscussionComment>> getSubLevelReplies(String discussionId, String parentId) async {
    try {
      debugPrint('Querying sub-level replies for parentId: $parentId in discussion: $discussionId');
      final querySnapshot = await _firestore
          .collection('comments')
          .where('discussionId', isEqualTo: discussionId)
          .where('parentId', isEqualTo: parentId)
          .get();

      debugPrint('Query returned ${querySnapshot.docs.length} documents for parentId: $parentId');

      return querySnapshot.docs.map((doc) => DiscussionComment.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching sub-level replies: $e');
      return [];
    }
  }

  Stream<int> getCommentCount(String discussionId) {
    return _firestore
        .collection('comments')
        .where('discussionId', isEqualTo: discussionId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
