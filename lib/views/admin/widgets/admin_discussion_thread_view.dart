import 'package:flutter/material.dart';
import '../../../models/entities/discussion_comment.dart';
import 'admin_discussion_comment_tile.dart';

class AdminDiscussionThreadView extends StatefulWidget {
  final DiscussionComment comment;
  final List<DiscussionComment> allComments;
  final VoidCallback onDelete;
  final VoidCallback onBack;
  final Function(String, bool) onToggleExpand;
  final Map<String, bool> expandedComments;
  final Future<void> Function() onRefresh;

  const AdminDiscussionThreadView({
    super.key,
    required this.comment,
    required this.allComments,
    required this.onDelete,
    required this.onBack,
    required this.onToggleExpand,
    required this.expandedComments,
    required this.onRefresh,
  });

  @override
  State<AdminDiscussionThreadView> createState() => _AdminDiscussionThreadViewState();
}

class _AdminDiscussionThreadViewState extends State<AdminDiscussionThreadView> {
  final ScrollController _scrollController = ScrollController();
  DiscussionComment? _nestedThreadComment;
  List<DiscussionComment> _nestedThreadReplies = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // First trigger the parent refresh and wait for it to complete
    await widget.onRefresh();
    
    // Only update state if the widget is still mounted
    if (mounted) {
      setState(() {
        // Clear nested thread state to force rebuild with fresh data
        _nestedThreadComment = null;
        _nestedThreadReplies = [];
      });
    }
  }

  // Helper method to build the comment tree
  Map<String, List<DiscussionComment>> _buildCommentTree() {
    final Map<String, List<DiscussionComment>> commentTree = {};
    
    // Get all comments that are part of this thread
    final threadComments = widget.allComments.where((c) => 
      c.parentId == widget.comment.id || // Direct replies to thread parent
      widget.allComments.any((parent) => parent.id == c.parentId) // Nested replies
    ).toList();
    
    // Build the tree structure
    for (var comment in threadComments) {
      final parentId = comment.parentId ?? '';
      commentTree.putIfAbsent(parentId, () => []);
      if (!commentTree[parentId]!.any((c) => c.id == comment.id)) {
        commentTree[parentId]!.add(comment);
      }
    }

    // Sort each level by date
    commentTree.forEach((_, comments) {
      comments.sort((a, b) => a.datePosted.compareTo(b.datePosted));
    });

    return commentTree;
  }

  void _openNestedThread(DiscussionComment parentComment, List<DiscussionComment> replies) {
    setState(() {
      _nestedThreadComment = parentComment;
      _nestedThreadReplies = [parentComment, ...replies];
    });
  }

  Widget _buildCommentBranch(DiscussionComment comment, Map<String, List<DiscussionComment>> tree, int level) {
    final directReplies = tree[comment.id] ?? [];
    final isExpanded = widget.expandedComments[comment.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminDiscussionCommentTile(
          key: ValueKey('comment_${comment.id}_${isExpanded}_$level'),
          comment: comment,
          replies: directReplies,
          allComments: widget.allComments,
          onDelete: widget.onDelete, // Each comment gets the same delete callback
          onViewThread: _openNestedThread,
          onToggleExpand: widget.onToggleExpand,
          isExpanded: isExpanded,
          isLastSibling: true,
          nestingLevel: level,
          disableNestedReplies: true,
        ),
        if (directReplies.isNotEmpty && isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: directReplies.map((reply) => 
                _buildCommentBranch(reply, tree, level + 1)
              ).toList(),
            ),
          ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final replyCount = widget.allComments.length - 1; // Excluding the parent comment

    if (_nestedThreadComment != null) {
      return AdminDiscussionThreadView(
        comment: _nestedThreadComment!,
        allComments: _nestedThreadReplies,
        onDelete: widget.onDelete,
        onBack: () {
          setState(() {
            _nestedThreadComment = null;
            _nestedThreadReplies = [];
          });
        },
        onToggleExpand: widget.onToggleExpand,
        expandedComments: widget.expandedComments,
        onRefresh: _refresh, // Use local refresh handler
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Back to discussion',
              ),
              const SizedBox(width: 8),
              Text(
                'Thread',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh, // Use local refresh handler
                tooltip: 'Refresh comments',
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: () => _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
                tooltip: 'Back to top',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Thread parent comment
              AdminDiscussionCommentTile(
                key: ValueKey('thread_${widget.comment.id}_${widget.expandedComments[widget.comment.id]}'),
                comment: widget.comment,
                replies: _buildCommentTree()[widget.comment.id] ?? [],
                allComments: widget.allComments,
                onDelete: widget.onDelete,
                onViewThread: _openNestedThread,
                onToggleExpand: widget.onToggleExpand,
                isExpanded: widget.expandedComments[widget.comment.id] ?? false,
                isLastSibling: false,
                nestingLevel: 0,
                disableNestedReplies: true,
              ),
              if ((_buildCommentTree()[widget.comment.id] ?? []).isNotEmpty && 
                  (widget.expandedComments[widget.comment.id] ?? false))
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (_buildCommentTree()[widget.comment.id] ?? [])
                      .map((reply) => _buildCommentBranch(
                        reply, 
                        _buildCommentTree(), 
                        1
                      )).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}