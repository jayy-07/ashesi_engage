import 'package:flutter/material.dart';
import '../models/services/bookmark_service.dart';
import '../models/services/auth_service.dart';

class BookmarkProvider extends ChangeNotifier {
  final BookmarkService _bookmarkService = BookmarkService();
  final Map<String, bool> _bookmarkStates = {};

  bool isBookmarked(String itemId) {
    return _bookmarkStates[itemId] ?? false;
  }

  Future<void> checkBookmarkStatus(String itemId) async {
    final authService = AuthService();
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    final isBookmarked = await _bookmarkService.isBookmarked(
      userId: userId,
      itemId: itemId,
    );

    _bookmarkStates[itemId] = isBookmarked;
    notifyListeners();
  }

  Future<void> toggleBookmark({
    required String itemId,
    required String itemType,
  }) async {
    final authService = AuthService();
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    try {
      if (_bookmarkStates[itemId] ?? false) {
        await _bookmarkService.removeBookmark(
          userId: userId,
          itemId: itemId,
        );
      } else {
        await _bookmarkService.addBookmark(
          userId: userId,
          itemId: itemId,
          itemType: itemType,
        );
      }

      _bookmarkStates[itemId] = !(_bookmarkStates[itemId] ?? false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }
} 