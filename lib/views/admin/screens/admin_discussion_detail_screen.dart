import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'dart:async';
import '../../../models/entities/discussion_post.dart';
import '../../../models/entities/discussion_comment.dart';
import '../../../models/services/discussion_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/ai_summary_card.dart';
import '../widgets/admin_discussion_comment_tile.dart';
import '../widgets/admin_discussion_thread_view.dart';
import '../widgets/discussion_sentiment_stats_card.dart';

class AdminDiscussionDetailScreen extends StatefulWidget {
  final DiscussionPost discussion;
  final String? highlightedCommentId;

  const AdminDiscussionDetailScreen({
    super.key,
    required this.discussion,
    this.highlightedCommentId,
  });

  @override
  State<AdminDiscussionDetailScreen> createState() => _AdminDiscussionDetailScreenState();
}

class _AdminDiscussionDetailScreenState extends State<AdminDiscussionDetailScreen> {
  final DiscussionService _discussionService = DiscussionService();
  final ScrollController _commentsScrollController = ScrollController();
  final Map<String, bool> _expandedComments = {};
  bool _isLoading = false;
  bool _isLoadingAISummary = false;
  bool _hasGeneratedSummary = false;
  String _aiSummary = '';
  List<DiscussionComment> _allComments = [];
  DiscussionComment? _selectedThreadComment;
  List<DiscussionComment> _selectedThreadReplies = [];

  Future<void> generateSummary() async {
    if (!mounted || _allComments.isEmpty) {
      setState(() {
        _isLoadingAISummary = false;
        _aiSummary = '';
        _hasGeneratedSummary = false;
      });
      return;
    }

    setState(() {
      _isLoadingAISummary = true;
      _aiSummary = '';
      _hasGeneratedSummary = false;
    });

    try {
      // Initialize Gemini model
      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash-002'
      );

      // Build hierarchical comment text
      final commentTexts = _buildHierarchicalCommentText(_allComments);
      
      // Create prompt with formatting requirements
      final prompt = [
        Content.text(
          """
          You are analyzing a discussion from Ashesi University's student e-participation platform, where students engage with their Student Council on various campus matters. This platform facilitates open dialogue between students and their representatives, helping build a more engaged campus community.

          Your task is to summarize this discussion thread in a way that helps both students and council members understand the key points and community sentiment. The discussion format shows reply relationships with '>' indicating responses to previous comments.

          Context (Discussion): ${widget.discussion.plainContent}

          Discussion thread to analyze:
          $commentTexts

          Generate a structured summary in this exact markdown format:

          ##### **Main Discussion Points**
          * [1-3 key discussion points, one per bullet]

          ##### **Student Perspectives**
          * [1-3 main viewpoints expressed by the community]

          ##### **Areas of Agreement**
          * [1-2 points where students found common ground]

          ##### **Areas of Debate**
          * [1-2 main points of contention or differing viewpoints]

          ##### **Actionable Suggestions**
          * [1-2 concrete suggestions for the Student Council or community]

          Requirements:
          - Use exactly the markdown headings shown above (##### and ** for each heading)
          - Use markdown bullet points (*)
          - Keep each bullet point to 1-2 sentences maximum
          - Use clear, objective language
          - Focus on how ideas developed through replies
          - Capture the flow of conversation and how viewpoints evolved
          - If a section has no relevant points, remove it altogether
          - Maintain neutral tone throughout
          - Never mention comment counts or use phrases like "users say" or "participants mention"
          - Ensure there is a blank line after each heading and between bullet points
          - Frame suggestions in the context of student council and campus improvement
          - Use as little bullet points as possible. This does not mean to always use the lowest number. Gauge the content of discussion and how many bullet points are needed.
          """
        )
      ];

      // Cancel any existing subscription
      _summaryStreamSubscription?.cancel();
      _aiSummary = '';

      // Stream the summary with haptic feedback
      await for (final chunk in model.generateContentStream(prompt)) {
        if (!mounted) break;
        
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          HapticFeedback.lightImpact();
        }
        
        setState(() {
          _aiSummary += chunk.text ?? '';
        });
      }

      // Mark as complete
      setState(() {
        _isLoadingAISummary = false;
        _hasGeneratedSummary = true;
      });
    } catch (e) {
      debugPrint('Error generating summary: $e');
      setState(() {
        _aiSummary = 'Unable to generate summary at this time.';
        _isLoadingAISummary = false;
        _hasGeneratedSummary = false;
      });
    }
  }

  // Helper method to build hierarchical comment text
  String _buildHierarchicalCommentText(List<DiscussionComment> comments, [String indent = '']) {
    final buffer = StringBuffer();
    
    for (final comment in comments) {
      buffer.writeln('$indent${comment.content}');
      
      // Add replies with increased indent for thread context
      if (comment.replies.isNotEmpty) {
        buffer.write(_buildHierarchicalCommentText(comment.replies, '$indent> '));
      }
    }
    
    return buffer.toString();
  }

  StreamSubscription<GenerateContentResponse>? _summaryStreamSubscription;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    
    // If a comment ID is provided to highlight, find and expand it
    if (widget.highlightedCommentId != null) {
      // We'll handle this after comments are loaded
      debugPrint('Will highlight comment: ${widget.highlightedCommentId}');
    }
  }

  Future<void> _fetchComments() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final comments = await _discussionService.getCommentsSync(widget.discussion.id);
      
      if (!mounted) return;
      
      setState(() {
        _allComments = comments.map((comment) => 
          comment.copyWith(isExpanded: _expandedComments[comment.id] ?? false)
        ).toList();
        
        // Update thread view if active
        if (_selectedThreadComment != null) {
          // Find the updated version of the thread parent comment
          final updatedThreadComment = comments.firstWhere(
            (c) => c.id == _selectedThreadComment!.id,
            orElse: () => _selectedThreadComment!
          );
          
          // Get all replies that belong to this thread
          final threadReplies = comments.where((c) => 
            _selectedThreadReplies.any((old) => old.id == c.id)
          ).toList();
          
          _selectedThreadComment = updatedThreadComment;
          _selectedThreadReplies = [updatedThreadComment, ...threadReplies];
        }
        
        // If we have a highlighted comment ID, find and expand it
        if (widget.highlightedCommentId != null) {
          // Find the highlighted comment if it exists
          final highlightedCommentList = comments.where(
            (c) => c.id == widget.highlightedCommentId
          ).toList();
          final highlightedComment = highlightedCommentList.isNotEmpty ? highlightedCommentList.first : null;
          
          if (highlightedComment != null) {
            debugPrint('Found highlighted comment, showing it');
            // If it's a child comment, need to find its parent
            if (highlightedComment.parentId != null) {
              // Find the parent comment if it exists
              final parentCommentList = comments.where(
                (c) => c.id == highlightedComment.parentId
              ).toList();
              final parentComment = parentCommentList.isNotEmpty ? parentCommentList.first : null;
              
              if (parentComment != null) {
                // Expand the parent and show the thread view
                _toggleCommentExpansion(parentComment.id, true);
                _selectedThreadComment = parentComment;
                _selectedThreadReplies = [
                  parentComment,
                  ...comments.where((c) => c.parentId == parentComment.id)
                ];
              }
            } else {
              // It's a top-level comment
              _toggleCommentExpansion(highlightedComment.id, true);
            }
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load comments: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildSentimentChip(BuildContext context) {
    if (widget.discussion.sentimentScore == null || widget.discussion.sentimentMagnitude == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final interpretation = widget.discussion.sentimentInterpretation;
    if (interpretation == null) return const SizedBox.shrink();

    final parts = interpretation.split(' | ');
    if (parts.length != 2) return const SizedBox.shrink();

    final sentiment = parts[0];
    final intensity = parts[1];

    Color getChipColor() {
      if (widget.discussion.sentimentScore! >= 0.5) {
        return Colors.green.withValues(alpha:0.2);
      } else if (widget.discussion.sentimentScore! > 0.1) {
        return Colors.lightGreen.withValues(alpha:0.2);
      } else if (widget.discussion.sentimentScore! >= -0.1) {
        return Colors.grey.withValues(alpha:0.2);
      } else if (widget.discussion.sentimentScore! >= -0.5) {
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
Score (${widget.discussion.sentimentScore?.toStringAsFixed(2)}): Indicates the overall emotional leaning
• -1.0 to -0.5: Very Negative
• -0.5 to -0.1: Negative
• -0.1 to 0.1: Neutral
• 0.1 to 0.5: Positive
• 0.5 to 1.0: Very Positive

Magnitude (${widget.discussion.sentimentMagnitude?.toStringAsFixed(2)}): Measures emotional intensity
• 0.0 to 1.0: Mild emotion
• 1.0 to 2.0: Moderate emotion
• 2.0+: Strong emotion''',
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentsScrollController.dispose();
    _summaryStreamSubscription?.cancel();
    super.dispose();
  }

  void _toggleCommentExpansion(String commentId, bool isExpanded) {
    setState(() {
      _expandedComments[commentId] = isExpanded;
      // Update the expansion state in _allComments
      _allComments = _allComments.map((comment) {
        if (comment.id == commentId) {
          return comment.copyWith(isExpanded: isExpanded);
        }
        return comment;
      }).toList();
    });
  }

  Future<void> _deleteDiscussion() async {
    final navigator = Navigator.of(context);
    try {
      await _discussionService.deleteDiscussion(widget.discussion.id);
      if (mounted) {
        navigator.pop(); // Go back to discussions list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discussion deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete discussion: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      // Find the comment before deleting it
      final commentToDelete = _allComments.firstWhere((c) => c.id == commentId);
      
      // Delete from backend first
      await _discussionService.deleteComment(widget.discussion.id, commentId);
      
      if (mounted) {
        setState(() {
          // Remove only the specific comment
          _allComments.removeWhere((c) => c.id == commentId);
          
          // If we're in thread view
          if (_selectedThreadComment != null) {
            if (_selectedThreadComment!.id == commentId) {
              // If the deleted comment was the thread parent, exit thread view
              _selectedThreadComment = null;
              _selectedThreadReplies = [];
            } else {
              // If a reply was deleted, just remove it from the thread replies
              _selectedThreadReplies.removeWhere((c) => c.id == commentId);
            }
          }
          
          // Update parent's reply count if this was a reply
          if (commentToDelete.parentId != null) {
            final parentIndex = _allComments.indexWhere((c) => c.id == commentToDelete.parentId);
            if (parentIndex != -1) {
              _allComments[parentIndex] = _allComments[parentIndex].copyWith(
                replyCount: _allComments[parentIndex].replyCount - 1
              );
            }
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete comment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Discussion',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Discussion'),
                  content: const Text('Are you sure you want to delete this discussion? This action cannot be undone.'),
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
                        _deleteDiscussion();
                      },
                      child: const Text('DELETE'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Discussion content
          Expanded(
            flex: 3,
            child: _buildDiscussionContent(theme),
          ),
          // Vertical divider
          const VerticalDivider(width: 1),
          // Right side - Comments
          Expanded(
            flex: 2,
            child: _buildCommentsPanel(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                imageUrl: widget.discussion.authorAvatar,
                radius: 24,
                fallbackInitial: widget.discussion.authorName.substring(0, 1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.discussion.authorName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.discussion.authorClass,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              _buildSentimentChip(context),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QuillEditor(
              controller: QuillController(
                document: Document.fromJson(
                  widget.discussion.content is List 
                    ? widget.discussion.content 
                    : widget.discussion.content['ops'] as List? ?? [{'insert': widget.discussion.plainContent}]
                ),
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
          ),
          const SizedBox(height: 16),
          Text(
            timeago.format(widget.discussion.datePosted),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                context: context,
                icon: Icons.arrow_upward_rounded,
                label: widget.discussion.upvotes.toString(),
                tooltip: 'Upvotes',
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                context: context,
                icon: Icons.arrow_downward_rounded,
                label: widget.discussion.downvotes.toString(),
                tooltip: 'Downvotes',
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                context: context,
                icon: Icons.reply,
                label: widget.discussion.replyCount.toString(),
                tooltip: 'Replies',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 32),
          AISummaryCard(
            isLoading: _isLoadingAISummary,
            summary: _aiSummary,
            commentCount: _allComments.length,
            onGenerateSummary: generateSummary,
            hasGeneratedSummary: _hasGeneratedSummary,
          ),
          if (!_hasGeneratedSummary && 
              !_isLoadingAISummary && 
              _allComments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: generateSummary,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Summary'),
                ),
              ),
            ),
          const SizedBox(height: 24),
          DiscussionSentimentStatsCard(
            comments: _allComments,
            discussionSentimentScore: widget.discussion.sentimentScore,
            discussionSentimentMagnitude: widget.discussion.sentimentMagnitude,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsPanel(ThemeData theme) {
    if (_selectedThreadComment != null) {
      return AdminDiscussionThreadView(
        comment: _selectedThreadComment!,
        allComments: _selectedThreadReplies,
        onDelete: () => _deleteComment(_selectedThreadComment!.id),
        onBack: () {
          setState(() {
            _selectedThreadComment = null;
            _selectedThreadReplies = [];
          });
          _fetchComments(); // Refresh comments when returning from thread
        },
        onToggleExpand: _toggleCommentExpansion,
        expandedComments: _expandedComments,
        onRefresh: _fetchComments,
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_allComments.isEmpty) {
      return Center(
        child: Text(
          'No comments yet',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Build comment tree
    final topLevelComments = _allComments.where((c) => c.parentId == null).toList()
      ..sort((a, b) => b.datePosted.compareTo(a.datePosted));

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
              Text(
                'Comments',
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
                  _allComments.length.toString(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchComments,
                tooltip: 'Refresh comments',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _commentsScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: topLevelComments.length,
            itemBuilder: (context, index) {
              final comment = topLevelComments[index];
              final replies = _allComments
                  .where((c) => c.parentId == comment.id)
                  .toList()
                ..sort((a, b) => a.datePosted.compareTo(b.datePosted));
              
              return AdminDiscussionCommentTile(
                key: ValueKey('${comment.id}-${comment.isExpanded}'),
                comment: comment,
                replies: replies,
                allComments: _allComments,
                onDelete: () => _deleteComment(comment.id),
                onViewThread: (parentComment, threadReplies) {
                  debugPrint('Opening thread view for comment: ${parentComment.id} with ${threadReplies.length} replies');
                  // Get only the relevant comments for this thread
                  final relevantComments = [parentComment, ...threadReplies];
                  setState(() {
                    _selectedThreadComment = parentComment;
                    _selectedThreadReplies = relevantComments;
                  });
                },
                onToggleExpand: _toggleCommentExpansion,
                isExpanded: comment.isExpanded,
                isLastSibling: index == topLevelComments.length - 1,
                nestingLevel: 0,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}