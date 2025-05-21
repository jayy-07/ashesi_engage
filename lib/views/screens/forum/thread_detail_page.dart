import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../../models/entities/discussion_comment.dart';
import '../../../models/entities/discussion_post.dart';
import '../../../viewmodels/discussion_details_viewmodel.dart';
import '../../../models/services/discussion_service.dart'; // Add this import
import '../../widgets/forum/discussion_comment_tile.dart';
import '../../widgets/forum/thread_parent_comment_tile.dart';
import '../../../widgets/snackbar_helper.dart';

class ThreadDetailPage extends StatefulWidget {
  final DiscussionComment parentComment;
  final DiscussionComment reply;
  final String? highlightCommentId;

  const ThreadDetailPage({
    super.key,
    required this.parentComment,
    required this.reply,
    this.highlightCommentId,
  });

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> with TickerProviderStateMixin {
  late final DiscussionDetailsViewModel _viewModel;
  final DiscussionService _discussionService = DiscussionService();
  bool _isLoading = true;
  final Map<String, AnimationController> _animationControllers = {};

  @override
  void initState() {
    super.initState();
    
    // Create a dummy discussion object from the parent comment
    final threadDiscussion = DiscussionPost(
      id: widget.parentComment.discussionId,
      authorId: widget.parentComment.authorId,
      authorName: widget.parentComment.authorName,
      authorClass: widget.parentComment.authorClass,
      authorAvatar: widget.parentComment.authorAvatar,
      content: widget.parentComment.content,
      plainContent: widget.parentComment.content, // Add this line
      datePosted: widget.parentComment.datePosted,
    );
    
    // Create the ViewModel before build
    _viewModel = DiscussionDetailsViewModel(threadDiscussion, context);
    
    // Set thread parent comment first to ensure proper context for replies
    debugPrint('Setting thread parent comment: ${widget.parentComment.id}');
    _viewModel.setThreadParentComment(widget.parentComment);

    // Initialize sub-level comments for the triggering comment
    debugPrint('Initializing sub-level comments for commentId: ${widget.parentComment.id}');
    _initializeSubLevelComments(widget.parentComment.id);
  }
  
  @override
  void didUpdateWidget(ThreadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the parent comment changed, update the thread context
    if (widget.parentComment.id != oldWidget.parentComment.id) {
      _viewModel.setThreadParentComment(widget.parentComment);
      _initializeSubLevelComments(widget.parentComment.id);
    }
  }
  
  @override
  void dispose() {
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
    // Nothing specific to dispose here, the ViewModel handles its own cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DiscussionDetailsViewModel>.value(
      value: _viewModel,
      child: Builder(
        builder: (context) {
          return Consumer<DiscussionDetailsViewModel>(
            builder: (context, viewModel, child) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Thread'),
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Context header showing which comment thread this is
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From discussion:',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Consumer<DiscussionDetailsViewModel>(
                                      builder: (context, viewModel, _) {
                                        final currentComment = viewModel.getCommentById(widget.parentComment.id) ?? widget.parentComment;
                                        return ThreadParentCommentTile(
                                          comment: currentComment,
                                          onVote: (isUpvote) async {
                                            debugPrint('Voting on thread parent comment ${currentComment.id}');
                                            // When voting on thread parent, ensure thread context is preserved
                                            await viewModel.voteCommentInThread(
                                              currentComment.id,
                                              isUpvote,
                                              widget.parentComment.id,
                                            );
                                          },
                                          onReply: () => viewModel.startReplyingTo(currentComment.id),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Thread continuation - only show related replies
                              viewModel.comments.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Text('No replies in this thread yet'),
                                    ),
                                  )
                                : Column(
                                    children: _buildCommentList(context, viewModel.comments),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Add comment input at bottom
                    if (viewModel.replyingToCommentId != null)
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _buildReplyPreview(context, viewModel),
                            ),
                            TextField(
                              controller: viewModel.commentController,
                              focusNode: viewModel.commentFocus,
                              decoration: InputDecoration(
                                hintText: 'Add your reply...',
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
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
                                          // Before submitting, ensure threadParentId is set correctly
                                          if (viewModel.replyingToCommentId != widget.parentComment.id) {
                                            debugPrint('Ensuring thread parent context is preserved');
                                            // Make sure we're in thread context before submitting
                                            viewModel.setThreadParentComment(widget.parentComment);
                                          }
                                          
                                          final success = await viewModel.submitComment();
                                          if (success && context.mounted) {
                                            // After submitting in thread view, we want to keep replying to the thread parent
                                            // but the text field should be cleared
                                            viewModel.commentController.clear();
                                            
                                            // Show a success message
                                            SnackbarHelper.showSuccess(context, 'Reply added to thread');
                                          } else if (!success && context.mounted) {
                                            // Show error message
                                            SnackbarHelper.showError(context, 'Failed to post reply. Please try again.');
                                          }
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DiscussionComment>> _fetchSubLevelComments(String commentId) async {
    try {
      // Fetch ALL sub-level replies to the triggering comment and their children
      final subLevelReplies = await _discussionService.getSubLevelReplies(
        widget.parentComment.discussionId,
        commentId
      );

      debugPrint("Fetched ${subLevelReplies.length} sub-level replies for commentId: $commentId");

      // To ensure we have the complete hierarchy, also fetch any replies to these replies
      List<DiscussionComment> allReplies = List.from(subLevelReplies);
      
      for (var reply in subLevelReplies) {
        // For each direct reply, check if it has any children
        if (reply.replyCount > 0) {
          // Recursively fetch the entire sub-tree
          final childReplies = await _recursivelyFetchReplies(reply.id);
          allReplies.addAll(childReplies);
        }
      }

      // Set appropriate levels for UI rendering
      final processedComments = allReplies.map((reply) {
        // Calculate level relative to parent comment
        int relativeLevel;
        
        if (reply.parentId == commentId) {
          // Direct child of the parent comment (level 1)
          relativeLevel = 1;
        } else {
          // Find the path from this comment back to the parent
          relativeLevel = _calculateRelativeLevel(reply, commentId, allReplies) + 1;
        }
        
        return reply.copyWith(
          isExpanded: true,
          level: relativeLevel 
        );
      }).toList();

      return processedComments;
    } catch (e) {
      debugPrint('Error fetching sub-level comments: $e');
      return [];
    }
  }
  
  // Helper method to recursively fetch all replies
  Future<List<DiscussionComment>> _recursivelyFetchReplies(String commentId) async {
    final directReplies = await _discussionService.getSubLevelReplies(
      widget.parentComment.discussionId, 
      commentId
    );
    
    List<DiscussionComment> allReplies = List.from(directReplies);
    
    for (var reply in directReplies) {
      if (reply.replyCount > 0) {
        final childReplies = await _recursivelyFetchReplies(reply.id);
        allReplies.addAll(childReplies);
      }
    }
    
    return allReplies;
  }
  
  // Calculate the level of a comment relative to a parent
  int _calculateRelativeLevel(DiscussionComment comment, String parentId, List<DiscussionComment> allComments) {
    // Base case: direct child of parent
    if (comment.parentId == parentId) return 1;
    
    // Keep track of visited comment IDs to prevent infinite loops
    Set<String> visited = <String>{comment.id};
    
    // Iterative approach to find the path to the parent
    int level = 0;
    String? currentParentId = comment.parentId;
    
    while (currentParentId != null && !visited.contains(currentParentId)) {
      // If we've reached the target parent, return the level
      if (currentParentId == parentId) {
        return level + 1;
      }
      
      // Find the parent comment
      final parentComment = allComments.firstWhereOrNull(
        (c) => c.id == currentParentId
      );
      
      // If we can't find the parent or it has no parent, break
      if (parentComment == null) break;
      
      // Mark this parent as visited
      visited.add(currentParentId);
      
      // Move up one level
      level++;
      currentParentId = parentComment.parentId;
    }
    
    // If we couldn't find a path to the parent, assume it's a direct reply
    return 1;
  }

  void _initializeSubLevelComments(String commentId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch sub-level comments
      final subLevelComments = await _fetchSubLevelComments(commentId);
      debugPrint("Initializing ViewModel with ${subLevelComments.length} sub-level comments for commentId: $commentId");

      // Filter out the parent comment itself - we're showing it separately in the header
      List<DiscussionComment> filteredComments = subLevelComments.where(
        (comment) => comment.id != widget.parentComment.id
      ).toList();
      
      debugPrint("Filtered out parent comment, remaining: ${filteredComments.length} comments");
      
      // Adjust all comment levels relative to the thread context
      // In thread view, we want to present these as a fresh hierarchy
      filteredComments = filteredComments.map((comment) {
        // Calculate the new level relative to this thread
        int newLevel;
        
        if (comment.parentId == widget.parentComment.id) {
          // Direct replies to the parent comment should be at level 0 in this context
          newLevel = 0;
        } else {
          // For deeper nested replies, calculate their level relative to direct replies
          final relativeLevel = _calculateRelativeLevel(comment, widget.parentComment.id, filteredComments);
          // Their level should be their relative level minus 1 (because direct replies are at level 0)
          newLevel = relativeLevel - 1;
          if (newLevel < 0) newLevel = 0; // Ensure no negative levels
        }
        
        return comment.copyWith(
          level: newLevel,
          isExpanded: true
        );
      }).toList();
      
      // Debug the adjusted comments
      for (var comment in filteredComments) {
        debugPrint('Adjusted comment ${comment.id}: parentId=${comment.parentId}, level=${comment.level}');
      }

      // Initialize the view model with the adjusted comments
      _viewModel.initializeWithSubLevelComments(filteredComments);
      
      // Mark the thread as initialized so the UI updates
      _viewModel.markThreadAsInitialized();

      // Force a refresh after initialization
      if (mounted) {
        setState(() {
          _isLoading = false;
          debugPrint('Thread detail page initialized with ${_viewModel.comments.length} comments');
        });
      }

      // Debug current state
      _debugViewModelState();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error initializing thread view: $e');
    }
  }

  void _debugViewModelState() {
    _viewModel.debugCommentHierarchy();
  }

  List<Widget> _buildCommentList(
    BuildContext context,
    List<DiscussionComment> comments,
  ) {
    // In thread detail page, we don't need to calculate relative to parent level
    // The comment levels have already been adjusted in _initializeSubLevelComments
    return comments.map((comment) {
      // Use the comment's level directly for indentation (it's already been normalized)
      final paddingLevel = comment.level;
      
      return Padding(
        padding: EdgeInsets.only(left: paddingLevel * 16.0),
        child: DiscussionCommentTile(
          comment: comment,
          onVote: (isUpvote) async {
            // Ensure thread context is preserved during vote
            await _viewModel.voteCommentInThread(
              comment.id,
              isUpvote,
              widget.parentComment.id,
            );
          },
          onReply: () => _viewModel.startReplyingTo(comment.id),
          onToggleExpand: (commentId, isExpanded) => 
              _viewModel.toggleCommentExpansion(commentId),
          indentWidth: 32.0,
          isLastSibling: comment == comments.last,
          isHighlighted: comment.id == widget.highlightCommentId,
          key: ValueKey('thread-${comment.id}'),
        ),
      );
    }).toList();
  }

  Widget _buildReplyPreview(BuildContext context, DiscussionDetailsViewModel viewModel) {
    final parentComment = viewModel.getCommentById(viewModel.replyingToCommentId!);
    if (parentComment == null) return const SizedBox.shrink();

    // Determine if we're replying to the thread parent comment
    final isReplyingToThreadParent = parentComment.id == widget.parentComment.id;
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReplyingToThreadParent 
                    ? 'Replying to thread' 
                    : 'Replying to ${parentComment.authorName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                parentComment.content.length > 100
                    ? '${parentComment.content.substring(0, 100)}...'
                    : parentComment.content,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // In thread view, only show Cancel if not replying to the thread parent
        if (!isReplyingToThreadParent)
          TextButton(
            onPressed: viewModel.cancelReply,
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}
