import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/entities/poll.dart';
import '../viewmodels/polls_viewmodel.dart';
import '../models/services/auth_service.dart';

class PollCard extends StatefulWidget {
  final Poll poll;
  final bool highlight;

  const PollCard({
    super.key,
    required this.poll,
    this.highlight = false,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> with TickerProviderStateMixin {
  String? _optimisticVote;
  DateTime _now = DateTime.now();
  late AnimationController _animationController;
  late Map<String, Animation<double>> _optionAnimations;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));
    _initializeAnimations();
    
    if (widget.highlight) {
      _highlightController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll != widget.poll) {
      _initializeAnimations();
      _animationController.forward();
    }
    if (widget.highlight != oldWidget.highlight) {
      if (widget.highlight) {
        _highlightController.repeat(reverse: true);
      } else {
        _highlightController.stop();
        _highlightController.reset();
      }
    }
  }

  void _initializeAnimations() {
    _optionAnimations = {};
    for (var option in widget.poll.options) {
      _optionAnimations[option.id] = Tween<double>(
        begin: 0,
        end: widget.poll.getVotesForOption(option.id).toDouble(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
    }
    _animationController.forward();
  }

  void _startTimer() {
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
        _startTimer();
      }
    });
  }

  void _handleVoteAction(BuildContext context, String optionId) {
    final viewModel = context.read<PollsViewModel>();
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final currentVote = _optimisticVote ?? widget.poll.votes[user.uid]?.optionId;
    
    // If the user has already voted and the poll doesn't allow vote changes, show a message
    if (currentVote != null && !widget.poll.isReversible) {
      HapticFeedback.mediumImpact(); // Error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This poll does not allow changing votes'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick(); // Tactile feedback for vote action

    setState(() {
      if (currentVote == optionId) {
        // Clicking the same option again removes the vote (only if reversible)
        if (widget.poll.isReversible) {
          _optimisticVote = null;
          viewModel.unvote(widget.poll.id);
        }
      } else {
        // Clicking a different option changes the vote
        _optimisticVote = optionId;
        viewModel.vote(widget.poll.id, optionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<AuthService>().currentUser;
    final userVote = _optimisticVote ?? (user != null ? widget.poll.votes[user.uid]?.optionId : null);
    final hasVoted = userVote != null;
    
    // Calculate total votes more accurately
    int actualTotalVotes = 0;
    Map<String, int> voteCounts = {};
    
    // First count actual votes
    for (var option in widget.poll.options) {
      final count = widget.poll.getVotesForOption(option.id);
      voteCounts[option.id] = count;
      actualTotalVotes += count;
    }
    
    // Adjust for optimistic updates
    if (_optimisticVote != null) {
      if (!widget.poll.votes.containsKey(user?.uid)) {
        // New vote
        voteCounts[_optimisticVote!] = (voteCounts[_optimisticVote!] ?? 0) + 1;
        actualTotalVotes += 1;
      } else if (_optimisticVote != widget.poll.votes[user?.uid]?.optionId) {
        // Changed vote
        final oldVoteId = widget.poll.votes[user?.uid]?.optionId;
        if (oldVoteId != null) {
          voteCounts[oldVoteId] = (voteCounts[oldVoteId] ?? 0) - 1;
          voteCounts[_optimisticVote!] = (voteCounts[_optimisticVote!] ?? 0) + 1;
        }
      }
    }
    
    final timeLeft = widget.poll.expiresAt.difference(_now);
    final isExpired = timeLeft.isNegative;
    final showResults = widget.poll.canShowResults || isExpired;

    // Ensure animations are initialized with current values
    if (_optionAnimations.isEmpty) {
      _initializeAnimations();
    }

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: widget.highlight ? Border.all(
              color: theme.colorScheme.primary.withOpacity(_highlightAnimation.value * 0.5),
              width: 2,
            ) : null,
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.poll.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.poll.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.poll.isReversible && hasVoted && !isExpired)
                        Tooltip(
                          message: 'Tap your vote again to remove it, or select another option to change your vote',
                          child: Icon(
                            Icons.touch_app,
                            color: theme.colorScheme.primary.withValues(alpha:0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Options
                  ...widget.poll.options.map((option) {
                    final isSelected = option.id == userVote;
                    final voteCount = voteCounts[option.id] ?? 0;
                    final percentage = actualTotalVotes > 0 ? (voteCount / actualTotalVotes * 100) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isExpired ? null : () => _handleVoteAction(context, option.id),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha:0.1)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isSelected)
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        option.text,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : null,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (showResults)
                                      AnimatedOpacity(
                                        duration: const Duration(milliseconds: 200),
                                        opacity: 1.0,
                                        child: Text(
                                          '$voteCount ${voteCount == 1 ? 'vote' : 'votes'}',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (showResults) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: 1.0,
                                    child: Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  // Footer
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'Expired'
                            : _formatTimeLeft(timeLeft),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.how_to_vote,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$actualTotalVotes votes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeLeft(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h remaining';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m remaining';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m remaining';
    } else {
      return 'Less than a minute remaining';
    }
  }
}