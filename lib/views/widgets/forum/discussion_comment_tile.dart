import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../models/entities/discussion_comment.dart';
import '../../../viewmodels/discussion_details_viewmodel.dart';
import '../../../models/services/auth_service.dart';
import '../user_avatar.dart';
import '../../screens/forum/thread_detail_page.dart';
import '../report_dialog.dart';
import '../../../widgets/snackbar_helper.dart';

class DiscussionCommentTile extends StatefulWidget {
  final DiscussionComment comment;
  final Function(bool isUpvote) onVote;
  final VoidCallback onReply;
  final Function(String commentId, bool isExpanded) onToggleExpand;
  final double indentWidth;
  final bool isLastSibling;
  final bool isHighlighted;

  // Update to support dynamic thresholds for different nesting levels
  static const int maxNestingLevel = 2; // Level 3 is where we first show "Continue thread"
  static const int secondThresholdLevel = 6; // Level 7 is where we show "Continue thread" again

  const DiscussionCommentTile({
    super.key,
    required this.comment,
    required this.onVote,
    required this.onReply,
    required this.onToggleExpand,
    this.indentWidth = 32.0,
    required this.isLastSibling,
    this.isHighlighted = false,
  });

  @override
  State<DiscussionCommentTile> createState() => _DiscussionCommentTileState();
}

class _DiscussionCommentTileState extends State<DiscussionCommentTile> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (widget.comment.isExpanded) {
      _controller.value = 1.0;
    }
    
    // Add highlight animation
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
  void didUpdateWidget(DiscussionCommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comment.isExpanded != oldWidget.comment.isExpanded) {
      if (widget.comment.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      // Add a debug print to verify the toggle is recognized
      debugPrint('Comment ${widget.comment.id} expanded: ${widget.comment.isExpanded}');
    }
    
    // Handle highlight changes
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
    _controller.dispose();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          constraints: const BoxConstraints(minWidth: 42, minHeight: 28),
          decoration: BoxDecoration(
            color: isActive 
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Important: prevent Row from expanding
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

    // Calculate effective level for UI display - cap at maxNestingLevel
    // Also ensure level is never negative
    final rawLevel = widget.comment.level >= 0 ? widget.comment.level : 0;
    final effectiveLevel = rawLevel > DiscussionCommentTile.maxNestingLevel
        ? DiscussionCommentTile.maxNestingLevel
        : rawLevel;
        
    // Calculate appropriate indentation that scales down for deeper nesting
    final scaledIndentWidth = effectiveLevel > 2 
        ? widget.indentWidth / (effectiveLevel - 1) 
        : widget.indentWidth;

    // Add opacity for optimistic comments
    final opacity = widget.comment.isOptimistic ? 0.6 : 1.0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap the entire row in a ConstrainedBox for deep nesting levels
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width,
              minHeight: 10.0,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (effectiveLevel > 0)
                    SizedBox(
                      width: scaledIndentWidth * effectiveLevel,
                      child: CustomPaint(
                        painter: CommentLinePainter(
                          color: theme.colorScheme.outlineVariant.withValues(alpha:0.5),
                          level: effectiveLevel,
                          indentWidth: scaledIndentWidth,
                          isLastSibling: widget.isLastSibling,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserAvatar(
                            imageUrl: widget.comment.authorAvatar,
                            radius: 16,
                            fallbackInitial: widget.comment.authorName.isNotEmpty 
                              ? widget.comment.authorName.substring(0, 1) 
                              : '?',
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
                                          Text(widget.comment.authorName),
                                          _buildMetadataRow(context),
                                        ],
                                      ),
                                    ),
                                    _buildMoreButton(context),
                                  ],
                                ),
                                Text(
                                  widget.comment.content,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 8,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (widget.comment.hasReplies)
                                        TextButton.icon(
                                          onPressed: () => widget.onToggleExpand(
                                            widget.comment.id,
                                            !widget.comment.isExpanded
                                          ),
                                          icon: Icon(
                                            widget.comment.isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            size: 20,
                                          ),
                                          label: Text(
                                            widget.comment.isExpanded
                                                ? 'Hide'
                                                : '${widget.comment.replyCount} ${widget.comment.replyCount == 1 ? 'reply' : 'replies'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: const Size(40, 36),
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                      const Spacer(),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              debugPrint('Reply button pressed for comment ID: ${widget.comment.id}');
                                              widget.onReply();
                                            },
                                            icon: const Icon(Icons.reply),
                                            iconSize: 20,
                                            constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                                          ),
                                          _buildVoteButton(
                                            context: context,
                                            icon: Icons.arrow_upward_rounded,
                                            count: widget.comment.upvotes,
                                            isActive: currentUserId != null && widget.comment.hasUserUpvoted(currentUserId),
                                            onPressed: () => widget.onVote(true),
                                          ),
                                          _buildVoteButton(
                                            context: context,
                                            icon: Icons.arrow_downward_rounded,
                                            count: widget.comment.downvotes,
                                            isActive: currentUserId != null && widget.comment.hasUserDownvoted(currentUserId),
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.comment.hasReplies)
            SizeTransition(
              sizeFactor: _animation,
              child: Column(
                children: [
                  if ((widget.comment.level >= DiscussionCommentTile.maxNestingLevel &&
                       widget.comment.level < DiscussionCommentTile.secondThresholdLevel) ||
                      widget.comment.level >= DiscussionCommentTile.secondThresholdLevel)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(width: scaledIndentWidth * (effectiveLevel + 1)),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _navigateToThread(context),
                              child: Text(
                                'Continue thread (${widget.comment.replyCount} ${widget.comment.replyCount == 1 ? "reply" : "replies"})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...widget.comment.replies.map((reply) {
                      return DiscussionCommentTile(
                        key: ValueKey('comment-${reply.id}'),
                        comment: reply,
                        onVote: (isUpvote) {
                          debugPrint('Vote on nested comment ID: ${reply.id}');
                          final viewModel = Provider.of<DiscussionDetailsViewModel>(
                            context,
                            listen: false
                          );
                          viewModel.voteComment(reply.id, isUpvote);
                        },
                        onReply: () {
                          debugPrint('Reply button pressed for nested comment ID: ${reply.id}');
                          try {
                            final viewModel = Provider.of<DiscussionDetailsViewModel>(
                              context,
                              listen: false
                            );
                            viewModel.startReplyingTo(reply.id);
                          } catch (e) {
                            debugPrint('Could not access ViewModel directly: $e');
                            widget.onReply();
                          }
                        },
                        onToggleExpand: widget.onToggleExpand,
                        indentWidth: scaledIndentWidth,
                        isLastSibling: reply == widget.comment.replies.last,
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Navigate to thread detail with THIS comment as the parent
  void _navigateToThread(BuildContext context) {
    debugPrint('Navigating to thread with parent comment: ${widget.comment.id}, level: ${widget.comment.level}');
    
    // Ensure we're not in the middle of a build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the ViewModel so we can access all the comments
      final viewModel = Provider.of<DiscussionDetailsViewModel>(context, listen: false);
      
      // Find any direct replies to this comment (they will be shown in the thread page)
      final directReplies = viewModel.getRepliesForComment(widget.comment.id);
      
      // If we have at least one reply, use the first one as the triggering reply
      final reply = directReplies.isNotEmpty 
          ? directReplies.first 
          : widget.comment; // Fallback to the comment itself
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ThreadDetailPage(
            parentComment: widget.comment,  // This comment is the parent
            reply: reply,                   // First reply or same comment
          ),
        ),
      );
    });
  }

  Widget _buildMetadataRow(BuildContext context) {
    return Row(
      children: [
        Text(
          widget.comment.authorClass,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text('•', 
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          timeago.format(widget.comment.datePosted),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAuthor = widget.comment.authorId == authService.currentUser?.uid;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (BuildContext context) => [
        if (isAuthor)
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
      onSelected: (String value) async {
        if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Comment'),
              content: const Text('Are you sure you want to delete this comment?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true && context.mounted) {
            try {
              final viewModel = Provider.of<DiscussionDetailsViewModel>(
                context,
                listen: false
              );
              await viewModel.deleteComment(widget.comment.id);

              if (context.mounted) {
                SnackbarHelper.showSuccess(context, 'Comment deleted');
              }
            } catch (e) {
              if (context.mounted) {
                SnackbarHelper.showError(context, 'Error deleting comment: $e');
              }
            }
          }
        } else if (value == 'report') {
          try {
            // Show the report dialog instead of using the ViewModel
            if (context.mounted) {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => ReportDialog(
                  contentType: 'discussion_comment',
                  contentId: widget.comment.id,
                ),
              );
              
              if (result == true && context.mounted) {
                SnackbarHelper.showSuccess(context, 'Comment reported');
              }
            }
          } catch (e) {
            debugPrint('Error reporting comment: $e');
            if (context.mounted) {
              SnackbarHelper.showError(context, 'Error reporting comment: $e');
            }
          }
        }
      },
    );
  }
}

class CommentLinePainter extends CustomPainter {
  final Color color;
  final int level;
  final double indentWidth;
  final bool isLastSibling;

  CommentLinePainter({
    required this.color,
    required this.level,
    required this.indentWidth,
    required this.isLastSibling,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw the connecting line for the current level
    if (level > 0) {
      final currentLevelX = size.width - (indentWidth / 2);
      canvas.drawPath(
        Path()
          ..moveTo(currentLevelX, 0)
          ..lineTo(currentLevelX, 12)
          ..lineTo(size.width, 12),
        paint,
      );
    }

    // Only draw vertical lines for previous levels if not the last sibling
    for (var i = 0; i < level - 1; i++) {
      if (!isLastSibling) {
        final x = (i + 1) * indentWidth - (indentWidth / 2);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CommentLinePainter oldDelegate) =>
      color != oldDelegate.color ||
      level != oldDelegate.level ||
      indentWidth != oldDelegate.indentWidth ||
      isLastSibling != oldDelegate.isLastSibling;
}
