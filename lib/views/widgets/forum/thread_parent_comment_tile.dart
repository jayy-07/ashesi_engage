import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../../models/entities/discussion_comment.dart';
import '../../../models/services/auth_service.dart';
import '../user_avatar.dart';

class ThreadParentCommentTile extends StatelessWidget {
  final DiscussionComment comment;
  final Function(bool isUpvote) onVote;
  final VoidCallback onReply;

  const ThreadParentCommentTile({
    super.key,
    required this.comment,
    required this.onVote,
    required this.onReply,
  });

  Widget _buildVoteButton({
    required BuildContext context,
    required IconData icon,
    required int count,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          debugPrint('Vote button pressed: icon=$icon, isActive=$isActive');
          onPressed();
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: theme.colorScheme.primary.withValues(alpha:0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha:0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          constraints: const BoxConstraints(minWidth: 42, minHeight: 28),
          decoration: BoxDecoration(
            color: isActive 
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              imageUrl: comment.authorAvatar,
              radius: 20,
              fallbackInitial: comment.authorName.isNotEmpty 
                ? comment.authorName.substring(0, 1) 
                : '?',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with author name and metadata
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
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
                            value: 'report',
                            child: ListTile(
                              leading: Icon(Icons.flag_outlined),
                              title: Text('Report'),
                              dense: true,
                            ),
                          ),
                        ],
                        onSelected: (String value) {
                          debugPrint('Menu item selected: $value');
                          // Handle report action
                        },
                      ),
                    ],
                  ),
                  
                  // Comment content
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      comment.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () {
                            debugPrint('Reply button pressed for comment: ${comment.id}');
                            onReply();
                          },
                          icon: const Icon(Icons.reply),
                          iconSize: 20,
                          constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                        ),
                        _buildVoteButton(
                          context: context,
                          icon: Icons.arrow_upward_rounded,
                          count: comment.upvotes,
                          isActive: currentUserId != null && comment.hasUserUpvoted(currentUserId),
                          onPressed: () {
                            debugPrint('Upvote pressed for comment: ${comment.id}');
                            onVote(true);
                          },
                        ),
                        _buildVoteButton(
                          context: context,
                          icon: Icons.arrow_downward_rounded,
                          count: comment.downvotes,
                          isActive: currentUserId != null && comment.hasUserDownvoted(currentUserId),
                          onPressed: () {
                            debugPrint('Downvote pressed for comment: ${comment.id}');
                            onVote(false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
