import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../auth/screens/setup_complete_page.dart';
import '../auth/screens/sign_in_page.dart';
import 'package:flutter/foundation.dart';
import '../viewmodels/admin_discussions_viewmodel.dart';
import '../viewmodels/admin_proposals_viewmodel.dart';
import '../viewmodels/article_viewmodel.dart';
import '../views/screens/forum/discussion_detail_page.dart';
import '../views/screens/home/home_screen.dart';
import '../models/services/discussion_service.dart';
import '../models/services/user_service.dart';
import '../models/services/article_service.dart';
import '../config/platform_config.dart';
import '../views/screens/mobile_only_screen.dart';
import '../views/admin/admin_screen.dart';
import '../views/admin/screens/admin_reports_screen.dart';
import '../views/screens/events/event_detail_page.dart';
import '../views/screens/proposals/proposal_detail_page.dart';
import '../models/entities/student_proposal.dart';
import '../models/entities/event.dart';
import '../models/entities/article.dart';
import '../models/services/proposal_service.dart';
import '../models/services/event_service.dart';
import '../views/screens/proposals/proposals_page.dart';
import '../views/screens/events/events_page.dart';
import '../views/screens/articles/articles_page.dart';
import '../views/admin/article/article_detail_page.dart';
import '../views/screens/polls/polls_screen.dart';
import '../auth/screens/profile_setup_page.dart';
import '../views/screens/settings/settings_screen.dart';
import '../views/screens/notifications/notification_screen.dart';
import '../views/screens/replies/my_replies_page.dart';
import '../views/screens/banned_user_screen.dart';
import '../auth/models/app_user.dart';

// Add this class to manage auth state
class AuthStateManager extends ChangeNotifier {
  AuthStateManager() {
    // Listen to Firebase auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('Auth state changed - User: ${user?.uid}');
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _authSubscription;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

// Create a single instance of AuthStateManager
final _authStateManager = AuthStateManager();

final _discussionService = DiscussionService();
final _databaseService = DatabaseService();
final _proposalService = ProposalService();
final _eventService = EventService();

// Navigation logger for debugging
class NavigationLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Pushed route: ${route.settings.name} with arguments: ${route.settings.arguments}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint('Replaced route: ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Popped route: ${route.settings.name}');
  }
}

// User roles
const int roleSuperAdmin = 1;
const int roleAdmin = 2;
const int roleRegular = 3;

// Authentication middleware
Widget _requireAuth(BuildContext context, Widget child) {
  if (FirebaseAuth.instance.currentUser == null) {
    return const SignInPage();
  }
  return child;
}

final router = GoRouter(
  refreshListenable: _authStateManager,
  initialLocation: '/',
  redirectLimit: 10,  // Prevent infinite redirects
  debugLogDiagnostics: true,  // Enable debug logging
  redirect: (context, state) async {
    debugPrint('Router redirect called for ${state.matchedLocation}');
    
    // Get current auth state
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isSignInPage = state.matchedLocation == '/signin';
    final isMobileOnlyPage = state.matchedLocation == '/mobile-only';
    final isSetupCompletePage = state.matchedLocation == '/setup-complete';
    final isAdminRoute = state.matchedLocation.startsWith('/admin');
    final isProfileSetupPage = state.matchedLocation == '/profile-setup';
    final isBannedPage = state.matchedLocation == '/banned';

    debugPrint('Redirect check - isLoggedIn: $isLoggedIn, location: ${state.matchedLocation}');

    // If not logged in and not on sign in page, redirect to sign in
    if (!isLoggedIn && !isSignInPage) {
      debugPrint('Not logged in, redirecting to signin');
      return '/signin';
    }

    // Handle the web platform specific redirects first
    if (PlatformConfig.isWeb) {
      if (isLoggedIn) {
        final dbUser = await _databaseService.getUser(user!.uid);
        final isAdmin = dbUser?.role == roleSuperAdmin || dbUser?.role == roleAdmin;

        // Admin checks
        if (isAdmin) {
          // Admins should always be in admin section except when signing out
          if (!isSignInPage && !isAdminRoute && !isBannedPage) {
            return '/admin';
          }
        } else {
          // Non-admin users on web should always see mobile-only screen
          if (!isMobileOnlyPage && !isSignInPage && !isBannedPage) {
            return '/mobile-only';
          }
        }
      }
      return null;
    }

    // Mobile platform specific logic
    if (isLoggedIn && !isSignInPage && !isProfileSetupPage && !isSetupCompletePage && !isBannedPage) {
      debugPrint('Checking user in database - UID: ${user!.uid}');
      final dbUser = await _databaseService.getUser(user.uid);
      
      // If user doesn't exist in database, redirect to profile setup
      if (dbUser == null) {
        debugPrint('User not in database, redirecting to profile setup');
        return '/profile-setup';
      }

      // On mobile, after profile setup, show setup complete page
      if (isProfileSetupPage) {
        return '/setup-complete';
      }
    }

    // Block admin routes on mobile
    if (isAdminRoute) {
      return '/';
    }

    debugPrint('No redirect needed');
    return null;
  },
  // Observer to log navigation events
  observers: [NavigationLogger()],
  routes: [
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInPage(),
    ),
    GoRoute(
      path: '/banned',
      builder: (context, state) {
        final user = state.extra as AppUser?;
        if (user == null) {
          return const SignInPage();
        }
        return BannedUserScreen(user: user);
      },
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupPage(),
    ),
    GoRoute(
      path: '/setup-complete',
      builder: (context, state) => const SetupCompletePage(),
    ),
    GoRoute(
      path: '/mobile-only',
      builder: (context, state) => const MobileOnlyScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => _requireAuth(context, const AdminScreen()),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => _requireAuth(context, const AdminReportsScreen()),
    ),
    // Add routes for admin proposal and discussion detail screens
    GoRoute(
      path: '/admin/proposals/:id',
      name: 'admin-proposal-detail',
      builder: (context, state) {
        final proposalId = state.pathParameters['id']!;
        final commentId = state.uri.queryParameters['commentId'];
        return _requireAuth(
          context,
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AdminProposalsViewModel()),
            ],
            child: AdminScreen(initialProposalId: proposalId, highlightCommentId: commentId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/admin/discussions/:id',
      name: 'admin-discussion-detail',
      builder: (context, state) {
        final discussionId = state.pathParameters['id']!;
        final commentId = state.uri.queryParameters['commentId'];
        return _requireAuth(
          context,
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AdminDiscussionsViewModel()),
            ],
            child: AdminScreen(initialDiscussionId: discussionId, highlightCommentId: commentId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => _requireAuth(
        context,
        HomeScreen(
          initialTab: state.uri.queryParameters['tab'],
          pollHighlight: state.uri.queryParameters['highlight'],
        ),
      ),
    ),
    // Proposal routes
    GoRoute(
      path: '/proposals',
      name: 'proposals',
      builder: (context, state) => _requireAuth(
        context,
        const ProposalsPage(),
      ),
    ),
    GoRoute(
      path: '/proposals/:id',
      name: 'proposal-detail',
      builder: (context, state) => _requireAuth(
        context,
        FutureBuilder<StudentProposal?>(
          future: _proposalService.getProposal(state.pathParameters['id']!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Scaffold(
                body: Center(child: Text('Proposal not found')),
              );
            }
            
            // Get comment ID to highlight from query parameters
            final commentId = state.uri.queryParameters['commentId'];
            
            return ProposalDetailPage(
              proposalId: snapshot.data!.id,
              highlightCommentId: commentId,
            );
          },
        ),
      ),
    ),
    // Event routes
    GoRoute(
      path: '/events',
      builder: (context, state) => _requireAuth(
        context,
        const EventsPage(),
      ),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) => _requireAuth(
        context,
        FutureBuilder(
          future: _eventService.getEventById(state.pathParameters['id']!),
          builder: (context, AsyncSnapshot<Event?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Scaffold(
                body: Center(child: Text('Event not found')),
              );
            }
            return EventDetailPage(event: snapshot.data!);
          },
        ),
      ),
    ),
    // Polls route
    GoRoute(
      path: '/polls',
      name: 'polls',
      builder: (context, state) => _requireAuth(
        context,
        PollsScreen(
          highlightedPollId: state.uri.queryParameters['highlight'],
        ),
      ),
    ),
    // Add poll notification route
    GoRoute(
      path: '/polls/:id',
      name: 'poll-detail',
      builder: (context, state) {
        final pollId = state.pathParameters['id']!;
        return _requireAuth(
          context,
          PollsScreen(
            initialPollId: pollId,
            highlightedPollId: pollId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/discussions/:discussionId',
      name: 'discussion-detail',
      builder: (context, state) => FutureBuilder(
        future: _discussionService
            .getDiscussion(state.pathParameters['discussionId']!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Not Found')),
              body: const Center(child: Text('Discussion not found')),
            );
          }

          // Get comment ID to highlight from query parameters
          final commentId = state.uri.queryParameters['commentId'];

          return _requireAuth(
              context, 
              DiscussionDetailPage(
                discussion: snapshot.data!,
                highlightCommentId: commentId,
              )
          );
        },
      ),
    ),
    // Settings route
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => _requireAuth(
        context,
        const SettingsScreen(),
      ),
    ),
    // Add notifications route
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => _requireAuth(
        context,
        const NotificationScreen(),
      ),
    ),
    // Add replies route
    GoRoute(
      path: '/replies',
      name: 'replies',
      builder: (context, state) => _requireAuth(
        context,
        const MyRepliesPage(),
      ),
    ),
    // Add articles route
    GoRoute(
      path: '/articles',
      name: 'articles',
      builder: (context, state) => _requireAuth(
        context,
        ChangeNotifierProvider(
          create: (_) => ArticleViewModel(),
          child: const ArticlesPage(),
        ),
      ),
    ),
    // Add article detail route for notifications
    GoRoute(
      path: '/articles/:id',
      name: 'article-detail',
      builder: (context, state) => _requireAuth(
        context,
        FutureBuilder<Article?>(
          future: ArticleService().getArticle(state.pathParameters['id']!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Scaffold(
                body: Center(child: Text('Article not found')),
              );
            }
            return ArticleDetailPage.wrapped(
              article: snapshot.data!,
            );
          },
        ),
      ),
    ),
  ],
);
