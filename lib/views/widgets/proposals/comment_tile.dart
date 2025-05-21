import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/entities/comment.dart';
import '../user_avatar.dart';  // Update this import

class CommentTile extends StatefulWidget {
  final Comment comment;
  final Function(bool isUpvote) onVote;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final bool isAuthor; // To determine if user can delete
  final bool isOptimistic; // New property to indicate if comment is still being uploaded
  final bool isHighlighted;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onVote,
    required this.onDelete,
    required this.onReport,
    required this.isAuthor,
    this.isOptimistic = false, // Default to false
    this.isHighlighted = false,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _highlightAnimation = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    );
    
    if (widget.isHighlighted) {
      _highlightController.forward();
      // Auto-dismiss highlight after 2 seconds
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _highlightController.reverse();
        }
      });
    }
  }

  @override
  void didUpdateWidget(CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _highlightController.forward();
      // Auto-dismiss highlight after 2 seconds
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _highlightController.reverse();
        }
      });
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _highlightController.reverse();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  Widget _buildVoteButton({
    required BuildContext context,
    required IconData icon,
    required int count,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = widget.isOptimistic ? 0.6 : 1.0;

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        final highlightColor = theme.colorScheme.primaryContainer.withValues(alpha:_highlightAnimation.value * 0.3);
        
        return Container(
          decoration: BoxDecoration(
            color: widget.isHighlighted ? highlightColor : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Opacity(
            opacity: opacity,
            child: child!,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              imageUrl: widget.comment.authorAvatar,
              radius: 16,
              fallbackInitial: widget.comment.authorName.substring(0, 1),
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
                              widget.comment.authorName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.comment.authorClass,
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
                                  timeago.format(widget.comment.datePosted),
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
                          if (widget.isAuthor)
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Delete'),
                                dense: true,
                              ),
                            ),
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
                          if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Comment'),
                                content: const Text('Are you sure you want to delete this comment?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      widget.onDelete();
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: theme.colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (value == 'report') {
                            widget.onReport();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.comment.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildVoteButton(
                        context: context,
                        icon: Icons.arrow_upward,
                        count: widget.comment.upvotes,
                        isActive: widget.comment.hasUserUpvoted,
                        onPressed: () => widget.onVote(true),
                      ),
                      const SizedBox(width: 8),
                      _buildVoteButton(
                        context: context,
                        icon: Icons.arrow_downward,
                        count: widget.comment.downvotes,
                        isActive: widget.comment.hasUserDownvoted,
                        onPressed: () => widget.onVote(false),
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
