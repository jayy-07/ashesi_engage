import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/entities/discussion_post.dart';
import '../../../models/services/auth_service.dart';
import '../../../models/services/discussion_service.dart';
import '../../../providers/bookmark_provider.dart';
import '../../screens/forum/discussion_detail_page.dart';
import '../user_avatar.dart';
import '../../../widgets/snackbar_helper.dart';

class DiscussionPostCard extends StatefulWidget {
  final DiscussionPost discussion;
  final Function(bool) onVote;
  final VoidCallback onReply;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  const DiscussionPostCard({
    super.key,
    required this.discussion,
    required this.onVote,
    required this.onReply,
    required this.onReport,
    required this.onDelete,
  });

  @override
  State<DiscussionPostCard> createState() => _DiscussionPostCardState();
}

class _DiscussionPostCardState extends State<DiscussionPostCard> {
  bool _isVoting = false;
  late Stream<int> _commentCountStream;
  
  @override
  void initState() {
    super.initState();
    _commentCountStream = DiscussionService().getCommentCount(widget.discussion.id);
    // Check bookmark status when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().checkBookmarkStatus(widget.discussion.id);
    });
  }

  Future<void> _handleVote(bool isUpvote) async {
    if (_isVoting) return;
    
    setState(() => _isVoting = true);
    try {
      HapticFeedback.mediumImpact();
      await Future.microtask(() => widget.onVote(isUpvote));
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final isBookmarked = bookmarkProvider.isBookmarked(widget.discussion.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscussionDetailPage(
              discussion: widget.discussion,
              focusComment: false,
              onReport: widget.onReport,
            ),
          ),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    imageUrl: widget.discussion.authorAvatar,
                    radius: 20,
                    fallbackInitial: widget.discussion.authorName.substring(0, 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.discussion.authorName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              widget.discussion.authorClass,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(widget.discussion.datePosted),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More options',
                    itemBuilder: (BuildContext context) {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final isAuthor = widget.discussion.authorId == authService.currentUser?.uid;
                      
                      return [
                        if (isAuthor)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                              dense: true,
                            ),
                          ),
                        PopupMenuItem<String>(
                          value: 'bookmark',
                          child: ListTile(
                            leading: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
                            title: Text(isBookmarked ? 'Remove bookmark' : 'Bookmark'),
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
                      ];
                    },
                    onSelected: (String value) {
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Discussion'),
                            content: const Text('Are you sure you want to delete this discussion? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onDelete();
                                  SnackbarHelper.showSuccess(context, 'Discussion deleted');
                                },
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (value == 'bookmark') {
                        bookmarkProvider.toggleBookmark(
                          itemId: widget.discussion.id,
                          itemType: 'discussion',
                        );
                        SnackbarHelper.showSuccess(context, isBookmarked ? 'Bookmark removed' : 'Bookmark added');
                      } else if (value == 'report') {
                        widget.onReport();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.discussion.plainContent,  
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.reply),
                    label: Text(widget.discussion.replyCount.toString()),
                    onPressed: () {
                      // Navigate directly to detail page with focusComment
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiscussionDetailPage(
                            discussion: widget.discussion,
                            focusComment: true,
                          ),
                        ),
                      ); // Remove .then() callback since onReply is no longer needed
                    },
                  ),
                  const Spacer(),
                  _buildVoteButton(
                    context: context,
                    icon: Icons.arrow_upward_rounded,
                    count: widget.discussion.upvotes,
                    isActive: widget.discussion.hasUserUpvoted,
                    onPressed: () => _handleVote(true),
                  ),
                  const SizedBox(width: 8),
                  _buildVoteButton(
                    context: context,
                    icon: Icons.arrow_downward_rounded,
                    count: widget.discussion.downvotes,
                    isActive: widget.discussion.hasUserDownvoted,
                    onPressed: () => _handleVote(false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton({
    required BuildContext context,
    required IconData icon,
    required int count,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      icon: Icon(
        icon,
        size: 20,
        color: isActive ? theme.colorScheme.primary : null,
      ),
      label: Text(
        count.toString(),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isActive ? theme.colorScheme.primary : null,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      style: isActive
          ? OutlinedButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
            )
          : null,
    );
  }
}
