import 'dart:async';
import 'package:flutter/material.dart';
import '../models/entities/discussion_post.dart';
import '../models/services/discussion_service.dart';

class AdminDiscussionsViewModel extends ChangeNotifier {
  final DiscussionService _discussionService = DiscussionService();
  List<DiscussionPost> _discussions = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<DiscussionPost>>? _discussionsSubscription;

  List<DiscussionPost> get discussions => _discussions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get unique classes from all discussions
  Set<String> get availableClasses => _discussions
      .map((discussion) => discussion.authorClass)
      .where((classYear) => classYear.isNotEmpty)
      .toSet();

  AdminDiscussionsViewModel() {
    _loadDiscussions();
  }

  @override
  void dispose() {
    _discussionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDiscussions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _discussionsSubscription = _discussionService.getDiscussions().listen(
        (discussions) {
          _discussions = discussions;
          _isLoading = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load discussions: $error';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to load discussions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDiscussion(String discussionId) async {
    try {
      await _discussionService.deleteDiscussion(discussionId);
      // The stream will automatically update the UI
    } catch (e) {
      debugPrint('Error deleting discussion: $e');
    }
  }

  // Selected discussion state
  String? _selectedDiscussionId;
  String? _highlightedCommentId;

  String? get selectedDiscussionId => _selectedDiscussionId;
  String? get highlightedCommentId => _highlightedCommentId;

  // Method to select a specific discussion, potentially with a highlighted comment
  void selectDiscussion(String discussionId, String? highlightCommentId) {
    _selectedDiscussionId = discussionId;
    _highlightedCommentId = highlightCommentId;
    debugPrint('Selected discussion: $discussionId, highlight comment: $highlightCommentId');
    notifyListeners();
  }
}