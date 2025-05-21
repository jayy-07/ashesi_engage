import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/entities/discussion_comment.dart';
import '../../widgets/user_avatar.dart';

class AdminDiscussionCommentTile extends StatelessWidget {
  final DiscussionComment comment;
  final List<DiscussionComment> replies;
  final List<DiscussionComment> allComments;
  final VoidCallback onDelete;
  final Function(DiscussionComment, List<DiscussionComment>) onViewThread;
  final Function(String, bool) onToggleExpand;
  final bool isExpanded;
  final bool isLastSibling;
  final int nestingLevel;
  final bool disableNestedReplies; // <-- Add this

  // Update static thresholds
  static const int maxNestingLevel = 4;
  static const int secondThresholdLevel = 8;

  const AdminDiscussionCommentTile({
    super.key,
    required this.comment,
    required this.replies,
    required this.allComments,
    required this.onDelete,
    required this.onViewThread,
    required this.onToggleExpand,
    this.isExpanded = true,
    this.isLastSibling = false,
    this.nestingLevel = 0,
    this.disableNestedReplies = false, // <-- Default to false
  });

  List<DiscussionComment> _getDirectReplies(String commentId) {
    // Get only direct replies to this comment
    final directReplies = allComments
        .where((c) => c.parentId == commentId)
        .toList();

    // Remove duplicates while preserving order
    final uniqueReplies = <String, DiscussionComment>{};
    for (var reply in directReplies) {
      uniqueReplies[reply.id] = reply;
    }

    return uniqueReplies.values.toList()
      ..sort((a, b) => a.datePosted.compareTo(b.datePosted));
  }

  // Get all nested replies for a comment
  List<DiscussionComment> _getAllReplies(String commentId) {
    final processedIds = <String>{};
    final replies = <DiscussionComment>[];
    
    void addReplies(String parentId) {
      final directReplies = _getDirectReplies(parentId);
      for (var reply in directReplies) {
        if (!processedIds.contains(reply.id)) {
          processedIds.add(reply.id);
          replies.add(reply);
          addReplies(reply.id);
        }
      }
    }

    addReplies(commentId);
    return replies..sort((a, b) => a.datePosted.compareTo(b.datePosted));
  }

  Widget _buildVoteButton({
    required BuildContext context,
    required IconData icon,
    required int count,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentChip(BuildContext context) {
    if (comment.sentimentScore == null || comment.sentimentMagnitude == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final interpretation = comment.sentimentInterpretation;
    if (interpretation == null) return const SizedBox.shrink();

    final parts = interpretation.split(' | ');
    if (parts.length != 2) return const SizedBox.shrink();

    final sentiment = parts[0];
    final intensity = parts[1];

    Color getChipColor() {
      if (comment.sentimentScore! >= 0.5) {
        return Colors.green.withValues(alpha:0.2);
      } else if (comment.sentimentScore! > 0.1) {
        return Colors.lightGreen.withValues(alpha:0.2);
      } else if (comment.sentimentScore! >= -0.1) {
        return Colors.grey.withValues(alpha:0.2);
      } else if (comment.sentimentScore! >= -0.5) {
        return Colors.orange.withValues(alpha:0.2);
      } else {
        return Colors.red.withValues(alpha:0.2);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getChipColor(),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sentiment,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '|',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha:0.5),
                  ),
                ),
              ),
              Text(
                intensity,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 16),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: '''
Score (${comment.sentimentScore?.toStringAsFixed(2)}): Indicates the overall emotional leaning
• -1.0 to -0.5: Very Negative
• -0.5 to -0.1: Negative
• -0.1 to 0.1: Neutral
• 0.1 to 0.5: Positive
• 0.5 to 1.0: Very Positive

Magnitude (${comment.sentimentMagnitude?.toStringAsFixed(2)}): Measures emotional intensity
• 0.0 to 1.0: Mild emotion
• 1.0 to 2.0: Moderate emotion
• 2.0+: Strong emotion''',
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReplies = replies.isNotEmpty;
    final isNested = nestingLevel > 0;
    
    // Update the shouldShowThreadButton logic to match DiscussionCommentTile
    final shouldShowThreadButton = (nestingLevel >= maxNestingLevel && 
                                  nestingLevel < secondThresholdLevel && 
                                  hasReplies) || 
                                 (nestingLevel >= secondThresholdLevel);

    return Padding(
      padding: const EdgeInsets.only(top: 4), // Add slight padding above comments
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left border line for nested comments
              if (!isLastSibling)
                SizedBox(
                  width: 2,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              // Avatar and content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(
                          imageUrl: comment.authorAvatar,
                          radius: 16,
                          fallbackInitial: comment.authorName.substring(0, 1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.authorName,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              comment.authorClass,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text('•', 
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              timeago.format(comment.datePosted),
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildSentimentChip(context),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Delete'),
                                          dense: true,
                                        ),
                                      ),
                                    ],
                                    onSelected: (String value) {
                                      if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Comment'),
                                            content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('CANCEL'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: theme.colorScheme.error,
                                                  foregroundColor: theme.colorScheme.onError,
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  onDelete();
                                                },
                                                child: const Text('DELETE'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.content,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildVoteButton(
                                        context: context,
                                        icon: Icons.arrow_upward_rounded,
                                        count: comment.upvotes,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildVoteButton(
                                        context: context,
                                        icon: Icons.arrow_downward_rounded,
                                        count: comment.downvotes,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (hasReplies && !shouldShowThreadButton)
                                        TextButton.icon(
                                          onPressed: () {
                                            debugPrint('Toggling expansion for comment ${comment.id} to ${!isExpanded}');
                                            onToggleExpand(comment.id, !isExpanded);
                                          },
                                          icon: Icon(
                                            isExpanded ? Icons.expand_less : Icons.expand_more,
                                            size: 16,
                                          ),
                                          label: Text(
                                            '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                                          ),
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      if (shouldShowThreadButton)
                                        TextButton.icon(
                                          onPressed: () {
                                            debugPrint('Opening thread view for comment: ${comment.id}');
                                            // Get all nested replies for this comment
                                            final allNestedReplies = _getAllReplies(comment.id);
                                            onViewThread(comment, allNestedReplies);
                                          },
                                          icon: const Icon(Icons.forum_outlined, size: 16),
                                          label: Text('Show more replies (${replies.length})'),
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!disableNestedReplies && hasReplies && !shouldShowThreadButton)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Column(
                        children: replies.asMap().entries.map((entry) {
                          final index = entry.key;
                          final reply = entry.value;
                          final isLastReply = index == replies.length - 1;
                          
                          // Get direct replies to this comment from all comments
                          final replyReplies = _getDirectReplies(reply.id);
                          
                          return AdminDiscussionCommentTile(
                            key: ValueKey('reply_${reply.id}'),
                            comment: reply,
                            replies: replyReplies,
                            allComments: allComments,
                            onDelete: onDelete, // The parent's onDelete will handle this reply's deletion
                            onViewThread: onViewThread,
                            onToggleExpand: onToggleExpand,
                            isExpanded: reply.isExpanded,
                            isLastSibling: isLastReply,
                            nestingLevel: nestingLevel + 1,
                            disableNestedReplies: disableNestedReplies,
                          );
                        }).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}