import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_discussions_viewmodel.dart';
import '../../viewmodels/admin_proposals_viewmodel.dart';
import '../../viewmodels/admin_polls_viewmodel.dart';
import '../../viewmodels/event_viewmodel.dart';
import '../../models/services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminDiscussionsViewModel()),
        ChangeNotifierProvider(create: (_) => AdminProposalsViewModel()),
        ChangeNotifierProvider(create: (context) => AdminPollsViewModel(Provider.of<AuthService>(context, listen: false))),
        ChangeNotifierProvider(create: (_) => EventViewModel()),
      ],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ashesi Engage Dashboard',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track and monitor community engagement',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              const _EngagementStats(),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Recent Activity and Events
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _RecentActivityCard(),
                        SizedBox(height: 24),
                        _UpcomingEventsCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right column - Active Polls and Top Discussions
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _ActivePollsCard(),
                        SizedBox(height: 24),
                        _TopDiscussionsCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngagementStats extends StatelessWidget {
  const _EngagementStats();

  @override
  Widget build(BuildContext context) {
    return Consumer4<AdminDiscussionsViewModel, AdminProposalsViewModel, AdminPollsViewModel, EventViewModel>(
      builder: (context, discussionsVM, proposalsVM, pollsVM, eventVM, _) {
        return GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _StatCard(
              title: 'Active Discussions',
              value: discussionsVM.discussions.length.toString(),
              icon: Icons.forum_outlined,
              color: Colors.indigo,
            ),
            _StatCard(
              title: 'Open Proposals',
              value: proposalsVM.proposals.where((p) => p.answeredAt == null).length.toString(),
              icon: Icons.description_outlined,
              color: Colors.green,
            ),
            _StatCard(
              title: 'Active Polls',
              value: pollsVM.polls.where((p) => !p.isExpired).length.toString(),
              icon: Icons.poll_outlined,
              color: Colors.orange,
            ),
            _StatCard(
              title: 'Upcoming Events',
              value: eventVM.upcomingEvents.length.toString(),
              icon: Icons.event_outlined,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer4<AdminDiscussionsViewModel, AdminProposalsViewModel, AdminPollsViewModel, EventViewModel>(
              builder: (context, discussionsVM, proposalsVM, pollsVM, eventVM, _) {
                final activities = [
                  ...discussionsVM.discussions.take(3).map((d) => _ActivityItem(
                    icon: Icons.forum_outlined,
                    color: Colors.indigo,
                    title: 'New Discussion',
                    description: d.plainContent,
                    time: d.datePosted,
                  )),
                  ...proposalsVM.proposals.take(3).map((p) => _ActivityItem(
                    icon: Icons.description_outlined,
                    color: Colors.green,
                    title: 'New Proposal',
                    description: p.title,
                    time: p.datePosted,
                  )),
                  ...pollsVM.polls.take(3).map((p) => _ActivityItem(
                    icon: Icons.poll_outlined,
                    color: Colors.orange,
                    title: 'New Poll',
                    description: p.title,
                    time: p.createdAt,
                  )),
                ]..sort((a, b) => b.time.compareTo(a.time));

                return Column(
                  children: activities.take(5).map((activity) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: activity.color.withValues(alpha:0.1),
                      child: Icon(activity.icon, color: activity.color, size: 20),
                    ),
                    title: Text(activity.title),
                    subtitle: Text(
                      activity.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _getTimeAgo(activity.time),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Events',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<EventViewModel>(
              builder: (context, eventVM, _) {
                final upcomingEvents = eventVM.upcomingEvents.take(3).toList();
                return Column(
                  children: upcomingEvents.map((event) => ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(event.title),
                    subtitle: Text(
                      '${_formatDate(event.startTime)} - ${_formatDate(event.endTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ActivePollsCard extends StatelessWidget {
  const _ActivePollsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.poll_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Polls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<AdminPollsViewModel>(
              builder: (context, pollsVM, _) {
                final activePolls = pollsVM.polls.where((p) => !p.isExpired).take(3);
                return Column(
                  children: activePolls.map((poll) => ListTile(
                    title: Text(poll.title),
                    subtitle: Text(
                      '${poll.totalVotes} votes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to poll details
                    },
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopDiscussionsCard extends StatelessWidget {
  const _TopDiscussionsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trending Discussions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<AdminDiscussionsViewModel>(
              builder: (context, discussionsVM, _) {
                // Sort by engagement (upvotes + comments)
                final trendingDiscussions = discussionsVM.discussions
                  .where((d) => d.datePosted.isAfter(DateTime.now().subtract(const Duration(days: 7))))
                  .toList()
                  ..sort((a, b) => (b.upvotes + b.replyCount).compareTo(a.upvotes + a.replyCount));

                return Column(
                  children: trendingDiscussions.take(3).map((discussion) => ListTile(
                    title: Text(
                      discussion.plainContent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 16, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(discussion.upvotes.toString()),
                        const SizedBox(width: 12),
                        Icon(Icons.comment, size: 16, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(discussion.replyCount.toString()),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to discussion details
                    },
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final DateTime time;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.time,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}