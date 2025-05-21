import 'dart:async';
import '../models/entities/discussion_post.dart';
import '../models/services/discussion_service.dart';
import '../models/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../views/widgets/report_dialog.dart';

class DiscussionsViewModel extends ChangeNotifier {
  final DiscussionService _discussionService;
  final AuthService _authService;
  List<DiscussionPost> _discussions = [];
  bool _isLoading = true;
  bool _isFabExtended = true;
  StreamSubscription<List<DiscussionPost>>? _discussionsSubscription;

  // Add the following fields and methods for searching:
  bool _isSearching = false;
  String _searchQuery = '';

  // Getters
  List<DiscussionPost> get discussions => _discussions;
  bool get isLoading => _isLoading;
  bool get isFabExtended => _isFabExtended;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;

  List<DiscussionPost> get filteredDiscussions {
    if (_searchQuery.isEmpty) return _discussions;
    final query = _searchQuery.toLowerCase();
    return _discussions.where((post) {
      final content = post.plainContent.toLowerCase();
      return content.contains(query);
    }).toList();
  }

  List<DiscussionPost> getUserDiscussions() {
    final user = _authService.currentUser;
    if (user == null) return [];
    
    return _discussions.where((discussion) => 
      discussion.authorId == user.uid
    ).toList();
  }

  DiscussionsViewModel(this._authService) : _discussionService = DiscussionService() {
    _initDiscussionsStream();
  }

  void _initDiscussionsStream() {
    _isLoading = true;
    notifyListeners();

    _discussionsSubscription = _discussionService.getDiscussions().listen(
      (discussions) {
        _discussions = discussions.map((discussion) {
          final user = _authService.currentUser;
          // Add user-specific voting status
          return discussion.copyWith(
            hasUserUpvoted: user != null && discussion.upvoterIds.contains(user.uid),
            hasUserDownvoted: user != null && discussion.downvoterIds.contains(user.uid),
          );
        }).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error loading discussions: $error');
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  Future<void> voteDiscussion(String discussionId, bool isUpvote) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Find the discussion
      final discussionIndex = _discussions.indexWhere((d) => d.id == discussionId);
      if (discussionIndex == -1) return;

      final discussion = _discussions[discussionIndex];
      final wasUpvoted = discussion.hasUserUpvoted;
      final wasDownvoted = discussion.hasUserDownvoted;
      
      // Optimistically update UI
      _discussions[discussionIndex] = discussion.copyWith(
        upvotes: isUpvote 
            ? (wasUpvoted ? discussion.upvotes - 1 : discussion.upvotes + 1)
            : (wasUpvoted ? discussion.upvotes - 1 : discussion.upvotes),
        downvotes: !isUpvote 
            ? (wasDownvoted ? discussion.downvotes - 1 : discussion.downvotes + 1)
            : (wasDownvoted ? discussion.downvotes - 1 : discussion.downvotes),
        hasUserUpvoted: isUpvote && !wasUpvoted,
        hasUserDownvoted: !isUpvote && !wasDownvoted,
      );
      notifyListeners();

      // Update backend
      await _discussionService.voteDiscussion(discussionId, isUpvote, user.uid);
    } catch (e) {
      debugPrint('Error voting on discussion: $e');
      // Revert to previous state on error
      final discussionIndex = _discussions.indexWhere((d) => d.id == discussionId);
      if (discussionIndex != -1) {
        final discussion = _discussions[discussionIndex];
        _discussions[discussionIndex] = discussion.copyWith(
          upvotes: discussion.upvotes,
          downvotes: discussion.downvotes,
          hasUserUpvoted: discussion.hasUserUpvoted,
          hasUserDownvoted: discussion.hasUserDownvoted,
        );
        notifyListeners();
      }
    }
  }

  Future<void> deleteDiscussion(String discussionId) async {
    try {
      await _discussionService.deleteDiscussion(discussionId);
      // The stream will automatically update the UI
    } catch (e) {
      debugPrint('Error deleting discussion: $e');
      rethrow;
    }
  }

  Future<void> reportDiscussion(String discussionId, BuildContext context) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ReportDialog(
          contentType: 'discussion',
          contentId: discussionId,
        ),
      );

      if (result == true) {
        debugPrint('Discussion reported: $discussionId');
      }
    } catch (e) {
      debugPrint('Error reporting discussion: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report discussion: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Cancel existing subscription
      await _discussionsSubscription?.cancel();
      
      // Reinitialize the stream
      _initDiscussionsStream();
    } catch (e) {
      debugPrint('Error refreshing discussions: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFabExtended(bool extended) {
    _isFabExtended = extended;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    // Simulate API or local filtering delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _isSearching = false;
      notifyListeners();
    });
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  DiscussionPost? getDiscussionById(String id) {
    try {
      return _discussions.firstWhere(
        (discussion) => discussion.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _discussionsSubscription?.cancel();
    super.dispose();
  }
}
