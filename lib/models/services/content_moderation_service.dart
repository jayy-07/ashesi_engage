import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../views/admin/screens/admin_discussion_detail_screen.dart';
import '../../views/admin/screens/admin_proposal_detail_screen.dart';
import 'proposal_service.dart';
import 'discussion_service.dart';

class ReportedContentPreview {
  final String title;
  final String preview;
  final String? authorName;
  final DateTime? timestamp;

  ReportedContentPreview({
    required this.title,
    required this.preview,
    this.authorName,
    this.timestamp,
  });
}

/// Service for admin content moderation actions
class ContentModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProposalService _proposalService = ProposalService();
  final DiscussionService _discussionService = DiscussionService();

  // Delete a discussion comment
  Future<void> deleteDiscussionComment(
      String commentId, String discussionId) async {
    try {
      // First find the comment document
      final commentQuery = await _firestore
          .collection('discussions')
          .doc(discussionId)
          .collection('comments')
          .where(FieldPath.documentId, isEqualTo: commentId)
          .get();

      if (commentQuery.docs.isEmpty) {
        throw Exception('Comment not found');
      }

      // Delete the comment
      await _firestore
          .collection('discussions')
          .doc(discussionId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete discussion comment: $e');
    }
  }

  // Delete a proposal comment
  Future<void> deleteProposalComment(
      String commentId, String proposalId) async {
    try {
      // First check if the comment exists
      final commentQuery = await _firestore
          .collection('proposals')
          .doc(proposalId)
          .collection('comments')
          .where(FieldPath.documentId, isEqualTo: commentId)
          .get();

      if (commentQuery.docs.isEmpty) {
        throw Exception('Comment not found');
      }

      // Delete the comment
      await _firestore
          .collection('proposals')
          .doc(proposalId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete proposal comment: $e');
    }
  }

  // Get a preview of reported content for display in the admin interface
  Future<ReportedContentPreview?> getReportedContentPreview(
      String contentId, String contentType) async {
    try {
      switch (contentType) {
        case 'discussion':
          final discussion = await _discussionService.getDiscussion(contentId);
          if (discussion != null) {
            return ReportedContentPreview(
              title:
                  'Discussion', // Changed from discussion.title to hardcoded 'Discussion'
              preview: discussion.plainContent.length > 150
                  ? '${discussion.plainContent.substring(0, 150)}...'
                  : discussion.plainContent,
              authorName: discussion.authorName,
              timestamp: discussion.datePosted,
            );
          }
          break;

        case 'proposal':
          final proposal = await _proposalService.getProposal(contentId);
          if (proposal != null) {
            return ReportedContentPreview(
              title: proposal.title,
              preview: proposal.plainContent.length > 150
                  ? '${proposal.plainContent.substring(0, 150)}...'
                  : proposal.plainContent,
              authorName: proposal.authorName,
              timestamp: proposal.datePosted,
            );
          }
          break;

        case 'discussion_comment':
          // For comments, we need to find which discussion it belongs to
          final parentId = await findParentContentId(contentId, contentType);
          if (parentId != null) {
            final commentDoc = await _firestore
                .collection('discussions')
                .doc(parentId)
                .collection('comments')
                .doc(contentId)
                .get();

            if (commentDoc.exists) {
              final data = commentDoc.data();
              return ReportedContentPreview(
                title: 'Comment on Discussion',
                preview: data?['content']?.toString() ?? 'No content available',
                authorName: data?['authorName']?.toString(),
                timestamp: data?['datePosted'] != null
                    ? (data?['datePosted'] as Timestamp).toDate()
                    : null,
              );
            }
          }
          break;

        case 'proposal_comment':
          // For comments, we need to find which proposal it belongs to
          final parentId = await findParentContentId(contentId, contentType);
          if (parentId != null) {
            final commentDoc = await _firestore
                .collection('proposals')
                .doc(parentId)
                .collection('comments')
                .doc(contentId)
                .get();

            if (commentDoc.exists) {
              final data = commentDoc.data();
              return ReportedContentPreview(
                title: 'Comment on Proposal',
                preview: data?['content']?.toString() ?? 'No content available',
                authorName: data?['authorName']?.toString(),
                timestamp: data?['datePosted'] != null
                    ? (data?['datePosted'] as Timestamp).toDate()
                    : null,
              );
            }
          }
          break;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting content preview: $e');
      return null;
    }
  }

  // Navigate to admin content based on type
  Future<void> navigateToAdminContent(
      BuildContext context, String contentType, String contentId) async {
    try {
      bool handled = false;
      String? parentId;

      switch (contentType) {
        case 'proposal':
          // For proposals, load the proposal and push directly to detail screen
          final proposal = await _proposalService.getProposal(contentId);
          if (proposal != null && context.mounted) {
            debugPrint('Directly navigating to proposal detail for ID: $contentId');
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminProposalDetailScreen(
                  proposal: proposal,
                  highlightCommentId: null,
                ),
              ),
            );
            handled = true;
          }
          break;

        case 'proposal_comment':
          // Find the parent proposal and navigate directly to detail screen
          parentId = await findParentContentId(contentId, 'proposal_comment');
          if (parentId != null) {
            final proposal = await _proposalService.getProposal(parentId);
            if (proposal != null && context.mounted) {
              debugPrint('Directly navigating to proposal detail for ID: $parentId with highlighted comment: $contentId');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminProposalDetailScreen(
                    proposal: proposal,
                    highlightCommentId: contentId,  // Pass the comment ID to highlight
                  ),
                ),
              );
              handled = true;
            }
          }
          break;

        case 'discussion':
          // For discussions, load the discussion and push directly to detail screen
          final discussion = await _discussionService.getDiscussion(contentId);
          if (discussion != null && context.mounted) {
            debugPrint('Directly navigating to discussion detail for ID: $contentId');
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDiscussionDetailScreen(discussion: discussion),
              ),
            );
            handled = true;
          }
          break;

        case 'discussion_comment':
          // Find the parent discussion and navigate directly to detail screen
          parentId = await findParentContentId(contentId, 'discussion_comment');
          if (parentId != null) {
            final discussion = await _discussionService.getDiscussion(parentId);
            if (discussion != null && context.mounted) {
              debugPrint('Directly navigating to discussion detail for ID: $parentId with highlighted comment: $contentId');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminDiscussionDetailScreen(
                    discussion: discussion,
                    highlightedCommentId: contentId,
                  ),
                ),
              );
              handled = true;
            }
          }
          break;
      }

      if (!handled) {
        throw Exception('Unsupported content type for admin navigation');
      }
    } catch (e) {
      debugPrint('Error navigating to admin content: $e');
      rethrow; // Rethrow to allow caller to handle error
    }
  }

  // Helper method to extract parent ID from a comment ID
  String? extractParentId(String commentId) {
    // Assume format is "parentId_commentId" or similar
    // In reality, you would implement this based on your actual ID structure
    final parts = commentId.split('_');
    if (parts.length >= 2) {
      return parts[0];
    }
    return null;
  }

  // Find parent content ID for a comment
  Future<String?> findParentContentId(
      String commentId, String commentType) async {
    // This is a simplified version - in a real app, you'd have a more robust way to find parent content
    try {
      if (commentType == 'discussion_comment') {
        // Query all discussions to find which one contains this comment
        final discussions = await _firestore.collection('discussions').get();

        for (final discussion in discussions.docs) {
          final commentExists = await _firestore
              .collection('discussions')
              .doc(discussion.id)
              .collection('comments')
              .doc(commentId)
              .get();

          if (commentExists.exists) {
            return discussion.id;
          }
        }
      } else if (commentType == 'proposal_comment') {
        // Query all proposals to find which one contains this comment
        final proposals = await _firestore.collection('proposals').get();

        for (final proposal in proposals.docs) {
          final commentExists = await _firestore
              .collection('proposals')
              .doc(proposal.id)
              .collection('comments')
              .doc(commentId)
              .get();

          if (commentExists.exists) {
            return proposal.id;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error finding parent content: $e');
      return null;
    }
  }
}
