import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/entities/discussion_post.dart';
import '../models/entities/discussion_comment.dart';
import '../models/services/discussion_service.dart';
import '../models/services/bookmark_service.dart';
import 'package:collection/collection.dart';
import '../models/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

import 'home_viewmodel.dart';
import '../widgets/snackbar_helper.dart';

class DiscussionDetailsViewModel extends ChangeNotifier {
  final DatabaseService _userService = DatabaseService();
  DiscussionPost _discussion;
  final TextEditingController commentController = TextEditingController();
  final FocusNode commentFocus = FocusNode();
  List<DiscussionComment> _comments = [];
  bool _isLoadingAISummary = false;
  bool _isBookmarked = false;
  bool _canSubmitComment = false;
  bool _isLoadingComments = false;
  bool _mounted = true;
  String? _replyingToCommentId;
  String? _replyingToCommentContent;
  String _aiSummary = '';
  final DiscussionService _discussionService = DiscussionService();
  StreamSubscription<List<DiscussionComment>>? _commentsSubscription;
  StreamSubscription<GenerateContentResponse>? _summaryStreamSubscription;
  List<DiscussionComment> _flatComments = [];
  bool _isSendingComment = false;
  String? _threadParentCommentId;
  bool _isThreadInitialized = false;
  bool _isInitialized = false;
  bool _hasGeneratedSummary = false;
  final BuildContext context;

  // Add character limit properties
  final int characterLimit = 500;
  int get characterCount => commentController.text.length;
  bool get isOverCharacterLimit => characterCount > characterLimit;

  // Getters
  DiscussionPost get discussion => _discussion;
  List<DiscussionComment> get comments => _comments;
  bool get isLoadingAISummary => _isLoadingAISummary;
  bool get isBookmarked => _isBookmarked;
  bool get canSubmitComment => !isSendingComment && commentController.text.trim().isNotEmpty && !isOverCharacterLimit;
  bool get isLoadingComments => _isLoadingComments;
  String? get replyingToCommentId => _replyingToCommentId;
  String? get replyingToCommentContent => _replyingToCommentContent;
  String get aiSummary => _aiSummary;
  bool get isSendingComment => _isSendingComment;
  bool get isCommentFocused => commentFocus.hasFocus;
  bool get isThreadInitialized => _isThreadInitialized;
  bool get hasGeneratedSummary => _hasGeneratedSummary;

  DiscussionDetailsViewModel(this._discussion, this.context) {
    commentController.addListener(_updateCanSubmit);
    commentController.addListener(() {
      notifyListeners();
    });
    
    _initializeAfterTransition();
    loadBookmarkState(); // Add this line to initialize bookmark state
  }
  
  // New method to initialize data after the transition
  void _initializeAfterTransition() {
    if (_isInitialized) return;
    
    // Use Future.microtask to ensure this runs after the current frame
    Future.microtask(() {
      if (!_mounted) return;
      
      // Now we can start loading comments
      _loadComments();
      _isInitialized = true;
    });
  }

  DiscussionComment? getCommentById(String id) {
    return _flatComments.firstWhereOrNull((c) => c.id == id);
  }

  void startReplyingTo(String commentId) {
    final comment = getCommentById(commentId);
    if (comment != null) {
      _replyingToCommentId = commentId;
      _replyingToCommentContent = comment.content;
      
      // Set the thread parent ID for thread organization purposes
      // If this is a reply to a child comment, preserve the proper hierarchy
      final topLevelAncestor = _findTopLevelAncestor(commentId);
      _threadParentCommentId = topLevelAncestor;
      
      debugPrint('Starting reply to commentId: $commentId (threadParent: $_threadParentCommentId)');
      commentFocus.requestFocus();
      _safeNotifyListeners();
    } else {
      debugPrint('Cannot reply to comment: $commentId - not found');
    }
  }
  
  // Helper method to find the top-level ancestor of a comment
  String _findTopLevelAncestor(String commentId) {
    DiscussionComment? current = getCommentById(commentId);
    if (current == null) return commentId;
    
    // If this is already a top-level comment
    if (current.parentId == null) return commentId;
    
    // Traverse up until we find a comment with no parent
    String topLevelId = commentId; // Changed from String? to String
    String? currentId = commentId;
    
    while (current != null && current.parentId != null) {
      currentId = current.parentId;
      current = getCommentById(currentId!);
      if (current != null && current.parentId == null) {
        topLevelId = currentId;
        break;
      }
    }
    
    return topLevelId; // Now this always returns a non-null String
  }

  void cancelReply() {
    _replyingToCommentId = null;
    _replyingToCommentContent = null;
    _threadParentCommentId = null;
    _safeNotifyListeners();
  }

  void toggleCommentExpansion(String commentId) {
    _comments = _toggleExpansionRecursively(_comments, commentId);
    _safeNotifyListeners();
  }

  List<DiscussionComment> _toggleExpansionRecursively(List<DiscussionComment> comments, String commentId) {
    List<DiscussionComment> updatedComments = [];
    
    for (final comment in comments) {
      if (comment.id == commentId) {
        // Toggle this comment's expanded state
        updatedComments.add(comment.copyWith(isExpanded: !comment.isExpanded));
      } else {
        // Check if the target comment is in this comment's replies
        final updatedReplies = _toggleExpansionRecursively(comment.replies, commentId);
        
        // If the replies were modified, update this comment with the new replies
        if (!identical(updatedReplies, comment.replies)) {
          updatedComments.add(comment.copyWith(replies: updatedReplies));
        } else {
          updatedComments.add(comment);
        }
      }
    }
    
    return updatedComments;
  }

  Future<bool> submitComment() async {
    if (!canSubmitComment) return false;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;
    final user = await _userService.getUser(firebaseUser.uid);
    if (user == null) return false;

    try {
      // Store current expansion states and scroll position
      final Map<String, bool> expansionStates = {};
      _collectExpansionStates(_comments, expansionStates);
      
      // Store the thread context and reply context before submission
      _isSendingComment = true;
      _safeNotifyListeners();

      // Get the comment being replied to
      final replyingToComment = _replyingToCommentId != null 
          ? getCommentById(_replyingToCommentId!) 
          : null;

      // Save the comment text before clearing
      final commentText = commentController.text.trim();
      
      // Clear comment field immediately for better UX
      commentController.clear();

      // Optimistically update local state
      final optimisticId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
      final optimisticComment = DiscussionComment(
        id: optimisticId,
        parentId: _replyingToCommentId,
        threadParentId: _threadParentCommentId,
        discussionId: _discussion.id,
        authorId: user.uid,
        authorName: '${user.firstName} ${user.lastName}',
        authorAvatar: user.photoURL ?? '',
        authorClass: user.classYear,
        content: commentText,
        datePosted: DateTime.now(),
        replies: [],
        level: replyingToComment != null ? replyingToComment.level + 1 : 0,
      );

      debugPrint('Adding optimistic comment with ID: ${optimisticComment.id}');
      _flatComments.add(optimisticComment.copyWith(isOptimistic: true));  // Ensure isOptimistic is true
      
      // Handle tree building with the optimistic comment
      if (_threadParentCommentId == null && _replyingToCommentId != null) {
        _comments = _setCommentExpansion(_comments, _replyingToCommentId!, true);
      }

      if (_threadParentCommentId != null) {
        ensureThreadContextPreserved();
      } else {
        _buildCommentTree(_flatComments);
        _comments = _applyExpansionStates(_comments, expansionStates);
        
        if (_replyingToCommentId != null) {
          _comments = _setCommentExpansion(_comments, _replyingToCommentId!, true);
        }
      }
      
      _safeNotifyListeners();

      // Submit to Firestore
      await _discussionService.createComment(
        discussionId: _discussion.id,
        content: commentText,
        authorId: user.uid,
        parentId: _replyingToCommentId,
        threadParentId: _threadParentCommentId,
      );

      // Show success snackbar
      _showSnackBar('Comment posted successfully');
      
      if (_threadParentCommentId != null && _replyingToCommentId != _threadParentCommentId) {
        _replyingToCommentId = _threadParentCommentId;
        _replyingToCommentContent = getCommentById(_threadParentCommentId!)?.content;
      } else if (_threadParentCommentId == null) {
        _replyingToCommentId = null;
        _replyingToCommentContent = null;
      }
      
      _isSendingComment = false;
      _safeNotifyListeners();
      
      return true;
    } catch (e) {
      _isSendingComment = false;
      _showSnackBar('Failed to post comment. Please try again.');
      _safeNotifyListeners();
      debugPrint('Error creating comment: $e');
      return false;
    }
  }
  
  // Helper method to set expansion state for a specific comment
  List<DiscussionComment> _setCommentExpansion(List<DiscussionComment> comments, String commentId, bool isExpanded) {
    List<DiscussionComment> updatedComments = [];
    
    for (final comment in comments) {
      if (comment.id == commentId) {
        // Set this comment's expanded state
        updatedComments.add(comment.copyWith(isExpanded: isExpanded));
      } else {
        // Check if the target comment is in this comment's replies
        final updatedReplies = _setCommentExpansion(comment.replies, commentId, isExpanded);
        
        // If the replies were modified, update this comment with the new replies
        if (!identical(updatedReplies, comment.replies)) {
          updatedComments.add(comment.copyWith(replies: updatedReplies));
        } else {
          updatedComments.add(comment);
        }
      }
    }
    
    return updatedComments;
  }

  Future<void> _loadComments() async {
    if (!_mounted) return;
    
    // Now we can set the loading state since the transition should be complete
    _isLoadingComments = true;
    _safeNotifyListeners();

    _commentsSubscription?.cancel();
    
    // Create a stream subscription that filters comments based on context
    _commentsSubscription = _discussionService
        .getComments(_discussion.id)
        .listen(
          (comments) {
            // Store the original state before update
            final originalThreadParentId = _threadParentCommentId;
            final originalReplyToId = _replyingToCommentId;
            final originalReplyContent = _replyingToCommentContent;
            
            // Check if we're dealing with an optimistic update that's being synced
            final previousCommentIds = Set<String>.from(_flatComments.map((c) => c.id));
            final incomingCommentIds = Set<String>.from(comments.map((c) => c.id));
            final removedIds = previousCommentIds.difference(incomingCommentIds);
            final addedIds = incomingCommentIds.difference(previousCommentIds);
            
            // Check if this update is likely in response to our own comment submission
            final hasOptimisticComment = _flatComments.any((c) => c.id.startsWith('temp-'));
            final justAddedComment = addedIds.length == 1 && removedIds.isEmpty && hasOptimisticComment;
            
            // If we're processing what looks like our own comment submission
            if (justAddedComment) {
              debugPrint('Processing database update for a newly submitted comment');
              
              // Just update the flat comments without triggering a full rebuild
              _updateFlatCommentsSelectively(comments, addedIds.first);
              
              // If we're in a thread detail view, handle it specifically
              if (originalThreadParentId != null && _isThreadInitialized) {
                debugPrint('Maintaining thread context for: $originalThreadParentId');
                
                // Ensure the thread parent ID is restored
                _threadParentCommentId = originalThreadParentId;
                
                // Filter comments and rebuild tree for thread view
                handleDatabaseUpdate(preserveThreadContext: true);
              } else {
                // For regular discussion view, just update optimistically
                handleDatabaseUpdate(preserveThreadContext: false);
              }
            } else {
              // Standard update (not our own comment submission)
              debugPrint('Processing standard database update with ${addedIds.length} new comments');
              
              // Update flat comments list
              _flatComments = comments;
              
              // If we're in a thread detail view, only show comments for that thread
              if (originalThreadParentId != null && _isThreadInitialized) {
                debugPrint('Maintaining thread context for: $originalThreadParentId');
                
                // Ensure the thread parent ID is restored
                _threadParentCommentId = originalThreadParentId;
                
                // Filter comments and rebuild tree for thread view
                handleDatabaseUpdate(preserveThreadContext: true);
              } else {
                // For regular discussion view, restore the reply context
                _replyingToCommentId = originalReplyToId;
                _replyingToCommentContent = originalReplyContent;
                
                handleDatabaseUpdate(preserveThreadContext: false);
              }
            }

            // Update loading state at the end
            _isLoadingComments = false;
            _safeNotifyListeners();
          },
          onError: (e) {
            debugPrint('Error loading comments: $e');
            _isLoadingComments = false;
            _safeNotifyListeners();
          },
        );
  }
  
  // Helper to update flat comments more selectively
  void _updateFlatCommentsSelectively(List<DiscussionComment> newComments, String newCommentId) {
    // Find any temporary comments in the flat list
    final tempComments = _flatComments.where((c) => c.isOptimistic).toList();
    
    if (tempComments.isNotEmpty) {
      for (final tempComment in tempComments) {
        final matchingRealComment = newComments.firstWhereOrNull((c) => 
          !c.isOptimistic && 
          c.parentId == tempComment.parentId && 
          c.content == tempComment.content &&
          c.datePosted.difference(tempComment.datePosted).inSeconds.abs() < 10
        );
        
        if (matchingRealComment != null) {
          debugPrint('Found real comment ${matchingRealComment.id} for optimistic comment ${tempComment.id}');
          // Remove the optimistic comment
          _flatComments.removeWhere((c) => c.id == tempComment.id);
          // Add the real comment if it's not already there
          if (!_flatComments.any((c) => c.id == matchingRealComment.id)) {
            _flatComments.add(matchingRealComment);
          }
        }
      }
    }
  }

  Future<void> voteComment(String commentId, bool isUpvote) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final user = await _userService.getUser(firebaseUser.uid);
    if (user == null) return;

    try {
      // Store current expansion states before updating
      final Map<String, bool> expansionStates = {};
      _collectExpansionStates(_comments, expansionStates);

      // Optimistically update UI first for better UX
      _flatComments = _updateCommentVote(_flatComments, commentId, isUpvote, user.uid);
      _buildCommentTree(_flatComments);
      _comments = _applyExpansionStates(_comments, expansionStates);
      _safeNotifyListeners();

      // Then update backend (still need to wait for response to handle errors)
      await _discussionService.voteComment(
        _discussion.id, 
        commentId,
        isUpvote,
        user.uid
      );
    } catch (e) {
      debugPrint('Error voting comment: $e');
      
      // On error, revert the optimistic update by reloading comments
      _loadComments();
    }
  }

  void _updateCanSubmit() {
    final newValue = commentController.text.trim().isNotEmpty;
    if (_canSubmitComment != newValue) {
      _canSubmitComment = newValue;
      _safeNotifyListeners();
    }
  }

  Future<void> generateSummary() async {
    if (!_mounted || _comments.isEmpty) {
      _isLoadingAISummary = false;
      _aiSummary = '';
      _hasGeneratedSummary = false;
      _safeNotifyListeners();
      return;
    }

    _isLoadingAISummary = true;
    _aiSummary = ''; // Reset summary when starting new generation
    _hasGeneratedSummary = false; // Reset generation state
    _safeNotifyListeners();

    try {
      // Initialize Gemini model
      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash-002'
      );

      // Prepare comments for summarization with hierarchy
      final commentTexts = _buildHierarchicalCommentText(_comments);
      
      // Create prompt with strict formatting requirements
      final prompt = [
        Content.text(
          """
          You are analyzing a discussion from Ashesi University's student e-participation platform, where students engage with their Student Council on various campus matters. This platform facilitates open dialogue between students and their representatives, helping build a more engaged campus community.

          Your task is to summarize this discussion thread in a way that helps both students and council members understand the key points and community sentiment. The discussion format shows reply relationships with '>' indicating responses to previous comments.

          Context (Discussion): ${_discussion.plainContent}

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
          - If a section has no relevant points, remove it altogether."
          - Maintain neutral tone throughout
          - Never mention comment counts or use phrases like "users say" or "participants mention"
          - Ensure there is a blank line after each heading and between bullet points
          - Frame suggestions in the context of student council and campus improvement
          - Use as little bulllet points as possible. This does not mean not to always use the lowest number. Gauge the content of discussion and how many bullet points are needed.
          """
        )
      ];

      // Cancel any existing subscription
      await _summaryStreamSubscription?.cancel();
      _aiSummary = '';

      // Stream the summary with proper await for
      await for (final chunk in model.generateContentStream(prompt)) {
        if (!_mounted) break; // Check if still mounted before updating
        
        // Only trigger haptic feedback if there's actual text content
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          HapticFeedback.lightImpact(); // Subtle haptic feedback as text generates
        }
        
        _aiSummary += chunk.text ?? '';
        _safeNotifyListeners();
      }

      // Mark as complete
      _isLoadingAISummary = false;
      _hasGeneratedSummary = true;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error generating summary: $e');
      _aiSummary = 'Unable to generate summary at this time.';
      _isLoadingAISummary = false;
      _hasGeneratedSummary = false;
      _safeNotifyListeners();
    }
  }

  // Helper method to build hierarchical comment text
  String _buildHierarchicalCommentText(List<DiscussionComment> comments, [String indent = '']) {
    final buffer = StringBuffer();
    
    for (final comment in comments) {
      // Add the comment with its indent level
      buffer.writeln('$indent${comment.content}');
      
      // Add replies with increased indent
      if (comment.replies.isNotEmpty) {
        buffer.write(_buildHierarchicalCommentText(comment.replies, '$indent> '));
      }
    }
    
    return buffer.toString();
  }

  @override
  void dispose() {
    _mounted = false;
    commentController.dispose();
    commentFocus.dispose();
    _commentsSubscription?.cancel();
    _summaryStreamSubscription?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (_mounted) {
      notifyListeners();
    }
  }

  Future<void> voteDiscussion(bool isUpvote) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final wasUpvoted = _discussion.hasUserUpvoted;
      final wasDownvoted = _discussion.hasUserDownvoted;
      
      // Optimistically update UI
      _discussion = _discussion.copyWith(
        upvotes: isUpvote 
            ? (wasUpvoted ? _discussion.upvotes - 1 : _discussion.upvotes + 1)
            : (wasUpvoted ? _discussion.upvotes - 1 : _discussion.upvotes),
        downvotes: !isUpvote 
            ? (wasDownvoted ? _discussion.downvotes - 1 : _discussion.downvotes + 1)
            : (wasDownvoted ? _discussion.downvotes - 1 : _discussion.downvotes),
        hasUserUpvoted: isUpvote && !wasUpvoted,
        hasUserDownvoted: !isUpvote && !wasDownvoted,
        upvoterIds: List<String>.from(_discussion.upvoterIds)
          ..removeWhere((id) => id == user.uid)
          ..addAll(isUpvote && !wasUpvoted ? [user.uid] : []),
        downvoterIds: List<String>.from(_discussion.downvoterIds)
          ..removeWhere((id) => id == user.uid)
          ..addAll(!isUpvote && !wasDownvoted ? [user.uid] : []),
      );
      _safeNotifyListeners();

      // Update backend
      await _discussionService.voteDiscussion(_discussion.id, isUpvote, user.uid);
      
      // Sync with HomeViewModel if available
      if (_mounted && context.mounted) {
        try {
          final homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
          await homeViewModel.updateDiscussionVote(_discussion.id, isUpvote);
        } catch (e) {
          // HomeViewModel might not be available in all contexts
          debugPrint('HomeViewModel not available for sync: $e');
        }
      }
    } catch (e) {
      debugPrint('Error voting discussion: $e');
      // Revert to previous state on error
      await _loadDiscussion();
    }
  }

  Future<void> _loadDiscussion() async {
    try {
      final updatedDiscussion = await _discussionService.getDiscussion(_discussion.id);
      if (updatedDiscussion != null) {
        _discussion = updatedDiscussion;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('Error reloading discussion: $e');
    }
  }

  Future<void> deleteDiscussion() async {
    try {
      await _discussionService.deleteDiscussion(_discussion.id);
      _showSnackBar('Discussion deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete discussion. Please try again.');
      debugPrint('Error deleting discussion: $e');
      rethrow;
    }
  }

  Future<void> reportDiscussion() async {
    try {
      // Contact the backend to report the discussion
      await _discussionService.reportContent(
        contentType: 'discussion',
        contentId: _discussion.id,
        reason: 'Reported by user'
      );
      debugPrint('Discussion reported: ${_discussion.id}');
    } catch (e) {
      debugPrint('Error reporting discussion: $e');
    }
  }

  Future<void> reportComment(String commentId) async {
    try {
      // Contact the backend to report the comment
      await _discussionService.reportContent(
        contentType: 'comment',
        contentId: commentId,
        reason: 'Reported by user'
      );
      debugPrint('Comment reported: $commentId');
    } catch (e) {
      debugPrint('Error reporting comment: $e');
    }
  }

  // Initialize with flat comments (specifically for thread view)
  void initializeWithFlatComments(List<DiscussionComment> comments) {
    // Set the thread parent to the actual parent comment ID
    _threadParentCommentId = comments.isNotEmpty 
        ? comments.first.parentId 
        : null;
    
    // Add the parent comment to flat list if missing
    if (!_flatComments.any((c) => c.id == _threadParentCommentId)) {
      _flatComments.insert(0, comments.first.copyWith(level: 0));
    }
    
    _buildCommentTree(_flatComments);
    
    // Add debug information before building the tree
    debugPrint('Building comment tree with ${comments.length} comments:');
    for (var comment in comments) {
      debugPrint('Comment ${comment.id}: parentId=${comment.parentId}, level=${comment.level}');
    }
    
    // Debug after building tree
    debugPrint('Comment tree built, result: ${_comments.length} top-level comments');
    
    // Expand all comments so direct replies are immediately visible
    _comments = _setAllCommentsExpansion(_comments, true);
    _isLoadingComments = false;
    _safeNotifyListeners();
  }
  
  List<DiscussionComment> getRepliesForComment(String commentId) {
    return _flatComments.where((c) => c.parentId == commentId).toList();
  }

  void _buildCommentTree(List<DiscussionComment> flatComments) {
    try {
      // Ensure the top-level comment is included
      final filteredComments = flatComments;

      // Before building the tree, debug the comments being used
      debugPrint('Building comment tree with ${filteredComments.length} comments');
      
      // Build tree starting from the root (null parentId)
      _comments = _buildTreeRecursively(
        filteredComments,
        null, // Start from the root
        0
      );
      
      // Debug the result
      debugPrint('Built tree with ${_comments.length} top-level comments');
    } catch (e) {
      debugPrint('Error building comment tree: $e');
      _comments = [];
    }
  }

  List<DiscussionComment> _buildTreeRecursively(
    List<DiscussionComment> flatComments,
    String? parentId,
    int level
  ) {
    final children = flatComments
        .where((c) => c.parentId == parentId)
        .map((c) => c.copyWith(level: level))
        .toList();

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final nestedReplies = _buildTreeRecursively(flatComments, child.id, level + 1);
      children[i] = child.copyWith(
        replies: nestedReplies,
        replyCount: nestedReplies.length,
      );
    }
    
    // Sort comments by date (oldest first) for stable ordering
    children.sort((a, b) => a.datePosted.compareTo(b.datePosted));
    
    return children;
  }

  // Helper method to set expansion state for all comments
  List<DiscussionComment> _setAllCommentsExpansion(List<DiscussionComment> comments, bool isExpanded) {
    return comments.map((comment) {
      final updatedReplies = _setAllCommentsExpansion(comment.replies, isExpanded);
      return comment.copyWith(
        isExpanded: isExpanded,
        replies: updatedReplies,
      );
    }).toList();
  }

  void setThreadParentComment(DiscussionComment comment) {
    // Store the previous thread parent ID to check if it's changing
    final previousThreadParentId = _threadParentCommentId;
    _threadParentCommentId = comment.id;
    
    debugPrint('Setting thread parent comment: ${comment.id}');
    
    // In thread detail page, the parent comment is shown separately in the header
    // So we don't need to include it in the comments list
    // We'll ensure to remove it if it somehow got included
    _flatComments = _flatComments.where((c) => c.id != comment.id).toList();
    
    debugPrint('Flat comments count after setting parent: ${_flatComments.length}');
    
    // If we're already in a thread view and have comments, rebuild the tree
    if (_flatComments.isNotEmpty) {
      if (_comments.isEmpty || previousThreadParentId != _threadParentCommentId) {
        // Only rebuild if necessary (empty tree or changed thread parent)
        _buildThreadDetailCommentTree(_flatComments);
      }
    }
    
    // Initialize the reply context to the thread parent
    startReplyingTo(comment.id);
  }

  // Debug method to help diagnose comment hierarchy issues
  void debugCommentHierarchy() {
    debugPrint('=== COMMENT HIERARCHY ===');
    debugPrint('Total flat comments: ${_flatComments.length}');
    debugPrint('Total tree comments: ${_countCommentsInTree(_comments)}');
    
    // Print top level comments
    for (var comment in _comments) {
      _debugPrintComment(comment, 0);
    }
    debugPrint('========================');
  }
  
  int _countCommentsInTree(List<DiscussionComment> comments) {
    int count = comments.length;
    for (var comment in comments) {
      count += _countCommentsInTree(comment.replies);
    }
    return count;
  }
  
  void _debugPrintComment(DiscussionComment comment, int indent) {
    final padding = ' ' * (indent * 2);
    debugPrint('$padding- ${comment.id}: "${comment.content.substring(0, comment.content.length > 20 ? 20 : comment.content.length)}..." (level: ${comment.level}, replies: ${comment.replies.length})');
    
    for (var reply in comment.replies) {
      _debugPrintComment(reply, indent + 1);
    }
  }

  void initializeWithSubLevelComments(List<DiscussionComment> subLevelComments) {
    // In thread detail page, we use the exact comments provided
    // The parent is shown separately in the header
    _flatComments = subLevelComments;
    
    // Log input comments for debugging
    debugPrint('Initializing with ${subLevelComments.length} sub-level comments');
    for (var comment in subLevelComments) {
      debugPrint('  Comment ${comment.id}: parentId=${comment.parentId}, level=${comment.level}, replyCount=${comment.replyCount}');
    }
    
    // For thread detail page, we need to treat comments with parentId == threadParentId as root comments
    _buildThreadDetailCommentTree(_flatComments);
    
    // Expand all comments for better visibility in thread detail view
    _comments = _setAllCommentsExpansion(_comments, true);
    
    // Set loading state
    _isLoadingComments = false;
    _safeNotifyListeners();
  }
  
  void _buildThreadDetailCommentTree(List<DiscussionComment> flatComments) {
    try {
      debugPrint('Building thread detail tree with ${flatComments.length} comments');
      debugPrint('Thread parent ID: $_threadParentCommentId');
      
      if (_threadParentCommentId == null) {
        // Fallback to regular tree building if no thread parent is set
        _buildCommentTree(flatComments);
        return;
      }
      
      // In thread detail view, comments with parentId == threadParentId are considered top level
      _comments = _buildThreadDetailTreeRecursively(
        flatComments,
        _threadParentCommentId!, // Use threadParentId as parent (with null check)
        0                       // Start at level 0
      );
      
      debugPrint('Built thread detail tree with ${_comments.length} top-level comments');
    } catch (e) {
      debugPrint('Error building thread detail comment tree: $e');
      _comments = [];
    }
  }
  
  List<DiscussionComment> _buildThreadDetailTreeRecursively(
    List<DiscussionComment> flatComments,
    String parentId,
    int level
  ) {
    // Get direct children of the specified parent
    final children = flatComments
        .where((c) => c.parentId == parentId)
        .map((c) => c.copyWith(level: level))
        .toList();
    
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      // Get replies to this comment
      final nestedReplies = _buildTreeRecursively(flatComments, child.id, level + 1);
      children[i] = child.copyWith(
        replies: nestedReplies,
        replyCount: nestedReplies.length,
      );
    }
    
    // Sort comments by date (oldest first) for stable ordering
    children.sort((a, b) => a.datePosted.compareTo(b.datePosted));
    
    return children;
  }

  void buildThreadCommentTree(List<DiscussionComment> comments) {
    if (_threadParentCommentId == null) return;
    
    // Filter to only comments belonging to this thread
    final threadComments = comments.where((c) => 
      c.threadParentId == _threadParentCommentId
    ).toList();

    // Build tree with thread parent as root
    _comments = _buildTreeRecursively(
      threadComments,
      _threadParentCommentId,
      0
    );
    
    // Maintain expansion states
    _comments = _preserveExpansionState(_comments);
    
    notifyListeners();
  }

  List<DiscussionComment> _preserveExpansionState(List<DiscussionComment> newComments) {
    return newComments.map((newComment) {
      final existingComment = _comments.firstWhereOrNull((c) => c.id == newComment.id);
      return existingComment != null 
          ? newComment.copyWith(isExpanded: existingComment.isExpanded)
          : newComment;
    }).toList();
  }

  // Ensure the thread context is preserved throughout the lifecycle
  void ensureThreadContextPreserved() {
    if (_threadParentCommentId != null) {
      // If we're in a thread view, filter _flatComments to only include comments
      // that are part of this thread or are direct replies
      final relevantComments = _flatComments.where((comment) {
        // Include comments that have this threadParentId
        if (comment.threadParentId == _threadParentCommentId) return true;
        
        // Include comments that are direct replies to the thread parent
        if (comment.parentId == _threadParentCommentId) return true;
        
        // Include comments that are in the reply chain of the thread
        bool isInReplyChain = false;
        
        // Check if this comment is in a reply chain to the thread parent
        String? currentParentId = comment.parentId;
        final Set<String> visitedIds = {};
        
        while (currentParentId != null && !visitedIds.contains(currentParentId)) {
          visitedIds.add(currentParentId);
          
          // Found a connection to the thread parent
          if (currentParentId == _threadParentCommentId) {
            isInReplyChain = true;
            break;
          }
          
          // Move up the chain
          final parentComment = _flatComments.firstWhereOrNull((c) => c.id == currentParentId);
          if (parentComment == null) break;
          
          currentParentId = parentComment.parentId;
        }
        
        return isInReplyChain;
      }).toList();
      
      // Debug output
      debugPrint('Preserving thread context: filtered from ${_flatComments.length} to ${relevantComments.length} comments');
      
      // Use these filtered comments to rebuild the thread tree
      _buildThreadDetailCommentTree(relevantComments);
    }
  }

  void markThreadAsInitialized() {
    _isThreadInitialized = true;
    
    // When initializing a thread, make sure we properly filter comments
    ensureThreadContextPreserved();
  }

  // Handle database updates in a way that preserves UI state appropriately
  void handleDatabaseUpdate({required bool preserveThreadContext}) {
    if (preserveThreadContext && _threadParentCommentId != null) {
      // Thread detail view logic remains the same
      ensureThreadContextPreserved();
      
      // Make sure all comments in thread view are expanded
      _comments = _setAllCommentsExpansion(_comments, true);
      
      debugPrint('Thread view maintained with ${_comments.length} comments after database update');
    } else {
      debugPrint('Handling database update for regular discussion view');
      
      // Enhanced: Preserve scroll position by maintaining expansion states
      final Map<String, bool> expansionStates = {};
      _collectExpansionStates(_comments, expansionStates);
      
      // Check if we have a pending optimistic comment
      final hasOptimisticComment = _flatComments.any((c) => c.id.startsWith('temp-'));
      
      if (hasOptimisticComment) {
        _handleOptimisticUpdate();
      } else {
        _buildCommentTree(_flatComments);
        _comments = _applyExpansionStates(_comments, expansionStates);
      }
      
      // Enhanced: Force expansion of any new comments' parents
      final newComments = _flatComments.where((c) => 
        c.datePosted.isAfter(DateTime.now().subtract(const Duration(seconds: 30)))
      ).toList();
      
      for (final newComment in newComments) {
        if (newComment.parentId != null) {
          _comments = _setCommentExpansion(_comments, newComment.parentId!, true);
        }
      }
      
      // Restore the reply context if it was set
      if (_replyingToCommentId != null) {
        _replyingToCommentId = _replyingToCommentId;
        _replyingToCommentContent = _replyingToCommentContent;
        debugPrint('Restored reply context to commentId: $_replyingToCommentId');
      }
      
      debugPrint('Regular view updated with ${_comments.length} comments after database update');
    }
    
    // Update loading state
    _isLoadingComments = false;
    _safeNotifyListeners();
  }
  
  // Handle optimistic updates more gracefully in discussion view
  void _handleOptimisticUpdate() {
    debugPrint('Handling optimistic update in discussion view');
    
    // Enhanced: Preserve current scroll position
    final previousFirstVisibleComment = _comments.isNotEmpty ? _comments.first.id : null;
    
    // Find any temporary comments in the flat list
    final tempComments = _flatComments.where((c) => c.id.startsWith('temp-')).toList();
    
    if (tempComments.isEmpty) {
      // No temp comments found, do regular build
      _buildCommentTree(_flatComments);
      return;
    }
    
    // For each temporary comment, try to find its real counterpart in the database
    for (final tempComment in tempComments) {
      // Look for a real comment that matches this temp comment
      // We'll match based on:
      // 1. Same parent ID
      // 2. Same content
      // 3. Similar timestamp (within a few seconds)
      final matchingRealComment = _flatComments.firstWhereOrNull((c) => 
        !c.id.startsWith('temp-') && 
        c.parentId == tempComment.parentId && 
        c.content == tempComment.content &&
        c.datePosted.difference(tempComment.datePosted).inSeconds.abs() < 10
      );
      
      if (matchingRealComment != null) {
        debugPrint('Found matching real comment for temp-${tempComment.id} -> ${matchingRealComment.id}');
        
        // Remove the temp comment since we found its real counterpart
        _flatComments.removeWhere((c) => c.id == tempComment.id);
      }
    }
    
    // Build the tree with the updated flat list
    _buildCommentTree(_flatComments);
    
    // Enhanced: Maintain previous expansion states and scroll position
    _comments = _preserveExpansionStateInDiscussionView(_comments);
    
    // If we had a previous first visible comment, try to keep it visible
    if (previousFirstVisibleComment != null) {
      final index = _comments.indexWhere((c) => c.id == previousFirstVisibleComment);
      if (index != -1) {
        // This would typically be handled by your view layer
        debugPrint('Maintaining scroll position near comment: $previousFirstVisibleComment');
      }
    }
  }
  
  // Helper method to preserve expansion state in discussion view
  List<DiscussionComment> _preserveExpansionStateInDiscussionView(List<DiscussionComment> newComments) {
    // Create a map of current expansion states
    final Map<String, bool> expansionStates = {};
    _collectExpansionStates(_comments, expansionStates);
    
    return _applyExpansionStates(newComments, expansionStates);
  }
  
  // Helper to collect expansion states from current comments
  void _collectExpansionStates(List<DiscussionComment> comments, Map<String, bool> states) {
    for (final comment in comments) {
      states[comment.id] = comment.isExpanded;
      _collectExpansionStates(comment.replies, states);
    }
  }
  
  // Helper to apply saved expansion states to new comments
  List<DiscussionComment> _applyExpansionStates(List<DiscussionComment> comments, Map<String, bool> states) {
    return comments.map((comment) {
      final newReplies = _applyExpansionStates(comment.replies, states);
      final isExpanded = states[comment.id] ?? false; // Default to collapsed if not found
      
      return comment.copyWith(
        isExpanded: isExpanded,
        replies: newReplies,
      );
    }).toList();
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _discussionService.deleteComment(_discussion.id, commentId);
      
      // Optimistically remove from local state
      _flatComments.removeWhere((c) => c.id == commentId);
      _buildCommentTree(_flatComments);
      _safeNotifyListeners();

      // Show success snackbar
      _showSnackBar('Comment deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete comment. Please try again.');
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  // Add this new method to handle voting in thread view
  Future<void> voteCommentInThread(String commentId, bool isUpvote, String threadParentId) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final user = await _userService.getUser(firebaseUser.uid);
    if (user == null) return;

    try {
      // Make a backup of current state
      final backupComments = List<DiscussionComment>.from(_comments);
      final backupFlatComments = List<DiscussionComment>.from(_flatComments);
      final originalThreadParentId = _threadParentCommentId;

      // Find and update just the target comment
      final int flatIndex = _flatComments.indexWhere((c) => c.id == commentId);
      if (flatIndex >= 0) {
        final comment = _flatComments[flatIndex];
        final updatedComment = _updateCommentVote([comment], commentId, isUpvote, user.uid).first;
        
        // Update flat list without rebuilding
        _flatComments[flatIndex] = updatedComment;
        
        // Update in tree without full rebuild
        _updateCommentInTree(commentId, updatedComment);
        
        // Notify listeners without rebuilding tree
        _safeNotifyListeners();

        // Update backend
        try {
          await _discussionService.voteComment(
            _discussion.id, 
            commentId,
            isUpvote,
            user.uid
          );
        } catch (e) {
          // On backend error, restore previous state
          _comments = backupComments;
          _flatComments = backupFlatComments;
          _threadParentCommentId = originalThreadParentId;
          _safeNotifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error voting on comment in thread: $e');
    }
  }

  // Helper method to update a comment in the tree without rebuilding
  void _updateCommentInTree(String commentId, DiscussionComment updatedComment) {
    _comments = _updateCommentInTreeRecursively(_comments, commentId, updatedComment);
  }

  // Recursively update a specific comment in the tree
  List<DiscussionComment> _updateCommentInTreeRecursively(
    List<DiscussionComment> comments,
    String commentId, 
    DiscussionComment updatedComment
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        // Found our target comment - return the updated version
        return updatedComment;
      } else {
        // Check if it's in the replies
        final updatedReplies = _updateCommentInTreeRecursively(
          comment.replies, 
          commentId, 
          updatedComment
        );
        
        // Only update this comment if its replies changed
        if (!identical(comment.replies, updatedReplies)) {
          return comment.copyWith(replies: updatedReplies);
        }
        return comment;
      }
    }).toList();
  }

  // Add the missing method used for optimistic comment voting
  List<DiscussionComment> _updateCommentVote(
    List<DiscussionComment> comments,
    String targetId, 
    bool isUpvote,
    String userId
  ) {
    return comments.map((comment) {
      if (comment.id == targetId) {
        final upvoterIds = List<String>.from(comment.upvoterIds);
        final downvoterIds = List<String>.from(comment.downvoterIds);
        
        // Check current vote status
        final hasUpvoted = upvoterIds.contains(userId);
        final hasDownvoted = downvoterIds.contains(userId);
        
        // Remove any existing votes first
        upvoterIds.remove(userId);
        downvoterIds.remove(userId);
        
        // Add the new vote
        if (isUpvote && !hasUpvoted) {
          upvoterIds.add(userId);
        } else if (!isUpvote && !hasDownvoted) {
          downvoterIds.add(userId);
        }
        
        // Return updated comment with new vote counts using only the ids arrays
        // The upvotes and downvotes counts are computed properties based on these arrays
        return comment.copyWith(
          upvoterIds: upvoterIds,
          downvoterIds: downvoterIds,
        );
      }
      return comment;
    }).toList();
  }

  // Helper method to show snackbar
  void _showSnackBar(String message) {
    if (_mounted) {
      SnackbarHelper.showSuccess(context, message);
    }
  }

  final BookmarkService _bookmarkService = BookmarkService();

  Future<void> loadBookmarkState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isBookmarked = await _bookmarkService.isBookmarked(
      userId: user.uid,
      itemId: _discussion.id,
    );
    _safeNotifyListeners();
  }

  Future<void> toggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (_isBookmarked) {
        await _bookmarkService.removeBookmark(
          userId: user.uid,
          itemId: _discussion.id,
        );
      } else {
        await _bookmarkService.addBookmark(
          userId: user.uid,
          itemId: _discussion.id,
          itemType: 'discussion',
        );
      }
      
      _isBookmarked = !_isBookmarked;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update bookmark. Please try again.'),
          ),
        );
      }
    }
  }
}
