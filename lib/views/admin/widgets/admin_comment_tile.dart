import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/entities/comment.dart';
import '../../widgets/user_avatar.dart';

class AdminCommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback onDelete;
  final bool isHighlighted;

  const AdminCommentTile({
    super.key,
    required this.comment,
    required this.onDelete,
    this.isHighlighted = false,
  });

  Widget _buildVoteButton({
    required BuildContext context,
    required IconData icon,
    required int count,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive 
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive 
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isActive 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentInfo(BuildContext context) {
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: isHighlighted ? BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha:0.3),
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: isHighlighted ? 12 : 0,
        ),
        child: Row(
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
                            isActive: comment.hasUserUpvoted,
                          ),
                          const SizedBox(width: 8),
                          _buildVoteButton(
                            context: context,
                            icon: Icons.arrow_downward_rounded,
                            count: comment.downvotes,
                            isActive: comment.hasUserDownvoted,
                          ),
                        ],
                      ),
                      _buildSentimentInfo(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}