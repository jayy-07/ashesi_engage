import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/entities/comment.dart';
import '../models/entities/discussion_comment.dart';

class ReplyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int pageSize = 10;

  // Fetch paginated proposal comments
  Future<(List<Comment>, DocumentSnapshot?)> getUserProposalComments(String userId, {DocumentSnapshot? lastDocument}) async {
    try {
      debugPrint('Fetching proposal comments for user $userId');
      
      // Query all proposals first to get their comments subcollections
      var proposalsQuery = _firestore.collection('proposals');
      final proposalDocs = await proposalsQuery.get();
      
      List<Comment> allComments = [];
      DocumentSnapshot? lastDoc;
      
      // For each proposal, get its comments where authorId matches
      for (var proposalDoc in proposalDocs.docs) {
        var query = proposalDoc.reference
            .collection('comments')
            .where('authorId', isEqualTo: userId)
            .orderBy('datePosted', descending: true)
            .limit(pageSize);

        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument);
        }

        final querySnapshot = await query.get();
        debugPrint('Found ${querySnapshot.docs.length} comments in proposal ${proposalDoc.id}');

        final comments = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return Comment(
            id: doc.id,
            proposalId: proposalDoc.id,
            authorId: data['authorId'] as String,
            authorName: data['authorName'] as String,
            authorAvatar: data['authorAvatar'] as String? ?? '',
            authorClass: data['authorClass'] as String? ?? '',
            content: data['content'] as String,
            datePosted: (data['datePosted'] as Timestamp).toDate(),
            upvotes: data['upvotes'] as int? ?? 0,
            downvotes: data['downvotes'] as int? ?? 0,
            hasUserUpvoted: false,
            hasUserDownvoted: false,
          );
        }).toList();

        allComments.addAll(comments);
        if (querySnapshot.docs.isNotEmpty) {
          lastDoc = querySnapshot.docs.last;
        }
      }

      // Sort all comments by date
      allComments.sort((a, b) => b.datePosted.compareTo(a.datePosted));
      
      // Take only the first pageSize comments
      if (allComments.length > pageSize) {
        allComments = allComments.take(pageSize).toList();
      }

      return (allComments, lastDoc);
    } catch (e) {
      debugPrint('Error fetching user proposal comments: $e');
      return (<Comment>[], null);
    }
  }

  // Fetch paginated discussion comments
  Future<(List<DiscussionComment>, DocumentSnapshot?)> getUserDiscussionComments(String userId, {DocumentSnapshot? lastDocument}) async {
    try {
      debugPrint('Fetching discussion comments for user $userId');
      
      var query = _firestore
          .collection('comments')  // Discussion comments are in top-level collection
          .where('authorId', isEqualTo: userId)
          .orderBy('datePosted', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      debugPrint('Found ${querySnapshot.docs.length} discussion comments');

      final comments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final discussionId = data['discussionId'] as String;
        
        return DiscussionComment(
          id: doc.id,
          discussionId: discussionId,
          authorId: data['authorId'] as String,
          authorName: data['authorName'] as String,
          authorAvatar: data['authorAvatar'] as String? ?? '',
          authorClass: data['authorClass'] as String? ?? '',
          content: data['content'] as String,
          datePosted: (data['datePosted'] as Timestamp).toDate(),
          parentId: data['parentId'] as String?,
          threadParentId: data['threadParentId'] as String?,
          upvoterIds: List<String>.from(data['upvoterIds'] ?? []),
          downvoterIds: List<String>.from(data['downvoterIds'] ?? []),
          replyCount: data['replyCount'] as int? ?? 0,
          replies: [],
        );
      }).toList();

      DocumentSnapshot? lastDoc = querySnapshot.docs.isEmpty ? null : querySnapshot.docs.last;
      return (comments, lastDoc);
    } catch (e) {
      debugPrint('Error fetching user discussion comments: $e');
      return (<DiscussionComment>[], null);
    }
  }
} 