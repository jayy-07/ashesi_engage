import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/entities/poll.dart';
import '../../../viewmodels/admin_polls_viewmodel.dart';
import 'package:timeago/timeago.dart' as timeago;

class PollAnalyticsScreen extends StatefulWidget {
  final Poll poll;

  const PollAnalyticsScreen({
    super.key,
    required this.poll,
  });

  @override
  State<PollAnalyticsScreen> createState() => _PollAnalyticsScreenState();
}

class _PollAnalyticsScreenState extends State<PollAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Color> _gradientColors = [
    const Color(0xFF50E4FF),
    const Color(0xFF2196F3),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Subscribe to poll updates
    final viewModel = context.read<AdminPollsViewModel>();
    viewModel.subscribeToPollUpdates(widget.poll.id);
  }

  @override
  void dispose() {
    // Unsubscribe from poll updates
    final viewModel = context.read<AdminPollsViewModel>();
    viewModel.unsubscribeFromPollUpdates(widget.poll.id);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1200;
    final isVeryWideScreen = screenWidth > 1600;

    // Listen to poll updates
    final poll = context.watch<AdminPollsViewModel>().getPoll(widget.poll.id) ?? widget.poll;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(poll.title),
          bottom: TabBar(
            isScrollable: isWideScreen,
            tabAlignment: isWideScreen ? TabAlignment.center : TabAlignment.start,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Results'),
              Tab(text: 'Timeline'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'analytics',
                  child: ListTile(
                    leading: const Icon(Icons.analytics),
                    title: const Text('View Analytics'),
                  ),
                ),
                PopupMenuItem(
                  value: 'change_expiry',
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Change Expiry Date'),
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_realtime',
                  child: ListTile(
                    leading: Icon(
                      poll.showRealTimeResults 
                          ? Icons.visibility 
                          : Icons.visibility_off,
                    ),
                    title: Text(
                      '${poll.showRealTimeResults ? 'Hide' : 'Show'} Real-time Results',
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_final',
                  child: ListTile(
                    leading: Icon(
                      poll.showResultsAfterEnd 
                          ? Icons.visibility 
                          : Icons.visibility_off,
                    ),
                    title: Text(
                      '${poll.showResultsAfterEnd ? 'Hide' : 'Show'} Final Results',
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Delete Poll',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
              onSelected: _handleMenuAction,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: TabBarView(
          children: [
            isVeryWideScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildOverviewTab(theme, poll),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildQuickStats(theme, poll),
                        ),
                      ),
                    ],
                  )
                : isWideScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _buildOverviewTab(theme, poll),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _buildQuickStats(theme, poll),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildOverviewTab(theme, poll),
                            const SizedBox(height: 24),
                            _buildQuickStats(theme, poll),
                          ],
                        ),
                      ),
            isVeryWideScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildResultsTab(theme, poll),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildVoteDistribution(theme, poll),
                        ),
                      ),
                    ],
                  )
                : isWideScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _buildResultsTab(theme, poll),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _buildVoteDistribution(theme, poll),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildResultsTab(theme, poll),
                            const SizedBox(height: 24),
                            _buildVoteDistribution(theme, poll),
                          ],
                        ),
                      ),
            SingleChildScrollView(
              padding: EdgeInsets.all(isWideScreen ? 32 : 16),
              child: _buildTimelineTab(theme, poll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, Poll poll) {
    final totalVotes = poll.votes.length;
    final now = DateTime.now();
    final timeLeft = poll.expiresAt.difference(now);
    final isExpired = timeLeft.isNegative;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Poll Status',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildStatusRow(
                  theme,
                  'Total Votes',
                  '$totalVotes',
                  Icons.how_to_vote,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  theme,
                  'Status',
                  isExpired ? 'Expired' : 'Active',
                  isExpired ? Icons.event_busy : Icons.event_available,
                  color: isExpired ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  theme,
                  'Real-time Results',
                  poll.showRealTimeResults ? 'Visible' : 'Hidden',
                  poll.showRealTimeResults ? Icons.visibility : Icons.visibility_off,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  theme,
                  'Final Results',
                  poll.showResultsAfterEnd ? 'Will be shown' : 'Will be hidden',
                  Icons.announcement,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Information',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildStatusRow(
                  theme,
                  'Created',
                  DateFormat('MMM d, y HH:mm').format(poll.createdAt),
                  Icons.create,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  theme,
                  'Expires',
                  DateFormat('MMM d, y HH:mm').format(poll.expiresAt),
                  Icons.schedule,
                ),
                if (!isExpired) ...[
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    theme,
                    'Time Left',
                    _formatDuration(timeLeft),
                    Icons.timer,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audience',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildStatusRow(
                  theme,
                  'Scope',
                  poll.isAllClasses ? 'All Classes' : '${poll.classScopes.length} Classes',
                  Icons.school,
                ),
                if (!poll.isAllClasses) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: poll.classScopes.map((className) => Chip(
                      label: Text(className),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsTab(ThemeData theme, Poll poll) {
    final totalVotes = poll.votes.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1200;
    
    return Column(
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(isWideScreen ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results Distribution',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                AspectRatio(
                  aspectRatio: isWideScreen ? 2.5 : 1.7,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: isWideScreen ? 60 : 40,
                      sections: poll.options.map((option) {
                        final votes = poll.getVotesForOption(option.id);
                        final percentage = totalVotes > 0 ? votes / totalVotes : 0;
                        return PieChartSectionData(
                          color: theme.colorScheme.primary.withValues(alpha:0.5 + (percentage * 0.5)),
                          value: votes.toDouble(),
                          title: '${(percentage * 100).toStringAsFixed(1)}%',
                          radius: isWideScreen ? 140 : 100,
                          titleStyle: TextStyle(
                            fontSize: isWideScreen ? 20 : 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ...poll.options.map((option) {
                  final votes = poll.getVotesForOption(option.id);
                  final percentage = totalVotes > 0 ? votes / totalVotes * 100 : 0;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.text,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '$votes votes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab(ThemeData theme, Poll poll) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1200;
    final votesList = poll.votes.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    
    if (votesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: isWideScreen ? 96 : 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No votes yet',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    final firstVote = votesList.first.value.timestamp;
    final lastVote = votesList.last.value.timestamp;
    final duration = lastVote.difference(firstVote);
    final votesPerHour = votesList.length / (duration.inHours + 1);

    return isWideScreen
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vote Timeline',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 32),
                        AspectRatio(
                          aspectRatio: 2.5,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < votesList.length) {
                                        final vote = votesList[value.toInt()];
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            DateFormat('HH:mm').format(vote.value.timestamp),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(votesList.length, (index) {
                                    return FlSpot(
                                      index.toDouble(),
                                      index + 1,
                                    );
                                  }),
                                  isCurved: true,
                                  gradient: LinearGradient(colors: _gradientColors),
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: _gradientColors
                                          .map((color) => color.withValues(alpha:0.2))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voting Activity',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        _buildStatusRow(
                          theme,
                          'First Vote',
                          DateFormat('MMM d, y HH:mm').format(firstVote),
                          Icons.start,
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          theme,
                          'Last Vote',
                          DateFormat('MMM d, y HH:mm').format(lastVote),
                          Icons.flag,
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          theme,
                          'Average',
                          '${votesPerHour.toStringAsFixed(1)} votes/hour',
                          Icons.speed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voting Activity',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildStatusRow(
                        theme,
                        'First Vote',
                        DateFormat('MMM d, y HH:mm').format(firstVote),
                        Icons.start,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        theme,
                        'Last Vote',
                        DateFormat('MMM d, y HH:mm').format(lastVote),
                        Icons.flag,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        theme,
                        'Average',
                        '${votesPerHour.toStringAsFixed(1)} votes/hour',
                        Icons.speed,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vote Timeline',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      AspectRatio(
                        aspectRatio: 1.7,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(votesList.length, (index) {
                                  final vote = votesList[index];
                                  return FlSpot(
                                    index.toDouble(),
                                    index + 1,
                                  );
                                }),
                                isCurved: true,
                                gradient: LinearGradient(colors: _gradientColors),
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: _gradientColors
                                        .map((color) => color.withValues(alpha:0.2))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildStatusRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color ?? theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Less than a minute';
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'analytics':
        // Already in analytics screen
        break;
      case 'change_expiry':
        _selectNewExpiryDate(context);
        break;
      case 'toggle_realtime':
        context.read<AdminPollsViewModel>().toggleRealTimeResults(
          widget.poll.id,
          !widget.poll.showRealTimeResults,
        );
        break;
      case 'toggle_final':
        context.read<AdminPollsViewModel>().toggleResultsAfterEnd(
          widget.poll.id,
          !widget.poll.showResultsAfterEnd,
        );
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poll'),
        content: const Text('Are you sure you want to delete this poll? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              context.read<AdminPollsViewModel>().deletePoll(widget.poll.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectNewExpiryDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.poll.expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    // ignore: use_build_context_synchronously
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.poll.expiresAt),
    );
    if (time == null) return;

    final newExpiryDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // ignore: use_build_context_synchronously
    context.read<AdminPollsViewModel>().updatePollExpiryDate(widget.poll.id, newExpiryDate);
  }

  Widget _buildQuickStats(ThemeData theme, Poll poll) {
    final totalVotes = poll.votes.length;
    final now = DateTime.now();
    final timeLeft = poll.expiresAt.difference(now);
    final isExpired = timeLeft.isNegative;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildStatTile(
              theme,
              icon: Icons.how_to_vote,
              title: 'Total Votes',
              value: totalVotes.toString(),
            ),
            const SizedBox(height: 16),
            _buildStatTile(
              theme,
              icon: isExpired ? Icons.event_busy : Icons.event_available,
              title: 'Status',
              value: isExpired ? 'Expired' : 'Active',
              color: isExpired ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            _buildStatTile(
              theme,
              icon: Icons.schedule,
              title: isExpired ? 'Ended' : 'Time Left',
              value: isExpired
                  ? timeago.format(poll.expiresAt)
                  : _formatDuration(timeLeft),
            ),
            if (poll.isAllClasses) ...[
              const SizedBox(height: 16),
              _buildStatTile(
                theme,
                icon: Icons.school,
                title: 'Audience',
                value: 'All Classes',
              ),
            ] else ...[
              const SizedBox(height: 16),
              _buildStatTile(
                theme,
                icon: Icons.school,
                title: 'Classes',
                value: '${poll.classScopes.length} Classes',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: color ?? theme.colorScheme.primary,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoteDistribution(ThemeData theme, Poll poll) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1200;
    final totalVotes = poll.votes.length;
    final optionVotes = poll.options.map((option) {
      final votes = poll.getVotesForOption(option.id);
      final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0.0;
      return MapEntry(option, percentage);
    }).toList();

    optionVotes.sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isWideScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vote Distribution',
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: isWideScreen ? 32 : 24),
            ...optionVotes.map((entry) {
              final option = entry.key;
              final percentage = entry.value;
              final votes = poll.getVotesForOption(option.id);

              return Padding(
                padding: EdgeInsets.only(bottom: isWideScreen ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            option.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: isWideScreen ? 16 : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$votes votes',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: isWideScreen ? 16 : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isWideScreen ? 12 : 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(isWideScreen ? 6 : 4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        minHeight: isWideScreen ? 12 : 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: isWideScreen ? 14 : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
} 