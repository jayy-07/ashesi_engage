import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/services/poll_service.dart';
import '../models/entities/poll.dart';
import '../models/services/auth_service.dart';
import '../models/services/user_service.dart';
import 'package:uuid/uuid.dart';
import 'admin_polls_viewmodel.dart'; // Added import

class PollsViewModel extends ChangeNotifier {
  final PollService _pollService = PollService();
  @protected
  final AuthService authService;
  final DatabaseService _databaseService = DatabaseService();
  @protected
  final Map<String, Poll> pollsMap = {};
  final Set<String> _subscribedPollIds = {};
  final Map<String, StreamSubscription<Poll?>> _pollSubscriptions = {};
  bool _isLoading = false;
  String? _error;
  Set<String> _availableClasses = {};
  List<String>? _userClasses;
  bool _isRefreshing = false;
  StreamSubscription<List<Poll>>? _pollsSubscription;

  bool _isAllClasses = false;
  List<String> _selectedClasses = [];
  
  // Filter states
  @protected
  bool isShowingExpiredPolls = false;
  @protected
  bool isShowingVotedPolls = false;
  @protected
  bool isShowingUnvotedPolls = false;

  PollsViewModel(this.authService) {
    _initialize();
  }

  List<Poll> get polls {
    final user = authService.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    var filteredPolls = pollsMap.values.toList();

    // First filter out polls that are expired and past their final results duration
    filteredPolls = filteredPolls.where((poll) {
      if (!poll.expiresAt.isBefore(now)) return true; // Not expired, show it
      
      // For expired polls, only keep them if they're within final results duration
      if (poll.showResultsAfterEnd) {
        final finalResultsEndTime = poll.expiresAt.add(Duration(hours: poll.finalResultsDuration));
        return now.isBefore(finalResultsEndTime);
      }
      return false;
    }).toList();

    // Then apply user-selected filters
    if (isShowingExpiredPolls) {
      // Show only expired polls that are within their final results duration window
      filteredPolls = filteredPolls.where((poll) => poll.expiresAt.isBefore(now)).toList();
    } else if (isShowingVotedPolls) {
      // Show only non-expired polls that the user has voted on
      filteredPolls = filteredPolls.where((poll) => 
        poll.hasUserVoted(user.uid) && !poll.expiresAt.isBefore(now)
      ).toList();
    } else if (isShowingUnvotedPolls) {
      // Show only non-expired polls that the user hasn't voted on
      filteredPolls = filteredPolls.where((poll) => 
        !poll.hasUserVoted(user.uid) && !poll.expiresAt.isBefore(now)
      ).toList();
    } else {
      // Default: show only active, non-expired polls
      filteredPolls = filteredPolls.where((poll) => 
        poll.isActive && !poll.expiresAt.isBefore(now)
      ).toList();
    }

    // Sort by expiry date
    filteredPolls.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    
    return filteredPolls;
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;

  bool get isAllClasses => _isAllClasses;
  List<String> get selectedClasses => _selectedClasses;
  Set<String> get availableClasses => _availableClasses;

  bool get showExpiredPolls => isShowingExpiredPolls;
  bool get showVotedPolls => isShowingVotedPolls;
  bool get showUnvotedPolls => isShowingUnvotedPolls;

  Poll? getPoll(String pollId) => pollsMap[pollId];

  void toggleExpiredPolls() {
    isShowingExpiredPolls = !isShowingExpiredPolls;
    isShowingVotedPolls = false;
    isShowingUnvotedPolls = false;
    notifyListeners();
  }

  void toggleVotedPolls() {
    isShowingVotedPolls = !isShowingVotedPolls;
    isShowingExpiredPolls = false;
    isShowingUnvotedPolls = false;
    notifyListeners();
  }

  void toggleUnvotedPolls() {
    isShowingUnvotedPolls = !isShowingUnvotedPolls;
    isShowingExpiredPolls = false;
    isShowingVotedPolls = false;
    notifyListeners();
  }

  void clearFilters() {
    isShowingExpiredPolls = false;
    isShowingVotedPolls = false;
    isShowingUnvotedPolls = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollsSubscription?.cancel();
    // Cancel all individual poll subscriptions
    for (var subscription in _pollSubscriptions.values) {
      subscription.cancel();
    }
    _pollSubscriptions.clear();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await Future.wait([
        _loadUserClasses(),
        _loadAvailableClasses(),
      ]);

      await _loadPolls();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isRefreshing = true;
    notifyListeners();

    await _loadPolls();

    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> _loadUserClasses() async {
    try {
      final user = authService.currentUser;
      if (user == null) {
        _userClasses = [];
        return;
      }

      final userData = await _databaseService.getUserData(user.uid);

      final classYear = userData['classYear'] as String?;
      _userClasses = classYear != null && classYear.isNotEmpty ? [classYear] : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user classes: $e');
      }
      _error = e.toString();
      _userClasses = [];
    }
  }

  Future<void> _loadAvailableClasses() async {
    try {
      final classes = await _databaseService.getAvailableClasses();
      _availableClasses = classes.toSet();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _loadPolls() async {
    try {
      _error = null;
      await _pollsSubscription?.cancel();
      
      // For AdminPollsViewModel, fetchAllForAdmin will be true.
      // For PollsViewModel (user-facing), it will be false (default).
      bool isAdminContext = this is AdminPollsViewModel;

      _pollsSubscription = _pollService.getAllPolls(
        classScopes: _userClasses,
        fetchAllForAdmin: isAdminContext,
      ).listen(
        (polls) {
          pollsMap.clear(); // Clear existing polls
          for (var poll in polls) {
            pollsMap[poll.id] = poll;
          }
          notifyListeners();
        },
        onError: (e) {
          if (kDebugMode) {
            print('Error loading polls: $e');
          }
          _error = e.toString();
          notifyListeners();
        }
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up polls subscription: $e');
      }
      _error = e.toString();
      notifyListeners();
    }
  }

  void setClassSelection(bool isAllClasses, List<String> selectedClasses) {
    _isAllClasses = isAllClasses;
    _selectedClasses = selectedClasses;
    notifyListeners();
  }

  // Optimistic vote handling
  Future<void> vote(String pollId, String optionId) async {
    try {
      final user = authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Optimistically update the UI
      final poll = pollsMap[pollId];
      if (poll == null) return;

      final newVotes = Map<String, PollVote>.from(poll.votes);
      newVotes[user.uid] = PollVote(
        optionId: optionId,
        timestamp: DateTime.now(),
      );

      pollsMap[pollId] = Poll(
        id: poll.id,
        title: poll.title,
        description: poll.description,
        createdBy: poll.createdBy,
        createdAt: poll.createdAt,
        expiresAt: poll.expiresAt,
        options: poll.options,
        votes: newVotes,
        showRealTimeResults: poll.showRealTimeResults,
        showResultsAfterEnd: poll.showResultsAfterEnd,
        finalResultsDuration: poll.finalResultsDuration,
        isAllClasses: poll.isAllClasses,
        classScopes: poll.classScopes,
        isActive: poll.isActive,
        isReversible: poll.isReversible,
      );
      notifyListeners();

      // Update backend
      await _pollService.vote(pollId, user.uid, optionId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      // Revert optimistic update on error
      await _loadPolls();
      rethrow;
    }
  }

  // Optimistic unvote handling
  Future<void> unvote(String pollId) async {
    try {
      final user = authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Optimistically update the UI
      final poll = pollsMap[pollId];
      if (poll == null) return;

      final newVotes = Map<String, PollVote>.from(poll.votes);
      newVotes.remove(user.uid);

      pollsMap[pollId] = Poll(
        id: poll.id,
        title: poll.title,
        description: poll.description,
        createdBy: poll.createdBy,
        createdAt: poll.createdAt,
        expiresAt: poll.expiresAt,
        options: poll.options,
        votes: newVotes,
        showRealTimeResults: poll.showRealTimeResults,
        showResultsAfterEnd: poll.showResultsAfterEnd,
        finalResultsDuration: poll.finalResultsDuration,
        isAllClasses: poll.isAllClasses,
        classScopes: poll.classScopes,
        isActive: poll.isActive,
        isReversible: poll.isReversible,
      );
      notifyListeners();

      // Update backend
      await _pollService.unvote(pollId, user.uid);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      // Revert optimistic update on error
      await _loadPolls();
      rethrow;
    }
  }

  Future<void> createPoll({
    required String title,
    required String description,
    required List<String> options,
    required DateTime expiresAt,
    required bool showRealTimeResults,
    required bool showResultsAfterEnd,
    required bool isAllClasses,
    required List<String> classScopes,
    required bool isReversible,
    required int finalResultsDuration,
  }) async {
    try {
      final user = authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final pollOptions = options.map((text) => PollOption(
        id: const Uuid().v4(),
        text: text,
      )).toList();

      final poll = Poll(
        id: '',  // Will be set by Firestore
        title: title,
        description: description,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        options: pollOptions,
        showRealTimeResults: showRealTimeResults,
        showResultsAfterEnd: showResultsAfterEnd,
        finalResultsDuration: finalResultsDuration,
        isAllClasses: isAllClasses,
        classScopes: classScopes,
        isActive: true,
        votes: {},
        isReversible: isReversible,
      );

      await _pollService.createPoll(poll);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleRealTimeResults(String pollId, bool showResults) async {
    try {
      await _pollService.toggleRealTimeResults(pollId, showResults);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleResultsAfterEnd(String pollId, bool showResults) async {
    try {
      await _pollService.toggleResultsAfterEnd(pollId, showResults);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePoll(String pollId) async {
    try {
      await _pollService.deletePoll(pollId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updatePollExpiryDate(String pollId, DateTime newExpiryDate) async {
    try {
      await _pollService.updatePollExpiryDate(pollId, newExpiryDate);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void subscribeToPollUpdates(String pollId) {
    if (_subscribedPollIds.contains(pollId)) return;
    _subscribedPollIds.add(pollId);
    // Start listening to real-time updates for this poll
    _startPollSubscription(pollId);
  }

  void unsubscribeFromPollUpdates(String pollId) {
    if (!_subscribedPollIds.contains(pollId)) return;
    _subscribedPollIds.remove(pollId);
    // Stop listening to real-time updates for this poll
    _stopPollSubscription(pollId);
  }

  void _startPollSubscription(String pollId) {
    // Cancel existing subscription if any
    _pollSubscriptions[pollId]?.cancel();
    
    // Start new subscription
    _pollSubscriptions[pollId] = _pollService.getPollStream(pollId).listen(
      (poll) {
        if (poll != null) {
          pollsMap[pollId] = poll;
          notifyListeners();
        }
      },
      onError: (e) {
        if (kDebugMode) {
          print('Error in poll subscription for $pollId: $e');
        }
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void _stopPollSubscription(String pollId) {
    // Cancel and remove the subscription
    _pollSubscriptions[pollId]?.cancel();
    _pollSubscriptions.remove(pollId);
  }
}