import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/services/bookmark_service.dart';
import '../models/services/auth_service.dart';
import '../models/entities/discussion_post.dart';
import '../models/entities/student_proposal.dart';

class BookmarksViewModel extends ChangeNotifier {
  final BookmarkService _bookmarkService;
  final AuthService _authService;
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  StreamSubscription<List<Map<String, dynamic>>>? _bookmarksSubscription;
  Timer? _searchDebouncer;

  // Getters
  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;
  bool get hasBookmarks => _bookmarks.isNotEmpty;

  List<Map<String, dynamic>> get filteredBookmarks {
    return _bookmarks.where((bookmark) {
      // Apply type filter
      if (_selectedFilter != 'all' && bookmark['type'] != _selectedFilter) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final item = bookmark['item'];
      
      if (item is DiscussionPost) {
        return item.plainContent.toLowerCase().contains(query);
      } else if (item is StudentProposal) {
        return item.title.toLowerCase().contains(query) ||
               item.plainContent.toLowerCase().contains(query);
      }
      
      return false;
    }).toList();
  }

  BookmarksViewModel(this._authService) : _bookmarkService = BookmarkService() {
    _initBookmarksStream();
  }

  void _initBookmarksStream() {
    final user = _authService.currentUser;
    if (user == null) {
      _isLoading = false;
      _bookmarks = [];
      notifyListeners();
      return;
    }

    _bookmarksSubscription = _bookmarkService.getUserBookmarks(user.uid).listen(
      (bookmarks) {
        _bookmarks = bookmarks;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error loading bookmarks: $error');
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    
    // Cancel previous debouncer if any
    _searchDebouncer?.cancel();
    
    // Debounce search to avoid excessive updates
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      notifyListeners();
    });
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    _bookmarksSubscription?.cancel();
    super.dispose();
  }
} 