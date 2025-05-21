import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import '../../../models/entities/discussion_post.dart';
import '../../widgets/user_avatar.dart';
import '../screens/admin_discussion_detail_screen.dart';

class AdminDiscussionCard extends StatelessWidget {
  final DiscussionPost discussion;
  final VoidCallback onDelete;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(bool)? onSelected;

  const AdminDiscussionCard({
    super.key,
    required this.discussion,
    required this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: isSelectionMode ? () => onSelected?.call(!isSelected) : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDiscussionDetailScreen(discussion: discussion),
            ),
          );
        },
        child: Stack(
          children: [
            if (isSelectionMode)
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: discussion.authorAvatar,
                        radius: 20,
                        fallbackInitial: discussion.authorName.substring(0, 1),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              discussion.authorName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  discussion.authorClass,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeago.format(discussion.datePosted),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isSelectionMode)
                        PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Discussion'),
                                  content: const Text(
                                    'Are you sure you want to delete this discussion? This action cannot be undone.'
                                  ),
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
                  const SizedBox(height: 16),
                  Text(
                    discussion.plainContent,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        discussion.upvotes.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        discussion.downvotes.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.reply,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        discussion.replyCount.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
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