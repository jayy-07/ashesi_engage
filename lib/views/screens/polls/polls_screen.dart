import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../viewmodels/polls_viewmodel.dart';
import '../../../viewmodels/survey_viewmodel.dart';
import '../../../widgets/poll_card.dart';
import '../../../widgets/survey_card.dart';

class PollsScreen extends StatefulWidget {
  final String? initialPollId;
  final String? highlightedPollId;
  
  const PollsScreen({
    super.key,
    this.initialPollId,
    this.highlightedPollId,
  });

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> with SingleTickerProviderStateMixin {
  bool _showPolls = true;
  late final AnimationController _controller;
  late final Animation<double> _animation;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.value = 1;

    // If we have an initial poll ID, scroll to it after the frame is built
    if (widget.initialPollId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPoll(widget.initialPollId!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPoll(String pollId) {
    // Find the index of the poll in the list
    final pollsViewModel = context.read<PollsViewModel>();
    final polls = pollsViewModel.polls;
    final index = polls.indexWhere((poll) => poll.id == pollId);
    
    if (index != -1) {
      // Calculate the offset based on your card height and padding
      final offset = index * (300.0 + 16.0); // Adjust these values based on your card height and padding
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleView(bool showPolls) {
    if (showPolls == _showPolls) return;
    setState(() => _showPolls = showPolls);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pollsViewModel = context.watch<PollsViewModel>();
    final surveyViewModel = context.watch<SurveyViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Pills for Polls/Surveys
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.4),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Stack(
                children: [
                  // Animated selection indicator
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: _showPolls 
                        ? Alignment.centerLeft 
                        : Alignment.centerRight,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5 - 16,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                  // Pills
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleView(true),
                            borderRadius: BorderRadius.circular(25),
                            child: Center(
                              child: Text(
                                'Polls',
                                style: TextStyle(
                                  color: _showPolls 
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleView(false),
                            borderRadius: BorderRadius.circular(25),
                            child: Center(
                              child: Text(
                                'Surveys',
                                style: TextStyle(
                                  color: !_showPolls 
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips
          if (_showPolls) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Expired'),
                      selected: pollsViewModel.showExpiredPolls,
                      onSelected: (_) => pollsViewModel.toggleExpiredPolls(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Voted'),
                      selected: pollsViewModel.showVotedPolls,
                      onSelected: (_) => pollsViewModel.toggleVotedPolls(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Not Voted'),
                      selected: pollsViewModel.showUnvotedPolls,
                      onSelected: (_) => pollsViewModel.toggleUnvotedPolls(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            // Status Filters
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Completed'),
                      selected: surveyViewModel.showCompletedSurveys,
                      onSelected: (_) => surveyViewModel.toggleCompletedSurveys(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pending'),
                      selected: surveyViewModel.showPendingSurveys,
                      onSelected: (_) => surveyViewModel.togglePendingSurveys(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Category Filters
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final category in surveyViewModel.availableCategories) ...[
                      if (category != surveyViewModel.availableCategories.first) 
                        const SizedBox(width: 8),
                      FilterChip(
                        label: Text(category),
                        selected: surveyViewModel.selectedCategories.contains(category),
                        onSelected: (_) => surveyViewModel.toggleCategory(category),
                        showCheckmark: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Content
          Expanded(
            child: FadeTransition(
              opacity: _animation,
              child: _showPolls 
                  ? _buildPollsList(pollsViewModel)
                  : _buildSurveysList(surveyViewModel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollsList(PollsViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => viewModel.refresh(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (viewModel.polls.isEmpty) {
      String message = 'No Active Polls';
      if (viewModel.showExpiredPolls) message = 'No Expired Polls';
      if (viewModel.showVotedPolls) message = 'No Voted Polls';
      if (viewModel.showUnvotedPolls) message = 'No Polls to Vote On';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new polls',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viewModel.polls.length,
        itemBuilder: (context, index) {
          final poll = viewModel.polls[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PollCard(
              poll: poll,
              highlight: poll.id == widget.highlightedPollId,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSurveysList(SurveyViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => viewModel.refresh(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Get user surveys with class filtering
    final surveys = viewModel.userSurveys;
    if (surveys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Surveys',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new surveys',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: surveys.length,
        itemBuilder: (context, index) {
          final survey = surveys[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurveyCard(survey: survey),
          );
        },
      ),
    );
  }
}