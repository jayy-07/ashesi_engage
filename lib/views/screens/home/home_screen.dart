import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'home_content.dart';
import '../proposals/proposals_page.dart';
import '../events/events_page.dart';
import '../forum/forum_page.dart';
import '../polls/polls_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/profile_drawer.dart';
import '../../../viewmodels/user_viewmodel.dart';
import '../../../models/services/auth_service.dart';
import '../../../viewmodels/polls_viewmodel.dart';
import '../../../viewmodels/survey_viewmodel.dart';
import '../../../services/connectivity_service.dart';

class HomeScreen extends StatefulWidget {
  final String? initialTab;
  final String? pollHighlight;

  const HomeScreen({
    super.key,
    this.initialTab,
    this.pollHighlight,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _hideController;
  late Animation<double> _hideAnimation;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Widget> get _pages => [
    const HomeContent(),
    const ProposalsPage(),
    const ForumPage(),
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PollsViewModel>(
          create: (context) => PollsViewModel(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider<SurveyViewModel>(
          create: (context) => SurveyViewModel(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
      ],
      child: PollsScreen(
        highlightedPollId: widget.pollHighlight,
      ),
    ),
    const EventsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_hideController);

    _scrollController.addListener(_onScroll);

    if (widget.initialTab != null) {
      switch (widget.initialTab) {
        case 'home':
          _selectedIndex = 0;
          break;
        case 'proposals':
          _selectedIndex = 1;
          break;
        case 'forum':
          _selectedIndex = 2;
          break;
        case 'polls':
          _selectedIndex = 3;
          break;
        case 'events':
          _selectedIndex = 4;
          break;
      }
    }
  }

  @override
  void dispose() {
    _hideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      _hideController.forward(from: _hideController.value);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      _hideController.reverse(from: _hideController.value);
    }
  }

  void onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PollsViewModel>(
          create: (_) => PollsViewModel(AuthService()),
        ),
      ],
      child: Consumer<ConnectivityService>(
        builder: (context, connectivity, child) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: const ProfileDrawer(),
            body: SafeArea(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    if (scrollNotification.dragDetails != null) {
                      if (scrollNotification.dragDetails!.primaryDelta! < -1) {
                        _hideController.forward();
                      } else if (scrollNotification.dragDetails!.primaryDelta! > 1) {
                        _hideController.reverse();
                      }
                    }
                  }
                  return false;
                },
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        pinned: true,
                        scrolledUnderElevation: 4.0,
                        surfaceTintColor: Theme.of(context).colorScheme.surface,
                        backgroundColor: innerBoxIsScrolled 
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.surface,
                        leadingWidth: 150,
                        leading: GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                child: SizedBox(
                                  width: 30.0,
                                  height: 30.0,
                                  child: Center(
                                    child: Consumer<UserViewModel>(
                                      builder: (context, userVM, _) => userVM.isLoading
                                        ? UserAvatar(
                                            radius: 15,
                                            fallbackInitial: '?',
                                          )
                                        : UserAvatar(
                                            imageUrl: userVM.profileImageUrl,
                                            radius: 15,
                                            fallbackInitial: (userVM.firstName?.isNotEmpty == true) 
                                              ? userVM.firstName!.substring(0, 1) 
                                              : '?',
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/images/ashesi_logo.png',
                                height: 16.0,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                        titleSpacing: 0,
                        actions: [
                          Consumer<ConnectivityService>(
                            builder: (context, connectivity, _) {
                              if (connectivity.isOnline) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.wifi_off_rounded,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onErrorContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'You\'re offline',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            tooltip: 'Notifications',
                            onPressed: () => context.pushNamed('notifications'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            tooltip: 'Settings',
                            onPressed: () => context.pushNamed('settings'),
                          ),
                        ],
                      ),
                    ];
                  },
                  body: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ),
            ),
            bottomNavigationBar: AnimatedBuilder(
                  animation: _hideAnimation,
                  builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 56 * _hideAnimation.value),
                  child: child,
                );
              },
                        child: NavigationBar(
                          selectedIndex: _selectedIndex,
                onDestinationSelected: onNavBarTap,
                destinations: const [
                            NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                              label: 'Home',
                            ),
                            NavigationDestination(
                    icon: Icon(Icons.lightbulb_outline),
                    selectedIcon: Icon(Icons.lightbulb),
                              label: 'Proposals',
                            ),
                            NavigationDestination(
                    icon: Icon(Icons.forum_outlined),
                    selectedIcon: Icon(Icons.forum),
                              label: 'Forum',
                            ),
                            NavigationDestination(
                    icon: Icon(Icons.poll_outlined),
                    selectedIcon: Icon(Icons.poll),
                              label: 'Polls',
                            ),
                            NavigationDestination(
                    icon: Icon(Icons.event_outlined),
                    selectedIcon: Icon(Icons.event),
                              label: 'Events',
                            ),
                          ],
                        ),
            ),
          );
        },
      ),
    );
  }
}
