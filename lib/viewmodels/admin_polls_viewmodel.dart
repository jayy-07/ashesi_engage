
import '../models/entities/poll.dart';
import 'polls_viewmodel.dart';

class AdminPollsViewModel extends PollsViewModel {
  bool _showExpiredPolls = false;
  
  AdminPollsViewModel(super.authService);

  @override
  bool get showExpiredPolls => _showExpiredPolls;

  @override
  void toggleExpiredPolls() {
    _showExpiredPolls = !_showExpiredPolls;
    notifyListeners();
  }

  @override
  List<Poll> get polls {
    final user = authService.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    var filteredPolls = pollsMap.values.toList();

    // Apply filters
    if (_showExpiredPolls) {
      // For admin view, show all expired polls regardless of final results duration
      filteredPolls = filteredPolls.where((poll) => poll.expiresAt.isBefore(now)).toList();
    } else if (isShowingVotedPolls) {
      filteredPolls = filteredPolls.where((poll) => 
        poll.hasUserVoted(user.uid) && !poll.expiresAt.isBefore(now)
      ).toList();
    } else if (isShowingUnvotedPolls) {
      filteredPolls = filteredPolls.where((poll) => 
        !poll.hasUserVoted(user.uid) && !poll.expiresAt.isBefore(now)
      ).toList();
    } else {
      // Default: show active polls
      filteredPolls = filteredPolls.where((poll) => 
        poll.isActive && !poll.expiresAt.isBefore(now)
      ).toList();
    }

    // Sort by expiry date
    filteredPolls.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    
    return filteredPolls;
  }
} 