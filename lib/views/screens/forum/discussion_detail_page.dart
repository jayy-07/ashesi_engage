import 'package:ashesi_engage/viewmodels/user_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../models/entities/discussion_post.dart';
import '../../../models/entities/discussion_comment.dart';
import '../../../models/services/auth_service.dart';
import '../../../viewmodels/discussion_details_viewmodel.dart';
import '../../widgets/forum/discussion_comment_tile.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/ai_summary_card.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../widgets/snackbar_helper.dart';

class DiscussionDetailPage extends StatefulWidget {
  final DiscussionPost discussion;
  final bool focusComment;
  final String? highlightCommentId;
  final ScrollController scrollController = ScrollController();
  final VoidCallback? onReport;

  DiscussionDetailPage({
    super.key,
    required this.discussion,
    this.focusComment = false,
    this.highlightCommentId,
    this.onReport,
  });

  @override
  State<DiscussionDetailPage> createState() => _DiscussionDetailPageState();
}

class _DiscussionDetailPageState extends State<DiscussionDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final bool _isSendingComment = false;
  late final DiscussionDetailsViewModel _viewModel;
  final Map<String, bool> _highlightedComments = {};

  @override
  void initState() {
    super.initState();
    _viewModel = DiscussionDetailsViewModel(widget.discussion, context);
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocus.requestFocus();
      });
    }
    if (widget.highlightCommentId != null) {
      _highlightedComments[widget.highlightCommentId!] = true;
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedComments[widget.highlightCommentId!] = false;
          });
        }
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToComment(widget.highlightCommentId!);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().checkBookmarkStatus(widget.discussion.id);
    });
  }

  void _scrollToComment(String commentId) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      final index = _viewModel.comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final estimatedPosition = 300.0 + (index * 150.0);
        
        widget.scrollController.animateTo(
          estimatedPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final isBookmarked = bookmarkProvider.isBookmarked(widget.discussion.id);

    return ChangeNotifierProvider<DiscussionDetailsViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discussion'),
          actions: [
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                color: isBookmarked ? theme.colorScheme.primary : null,
              ),
              onPressed: () {
                bookmarkProvider.toggleBookmark(
                  itemId: widget.discussion.id,
                  itemType: 'discussion',
                );
              },
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
                            context.read<DiscussionDetailsViewModel>().deleteDiscussion();
                          },
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (value == 'report') {
                  if (widget.onReport != null) {
                    widget.onReport!();
                  } else {
                    context.read<DiscussionDetailsViewModel>().reportDiscussion();
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _DiscussionDetailContent(
                focusComment: widget.focusComment,
                scrollController: widget.scrollController,
                highlightCommentId: widget.highlightCommentId,
              ),
            ),
            _CommentInput(focusComment: widget.focusComment),
          ],
        ),
      ),
    );
  }
}

class _DiscussionDetailContent extends StatelessWidget {
  final bool focusComment;
  final ScrollController scrollController;
  final String? highlightCommentId;

  const _DiscussionDetailContent({
    required this.focusComment,
    required this.scrollController,
    this.highlightCommentId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<DiscussionDetailsViewModel>();

    return SingleChildScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      imageUrl: viewModel.discussion.authorAvatar,
                      radius: 20,
                      fallbackInitial: viewModel.discussion.authorName.substring(0, 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewModel.discussion.authorName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            viewModel.discussion.authorClass,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                QuillEditor(
                  controller: QuillController(
                    document: Document.fromJson(viewModel.discussion.content),
                    selection: const TextSelection.collapsed(offset: 0),
                    readOnly: true,
                  ),
                  scrollController: ScrollController(),
                  focusNode: FocusNode(),
                  configurations: QuillEditorConfigurations(
                    showCursor: false,
                    padding: EdgeInsets.zero,
                    autoFocus: false,
                    expands: false,
                    scrollable: false,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  timeago.format(viewModel.discussion.datePosted),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildVoteButton(
                      context: context,
                      icon: Icons.arrow_upward_rounded,
                      count: viewModel.discussion.upvotes,
                      isActive: viewModel.discussion.hasUserUpvoted,
                      onPressed: () => viewModel.voteDiscussion(true),
                    ),
                    const SizedBox(width: 8),
                    _buildVoteButton(
                      context: context,
                      icon: Icons.arrow_downward_rounded,
                      count: viewModel.discussion.downvotes,
                      isActive: viewModel.discussion.hasUserDownvoted,
                      onPressed: () => viewModel.voteDiscussion(false),
                    ),
                  ],
                ),
                const Divider(height: 32),
                AISummaryCard(
                  isLoading: viewModel.isLoadingAISummary,
                  summary: viewModel.aiSummary,
                  commentCount: viewModel.comments.length,
                  onGenerateSummary: viewModel.generateSummary,
                  hasGeneratedSummary: viewModel.hasGeneratedSummary,
                ),
                if (!viewModel.hasGeneratedSummary && 
                  !viewModel.isLoadingAISummary && 
                  viewModel.comments.isNotEmpty)
                  Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                    onPressed: viewModel.generateSummary,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Summary'),
                    ),
                  ),
                  ),
                const SizedBox(height: 18),
                Text(
                  '${viewModel.comments.length} ${viewModel.comments.length == 1 ? 'comment' : 'comments'}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (viewModel.isLoadingComments)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: _buildCommentList(context, viewModel.comments),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCommentList(
    BuildContext context,
    List<DiscussionComment> comments,
  ) {
    final viewModel = context.read<DiscussionDetailsViewModel>();
    final highlightedComments = 
        context.findAncestorStateOfType<_DiscussionDetailPageState>()?._highlightedComments ?? {};

    return [
      for (var comment in comments)
        Padding(
          padding: EdgeInsets.only(left: comment.level * 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: highlightedComments[comment.id] == true
                ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128)
                : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DiscussionCommentTile(
              key: ValueKey('discussion-${comment.id}'),
              comment: comment,
              onVote: (isUpvote) => viewModel.voteComment(comment.id, isUpvote),
              onReply: () => viewModel.startReplyingTo(comment.id),
              onToggleExpand: (commentId, isExpanded) =>
                  viewModel.toggleCommentExpansion(commentId),
              indentWidth: 32.0,
              isLastSibling: comment == comments.last,
              isHighlighted: comment.id == highlightCommentId,
            ),
          ),
        ),
    ];
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
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 36), // Add minimum size
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // Add reasonable padding
        backgroundColor: isActive ? theme.colorScheme.primaryContainer : null,
      ),
    );
  }
}

class _CommentInput extends StatefulWidget {
  final bool focusComment;

  const _CommentInput({required this.focusComment});

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  @override
  void initState() {
    super.initState();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final viewModel = context.read<DiscussionDetailsViewModel>();
        viewModel.commentFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<DiscussionDetailsViewModel>();

    String hintText = 'Add a comment...';
    Widget? replyPreview;
    
    if (viewModel.replyingToCommentId != null) {
      final parentComment = viewModel.getCommentById(viewModel.replyingToCommentId!);
      if (parentComment != null) {
        hintText = 'Reply to ${parentComment.authorName}...';
        replyPreview = Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to ${parentComment.authorName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parentComment.content.length > 100
                          ? '${parentComment.content.substring(0, 100)}...'
                          : parentComment.content,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: viewModel.cancelReply,
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyPreview != null) replyPreview,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<UserViewModel>(
                builder: (context, userViewModel, child) {
                  final appUser = userViewModel.currentUser;

                  String? imageUrl;
                  String fallbackInitial = '?';
                  String constructedDisplayName = '';

                  if (appUser != null) {
                    imageUrl = appUser.photoURL; // Corrected: Use photoURL
                    constructedDisplayName = "${appUser.firstName} ${appUser.lastName}".trim();

                    if (constructedDisplayName.isNotEmpty) {
                      fallbackInitial = constructedDisplayName[0].toUpperCase();
                    } else if (appUser.email.isNotEmpty) { // Corrected: AppUser.email is non-nullable, remove ?.
                      fallbackInitial = appUser.email[0].toUpperCase(); // Corrected: No ! needed
                    }
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: UserAvatar(
                      imageUrl: imageUrl,
                      radius: 20,
                      fallbackInitial: fallbackInitial,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: viewModel.commentController,
                  focusNode: viewModel.commentFocus,
                  maxLength: viewModel.characterLimit,
                  autofocus: widget.focusComment,
                  decoration: InputDecoration(
                    hintText: hintText,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    counterText:
                        '${viewModel.characterCount}/${viewModel.characterLimit}',
                    counterStyle: theme.textTheme.bodySmall?.copyWith(
                      color: viewModel.isOverCharacterLimit
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: viewModel.canSubmitComment
                        ? IconButton(
                            icon: viewModel.isSendingComment
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            onPressed: viewModel.isSendingComment
                                ? null
                                : () async {
                                    final success = await viewModel.submitComment();
                                    if (success && context.mounted) {
                                      // Scroll to show the new comment if needed
                                      // We don't have a direct reference to the newly added comment,
                                      // but we can scroll to the approximate area
                                      if (context.mounted && context.findAncestorWidgetOfExactType<DiscussionDetailPage>() != null) {
                                        // Delay to allow UI to rebuild
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          final scrollController = context
                                              .findAncestorWidgetOfExactType<DiscussionDetailPage>()
                                              ?.scrollController;
                                          
                                          if (scrollController != null && scrollController.hasClients) {
                                            // If user was replying to a comment, try to scroll to that general area
                                            if (viewModel.replyingToCommentId != null) {
                                              // Find approximate position
                                              final currentOffset = scrollController.offset;
                                              final maxScroll = scrollController.position.maxScrollExtent;
                                              
                                              // Since we can't locate the exact comment easily,
                                              // we'll scroll a bit further down from current position
                                              final targetOffset = currentOffset + 200; // Arbitrary distance
                                              
                                              scrollController.animateTo(
                                                targetOffset.clamp(0, maxScroll),
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeOut,
                                              );
                                            }
                                          }
                                        });
                                      }
                                    } else if (!success && context.mounted) {
                                      // Show error message
                                      SnackbarHelper.showError(context, 'Failed to post comment. Please try again.');
                                    }
                                  },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
