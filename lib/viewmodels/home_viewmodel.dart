import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/entities/discussion_post.dart';
import '../models/entities/event.dart';
import '../models/entities/poll.dart';
import '../models/entities/student_proposal.dart';
import '../models/services/discussion_service.dart';
import '../models/services/event_service.dart';
import '../models/services/poll_service.dart';
import '../models/services/proposal_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DiscussionService _discussionService = DiscussionService();
  final EventService _eventService = EventService();
  final PollService _pollService = PollService();
  final ProposalService _proposalService = ProposalService();
  
  List<DiscussionPost> _topDiscussions = [];
  List<Event> _upcomingEvents = [];
  List<Poll> _activePolls = [];
  List<StudentProposal> _answeredProposals = [];
  bool _isLoading = true;
  String? _error;

  // Subscriptions
  StreamSubscription<List<DiscussionPost>>? _discussionsSubscription;
  StreamSubscription<List<Event>>? _eventsSubscription;
  StreamSubscription<List<Poll>>? _pollsSubscription;
  StreamSubscription<List<StudentProposal>>? _proposalsSubscription;

  // Getters
  List<DiscussionPost> get topDiscussions => _topDiscussions;
  List<Event> get upcomingEvents => _upcomingEvents;
  List<Poll> get activePolls => _activePolls;
  List<StudentProposal> get answeredProposals => _answeredProposals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HomeViewModel() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Listen to discussions and filter for top ones from past week
      _discussionsSubscription = _discussionService.getDiscussions().listen(
        (discussions) {
          final now = DateTime.now();
          final weekAgo = now.subtract(const Duration(days: 7));
          
          _topDiscussions = discussions
              .where((d) => d.datePosted.isAfter(weekAgo))
              .toList()
            ..sort((a, b) => (b.upvotes - b.downvotes)
                .compareTo(a.upvotes - a.downvotes));
          
          // Take top 5 discussions
          if (_topDiscussions.length > 5) {
            _topDiscussions = _topDiscussions.sublist(0, 5);
          }
          
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load discussions: $error';
          notifyListeners();
        },
      );

      // Listen to events and filter for upcoming ones in next 24 hours
      _eventsSubscription = _eventService.getEvents().listen(
        (events) {
          final now = DateTime.now();
          final tomorrow = now.add(const Duration(days: 1));
          
          _upcomingEvents = events
              .where((e) => e.startTime.isAfter(now) && e.startTime.isBefore(tomorrow))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load events: $error';
          notifyListeners();
        },
      );

      // Listen to polls and filter for currently active ones
      _pollsSubscription = _pollService.getPolls().listen(
        (polls) {
          final now = DateTime.now();
          
          _activePolls = polls
              .where((p) => p.expiresAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
          
          // Take top 5 active polls
          if (_activePolls.length > 5) {
            _activePolls = _activePolls.sublist(0, 5);
          }
          
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load polls: $error';
          notifyListeners();
        },
      );

      // Listen to proposals and filter for recently answered ones
      _proposalsSubscription = _proposalService.getProposals().listen(
        (proposals) {
          final now = DateTime.now();
          final weekAgo = now.subtract(const Duration(days: 7));
          
          _answeredProposals = proposals
              .where((p) => p.answeredAt != null && p.answeredAt!.isAfter(weekAgo))
              .toList()
            ..sort((a, b) => b.answeredAt!.compareTo(a.answeredAt!));
          
          // Take top 5 answered proposals
          if (_answeredProposals.length > 5) {
            _answeredProposals = _answeredProposals.sublist(0, 5);
          }
          
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load proposals: $error';
          notifyListeners();
        },
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Cancel existing subscriptions
      await _discussionsSubscription?.cancel();
      await _eventsSubscription?.cancel();
      await _pollsSubscription?.cancel();
      await _proposalsSubscription?.cancel();

      // Reinitialize
      await _initialize();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> endorseProposal(String proposalId) async {
    try {
      final proposal = _answeredProposals.firstWhere((p) => p.id == proposalId);
      if (proposal.isEndorsedByUser) {
        await _proposalService.removeEndorsement(proposalId, proposal.authorId);
      } else {
        await _proposalService.endorseProposal(proposalId, proposal.authorId);
      }
    } catch (e) {
      debugPrint('Error endorsing proposal: $e');
      rethrow;
    }
  }

  Future<void> deleteProposal(String proposalId) async {
    try {
      await _proposalService.deleteProposal(proposalId);
    } catch (e) {
      debugPrint('Error deleting proposal: $e');
      rethrow;
    }
  }

  Future<void> updateDiscussionVote(String discussionId, bool isUpvote) async {
    final discussionIndex = _topDiscussions.indexWhere((d) => d.id == discussionId);
    if (discussionIndex == -1) return;

    final discussion = _topDiscussions[discussionIndex];
    final wasUpvoted = discussion.hasUserUpvoted;
    final wasDownvoted = discussion.hasUserDownvoted;
    
    // Get current user ID for voter lists
    final userId = _discussionService.getCurrentUserId();
    if (userId == null) return;

    // Update voter ID lists
    final upvoterIds = List<String>.from(discussion.upvoterIds);
    final downvoterIds = List<String>.from(discussion.downvoterIds);
    
    // Remove any existing votes first
    upvoterIds.remove(userId);
    downvoterIds.remove(userId);
    
    // Add new vote if applicable
    if (isUpvote && !wasUpvoted) {
      upvoterIds.add(userId);
    } else if (!isUpvote && !wasDownvoted) {
      downvoterIds.add(userId);
    }

    // Update discussion with new vote counts
    _topDiscussions[discussionIndex] = discussion.copyWith(
      upvoterIds: upvoterIds,
      downvoterIds: downvoterIds,
      hasUserUpvoted: isUpvote && !wasUpvoted,
      hasUserDownvoted: !isUpvote && !wasDownvoted,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _discussionsSubscription?.cancel();
    _eventsSubscription?.cancel();
    _pollsSubscription?.cancel();
    _proposalsSubscription?.cancel();
    super.dispose();
  }
}