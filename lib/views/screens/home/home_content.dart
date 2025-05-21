import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/polls_viewmodel.dart';
import '../../../viewmodels/user_viewmodel.dart';
import '../../../viewmodels/article_viewmodel.dart';
import '../../../viewmodels/discussions_viewmodel.dart';
import '../../../models/services/auth_service.dart';
import '../../widgets/events/event_card.dart';
import '../../../widgets/poll_card.dart';
import '../../widgets/forum/discussion_post_card.dart';
import '../../widgets/article_card.dart';
import '../forum/discussion_detail_page.dart';
import 'home_screen.dart';

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({
    required this.title,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const Spacer(),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  void _switchToTab(BuildContext context, int index) {
    if (context.mounted) {
      final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
      if (homeScreen != null) {
        homeScreen.onNavBarTap(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => DiscussionsViewModel(AuthService())),
        ChangeNotifierProvider(
          create: (_) {
            final viewModel = ArticleViewModel();
            // Load articles immediately when created
            viewModel.loadArticles();
            return viewModel;
          }
        ),
      ],
      builder: (context, child) {
        return Consumer2<HomeViewModel, ArticleViewModel>(
          builder: (context, homeViewModel, articleViewModel, child) {
            if (homeViewModel.isLoading || articleViewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (homeViewModel.error != null) {
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
                      homeViewModel.error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => homeViewModel.refresh(),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            final featuredArticles = articleViewModel.articles
                .where((n) => n.isPublished && n.isFeatured)
                .toList()
              ..sort((a, b) => b.datePublished.compareTo(a.datePublished));

            return RefreshIndicator(
              onRefresh: () async {
                final pollsVM = context.read<PollsViewModel>();
                await Future.wait([
                  homeViewModel.refresh(),
                  articleViewModel.loadArticles(),
                  pollsVM.refresh(),
                ]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Consumer<UserViewModel>(
                          builder: (context, userViewModel, _) {
                            if (userViewModel.isLoading) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome,',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  userViewModel.firstName ?? "User",
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24.0),
                        
                        if (featuredArticles.isNotEmpty) 
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Featured Updates',
                                onViewAll: () => context.pushNamed('articles'),
                              ),
                              const SizedBox(height: 16.0),
                              SizedBox(
                                height: 460,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: featuredArticles.length,
                                  itemBuilder: (context, index) {
                                    final article = featuredArticles[index];
                                    return SizedBox(
                                      width: MediaQuery.of(context).size.width - 32, // Full width minus padding
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: index != featuredArticles.length - 1 ? 16.0 : 0,
                                          left: index == 0 ? 0 : 0,
                                        ),
                                        child: ArticleCard(article: article),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 32.0),
                            ],
                          ),
                        
                        if (homeViewModel.upcomingEvents.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Upcoming Events',
                                onViewAll: () => _switchToTab(context, 4),
                              ),
                              const SizedBox(height: 16.0),
                              ...homeViewModel.upcomingEvents.map((event) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: EventCard(
                                  event: event,
                                  onAddToCalendar: (event) async {
                                    // Add to Calendar functionality
                                    final calendar.Event calendarEvent = calendar.Event(
                                      title: event.title,
                                      description: event.shortDescription,
                                      location: event.location,
                                      startDate: event.startTime,
                                      endDate: event.endTime,
                                      allDay: event.isAllDay,
                                    );
                                    await calendar.Add2Calendar.addEvent2Cal(calendarEvent);
                                  },
                                ),
                              )).toList(),
                              const SizedBox(height: 32.0),
                            ],
                          ),

                        Consumer<PollsViewModel>(
                          builder: (context, pollsViewModel, _) {
                            final activePolls = pollsViewModel.polls
                                .where((poll) => poll.isActive && !poll.expiresAt.isBefore(DateTime.now()))
                                .toList();
                            if (activePolls.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  title: 'Active Polls',
                                  onViewAll: () => _switchToTab(context, 3),
                                ),
                                const SizedBox(height: 16.0),
                                ...activePolls.map((poll) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: PollCard(poll: poll),
                                )).toList(),
                                const SizedBox(height: 32.0),
                              ],
                            );
                          },
                        ),

                        if (homeViewModel.topDiscussions.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Trending Discussions',
                                onViewAll: () => _switchToTab(context, 2),
                              ),
                              const SizedBox(height: 16.0),
                              ...homeViewModel.topDiscussions.map((discussion) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: DiscussionPostCard(
                                  discussion: discussion,
                                  onVote: (isUpvote) async {
                                    // Get both view models to ensure synchronized state
                                    final discussionsVM = Provider.of<DiscussionsViewModel>(context, listen: false);
                                    final homeVM = Provider.of<HomeViewModel>(context, listen: false);
                                    
                                    // Update vote in discussions view model first
                                    await discussionsVM.voteDiscussion(discussion.id, isUpvote);
                                    
                                    // Then update the home view model to reflect the change
                                    await homeVM.updateDiscussionVote(discussion.id, isUpvote);
                                  },
                                  onReply: () {
                                    // Get the updated discussion from discussions view model
                                    final discussionsVM = Provider.of<DiscussionsViewModel>(context, listen: false);
                                    final updatedDiscussion = discussionsVM.getDiscussionById(discussion.id) ?? discussion;
                                    
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DiscussionDetailPage(
                                          discussion: updatedDiscussion,
                                          focusComment: true,
                                        ),
                                      ),
                                    );
                                  },
                                  onReport: () {
                                    final discussionsVM = context.read<DiscussionsViewModel>();
                                    discussionsVM.reportDiscussion(discussion.id, context);
                                  },
                                  onDelete: () async {
                                    final discussionsVM = context.read<DiscussionsViewModel>();
                                    await discussionsVM.deleteDiscussion(discussion.id);
                                  },
                                ),
                              )).toList(),
                            ],
                          ),

                        if (featuredArticles.isEmpty &&
                            homeViewModel.upcomingEvents.isEmpty &&
                            homeViewModel.activePolls.isEmpty &&
                            homeViewModel.topDiscussions.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 64.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Featured Content',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check back later for updates',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
