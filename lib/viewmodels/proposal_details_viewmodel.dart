import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/entities/student_proposal.dart';
import '../models/entities/comment.dart';
import '../models/services/auth_service.dart';
import '../models/services/proposal_service.dart';
import '../models/services/user_service.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import '../models/services/bookmark_service.dart';
import '../views/widgets/report_dialog.dart';
import '../widgets/snackbar_helper.dart';

class ProposalDetailsViewModel extends ChangeNotifier {
  StudentProposal _proposal;
  final QuillController proposalContentController;
  final QuillController answerController;
  final TextEditingController commentController = TextEditingController();
  final FocusNode commentFocus = FocusNode();
  List<Comment> _comments = [];
  bool _isLoadingAISummary = false;
  bool _isBookmarked = false;
  bool _canSubmitComment = false;
  bool _isLoadingComments = true;
  bool _mounted = true;
  final AuthService _authService = AuthService();
  final ProposalService _proposalService;
  final DatabaseService _databaseService = DatabaseService();
  final BookmarkService _bookmarkService = BookmarkService();
  static const int _commentCharacterLimit = 500;
  StreamSubscription<QuerySnapshot>? _commentsSubscription;
  bool _isSendingComment = false;
  String _aiSummary = '';
  StreamSubscription<GenerateContentResponse>? _summaryStreamSubscription;
  bool _hasGeneratedSummary = false;
  final BuildContext context;

  // Add character limit properties
  final int characterLimit = 500;
  int get characterCount => commentController.text.length;
  bool get isOverCharacterLimit => characterCount > characterLimit;

  // Getters
  StudentProposal get proposal => _proposal;
  List<Comment> get comments => _comments;
  bool get isLoadingAISummary => _isLoadingAISummary;
  bool get isBookmarked => _isBookmarked;
  bool get canSubmitComment => !isSendingComment && commentController.text.trim().isNotEmpty && !isOverCharacterLimit;
  bool get isLoadingComments => _isLoadingComments;
  bool get isSendingComment => _isSendingComment;
  String get aiSummary => _aiSummary;
  bool get hasGeneratedSummary => _hasGeneratedSummary;
  String get currentAdminId => _authService.currentUser?.uid ?? '';
  String get currentAdminName => _authService.currentUser?.displayName ?? 'Admin';

  ProposalDetailsViewModel(this._proposal, this.context, this._proposalService) : 
    proposalContentController = QuillController(
      document: Document.fromJson(_proposal.content['ops'] as List),
      selection: const TextSelection.collapsed(offset: 0)
    ),
    answerController = QuillController(
      document: _proposal.answer != null 
        ? Document.fromJson(_proposal.answer!['ops'] as List)
        : Document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true
    ) {

    // Ensure isEndorsedByUser is correctly initialized
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      final bool actuallyEndorsed = _proposal.endorserIds.contains(userId);
      if (_proposal.isEndorsedByUser != actuallyEndorsed) {
        // Assuming StudentProposal has a copyWith method
        _proposal = _proposal.copyWith(isEndorsedByUser: actuallyEndorsed);
      }
    }

    _loadComments();
    commentController.addListener(_updateCanSubmit);
    commentController.addListener(_updateCharacterCount);
    commentController.addListener(() {
      notifyListeners();
    });
    loadBookmarkState();
  }

  Future<void> _loadComments() async {
    if (!_mounted) return;
    _isLoadingComments = true;
    _safeNotifyListeners();

    try {
      _commentsSubscription = FirebaseFirestore.instance
          .collection('proposals')
          .doc(_proposal.id)
          .collection('comments')
          .orderBy('datePosted', descending: true)
          .snapshots()
          .listen((snapshot) {
        _comments = snapshot.docs.map((doc) {
          final data = doc.data();
          final upvoterIds = List<String>.from(data['upvoterIds'] ?? []);
          final downvoterIds = List<String>.from(data['downvoterIds'] ?? []);
          final user = _authService.currentUser;

          // Handle null timestamp
          final timestamp = data['datePosted'];
          final datePosted = timestamp != null 
              ? (timestamp as Timestamp).toDate()
              : DateTime.now(); // Fallback to current time if null

          return Comment(
            id: doc.id,
            proposalId: _proposal.id,
            authorId: data['authorId'] ?? '',
            authorName: data['authorName'] ?? '',
            authorAvatar: data['authorAvatar'] ?? '',
            authorClass: data['authorClass'] ?? '',
            content: data['content'] ?? '',
            datePosted: datePosted,
            upvotes: upvoterIds.length,
            downvotes: downvoterIds.length,
            hasUserUpvoted: user != null && upvoterIds.contains(user.uid),
            hasUserDownvoted: user != null && downvoterIds.contains(user.uid),
            sentimentScore: data['sentimentScore']?.toDouble(),
            sentimentMagnitude: data['sentimentMagnitude']?.toDouble(),
          );
        }).toList();

        _isLoadingComments = false;
        _safeNotifyListeners();
      }, onError: (e) {
        debugPrint('Error loading comments: $e');
        _isLoadingComments = false;
        _safeNotifyListeners();
      });
    } catch (e) {
      debugPrint('Error setting up comments stream: $e');
      _isLoadingComments = false;
      _safeNotifyListeners();
    }
  }

  Future<void> voteComment(String commentId, bool isUpvote) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final commentIndex = _comments.indexWhere((c) => c.id == commentId);
      if (commentIndex == -1) return;

      final comment = _comments[commentIndex];
      final wasUpvoted = comment.hasUserUpvoted;
      final wasDownvoted = comment.hasUserDownvoted;
      
      // Optimistically update UI with all possible state changes
      _comments[commentIndex] = comment.copyWith(
        upvotes: isUpvote 
            ? (wasUpvoted ? comment.upvotes - 1 : comment.upvotes + 1)
            : (wasUpvoted ? comment.upvotes - 1 : comment.upvotes),
        downvotes: !isUpvote 
            ? (wasDownvoted ? comment.downvotes - 1 : comment.downvotes + 1)
            : (wasDownvoted ? comment.downvotes - 1 : comment.downvotes),
        hasUserUpvoted: isUpvote && !wasUpvoted,
        hasUserDownvoted: !isUpvote && !wasDownvoted,
      );
      _safeNotifyListeners();

      // Update in Firestore
      await _proposalService.voteComment(
        _proposal.id,
        commentId,
        isUpvote,
        user.uid,
      );
    } catch (e) {
      debugPrint('Error voting on comment: $e');
      // Revert to previous state on error
      final commentIndex = _comments.indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        final comment = _comments[commentIndex];
        _comments[commentIndex] = comment.copyWith(
          upvotes: comment.upvotes,
          downvotes: comment.downvotes,
          hasUserUpvoted: comment.hasUserUpvoted,
          hasUserDownvoted: comment.hasUserDownvoted,
        );
        _safeNotifyListeners();
      }
    }
  }

  Future<void> submitComment() async {
    if (!canSubmitComment) return;
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      _isSendingComment = true;
      _safeNotifyListeners();

      final commentText = commentController.text.trim();
      commentController.clear();

      final userData = await _databaseService.getUser(user.uid);
      if (userData == null) {
        throw Exception('User profile not found');
      }

      // Default to an empty string if photoURL is null or empty
      final photoURL = (userData.photoURL?.isNotEmpty ?? false) 
          ? userData.photoURL!
          : '';

      // Add optimistic comment immediately for better UX
      final optimisticComment = Comment(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        proposalId: _proposal.id,
        authorId: user.uid,
        authorName: '${userData.firstName} ${userData.lastName}',
        authorClass: userData.classYear,
        authorAvatar: photoURL,
        content: commentText,
        datePosted: DateTime.now(),
        isOptimistic: true,
      );

      // Add optimistic comment to the list
      _comments = [optimisticComment, ..._comments];
      _safeNotifyListeners();

      // Clear input immediately
      commentController.clear();

      // Submit to backend
      await _proposalService.addComment(
        _proposal.id,
        commentText,
        user.uid,
        '${userData.firstName} ${userData.lastName}',
        userData.classYear,
        photoURL,
      );

      // Remove optimistic comment since backend update will trigger new list
      _comments.removeWhere((c) => c.id == optimisticComment.id);
      
      _showSnackBar('Comment posted successfully');
      
      _isSendingComment = false;
      _safeNotifyListeners();
    } catch (e) {
      _isSendingComment = false;
      _showSnackBar('Failed to post comment. Please try again.');
      _safeNotifyListeners();
      debugPrint('Error creating comment: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _proposalService.deleteComment(_proposal.id, commentId);
      _showSnackBar('Comment deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete comment. Please try again.');
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<void> reportComment(String commentId) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ReportDialog(
          contentType: 'proposal_comment',
          contentId: commentId,
        ),
      );

      if (result == true) {
        debugPrint('Comment reported: $commentId');
      }
    } catch (e) {
      debugPrint('Error reporting comment: $e');
      _showSnackBar('Failed to report comment. Please try again.');
    }
  }

  Future<void> deleteProposal() async {
    try {
      await _proposalService.deleteProposal(_proposal.id);
      _showSnackBar('Proposal deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete proposal. Please try again.');
      debugPrint('Error deleting proposal: $e');
      rethrow;
    }
  }

  Future<void> reportProposal() async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ReportDialog(
          contentType: 'proposal',
          contentId: _proposal.id,
        ),
      );

      if (result == true) {
        debugPrint('Proposal reported: ${_proposal.id}');
      }
    } catch (e) {
      debugPrint('Error reporting proposal: $e');
      _showSnackBar('Failed to report proposal. Please try again.');
    }
  }

  void _updateCharacterCount() {
    // No need to store count since we use the getter
    _safeNotifyListeners();
  }

  void _updateCanSubmit() {
    final text = commentController.text.trim();
    final newValue = text.isNotEmpty && text.length <= _commentCharacterLimit;
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

      // Prepare comments for summarization
      final commentTexts = _comments.map((c) => c.content).join('\n');
      
      // Create prompt with strict formatting requirements
      final prompt = [
        Content.text(
          """
          You are analyzing feedback on a student proposal from Ashesi University's e-participation platform. This platform enables students to submit formal proposals to the Student Council for campus improvements, policy changes, or new initiatives. The Council uses this feedback to evaluate and refine proposals before implementation.

          Your task is to synthesize the community feedback to help the proposal author understand the collective response.

          Context (Proposal): ${_proposal.plainContent}

          Feedback comments to analyze:
          $commentTexts

          Generate a structured summary in this exact markdown format:

          ##### **Key Community Feedback**
          * [1-3 main points of student feedback, one per bullet]

          ##### **Strengths Highlighted**
          * [1-2 positive aspects that resonate with the student body]

          ##### **Concerns Raised**
          * [1-2 main concerns or issues identified by students]

          Requirements:
          - Use exactly the markdown headings shown above (##### and ** for each heading)
          - Use markdown bullet points (*)
          - Keep each bullet point to 1-2 sentences maximum
          - Use clear, objective language
          - Focus on concrete feedback and suggestions
          - If a section has no relevant points, write "None identified."
          - Maintain neutral tone throughout
          - Never mention comment counts or use phrases like "users say" or "participants mention"
          - Ensure there is a blank line after each heading and between bullet points
          - Frame feedback in the context of Ashesi University and student impact
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

  Future<void> loadBookmarkState() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _isBookmarked = await _bookmarkService.isBookmarked(
      userId: user.uid,
      itemId: _proposal.id,
    );
    _safeNotifyListeners();
  }

  Future<void> toggleBookmark() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      if (_isBookmarked) {
        await _bookmarkService.removeBookmark(
          userId: user.uid,
          itemId: _proposal.id,
        );
      } else {
        await _bookmarkService.addBookmark(
          userId: user.uid,
          itemId: _proposal.id,
          itemType: 'proposal',
        );
      }
      
      _isBookmarked = !_isBookmarked;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      _showSnackBar('Failed to update bookmark. Please try again.');
    }
  }

  Future<void> endorseProposal() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch fresh proposal from Firestore
      final freshProposal = await _proposalService.getProposal(_proposal.id);
      if (freshProposal == null) throw Exception('Proposal not found');

      final endorsedByUser = freshProposal.hasUserEndorsed(user.uid);

      // 2. Update backend first
      if (endorsedByUser) {
        await _proposalService.removeEndorsement(_proposal.id, user.uid);
      } else {
        await _proposalService.endorseProposal(_proposal.id, user.uid);
      }

      // 3. Update local state
      _proposal = freshProposal.copyWith(
        isEndorsedByUser: !endorsedByUser,
        currentSignatures: endorsedByUser 
            ? freshProposal.currentSignatures - 1 
            : freshProposal.currentSignatures + 1,
      );
      _safeNotifyListeners();

    } catch (e) {
      debugPrint('Error toggling endorsement: $e');
      rethrow;
    }
  }

  Future<void> answerProposal(String proposalId, Delta answer, String adminId) async {
    try {
      await _proposalService.answerProposal(
        proposalId: proposalId,
        answer: answer,
        plainAnswer: answer.toList().map((op) => op.value?.toString() ?? '').join(''),
        adminId: adminId,
        adminName: currentAdminName,
      );
      
      // Update local state
      _proposal = _proposal.copyWith(
        answer: {'ops': answer.toJson()},
        plainAnswer: answer.toList().map((op) => op.value?.toString() ?? '').join(''),
        answeredAt: DateTime.now(),
        answeredBy: adminId,
        answeredByName: currentAdminName,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error answering proposal: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _commentsSubscription?.cancel();
    _summaryStreamSubscription?.cancel();
    commentController.removeListener(_updateCharacterCount);
    commentController.dispose();
    commentFocus.dispose();
    proposalContentController.dispose();
    answerController.dispose();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (_mounted) {
      notifyListeners();
    }
  }

  // Helper method to show snackbar
  void _showSnackBar(String message) {
    if (_mounted) {
      SnackbarHelper.showSuccess(context, message);
    }
  }

  @protected
  void updateAISummaryState({
    required bool isLoading,
    required String summary,
    required bool hasGenerated,
  }) {
    _isLoadingAISummary = isLoading;
    _aiSummary = summary;
    _hasGeneratedSummary = hasGenerated;
  }

  @protected
  void cancelCurrentSummarySubscription() {
    _summaryStreamSubscription?.cancel();
  }
}