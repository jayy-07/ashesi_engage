import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'views/screens/home/home_screen.dart';
import 'views/admin/admin_screen.dart';
import 'viewmodels/home_viewmodel.dart' as home;
import 'viewmodels/proposals_viewmodel.dart';
import 'viewmodels/events_viewmodel.dart';
import 'viewmodels/discussions_viewmodel.dart';
import 'auth/screens/profile_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/services/auth_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'models/services/user_service.dart';
import 'viewmodels/user_viewmodel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'viewmodels/event_viewmodel.dart';
import 'viewmodels/polls_viewmodel.dart';
import 'viewmodels/survey_viewmodel.dart';
import 'viewmodels/admin_polls_viewmodel.dart';
import 'viewmodels/user_management_viewmodel.dart';
import 'views/screens/banned_user_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'auth/models/app_user.dart';
import 'models/services/proposal_service.dart';
import 'services/notification_service.dart';
import 'providers/bookmark_provider.dart';
import 'services/connectivity_service.dart';
import 'config/router_config.dart';
import 'package:app_links/app_links.dart';
import 'viewmodels/settings_viewmodel.dart';

// Global variable to store initial link
String? initialLink;
bool _deepLinkSetupAttempted = false;

void _setupDeepLinkHandling() async {
  if (kIsWeb || _deepLinkSetupAttempted) {
    if (kIsWeb) debugPrint('Skipping deep link setup for web platform');
    if (_deepLinkSetupAttempted) debugPrint('Deep link setup already attempted.');
    return;
  }
  _deepLinkSetupAttempted = true;

  final appLinks = AppLinks();
  debugPrint('Setting up deep link handling for ashesiengage:// scheme');

  try {
    final appLink = await appLinks.getInitialAppLink();
    if (appLink != null) {
      debugPrint('Initial deep link: ${appLink.toString()}');
      initialLink = appLink.toString();
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      appLinks.uriLinkStream.listen((Uri uri) {
        debugPrint('Deep link received while app running: ${uri.toString()}');
        _handleDeepLinkDirectly(uri.toString(), isInitialLink: false);
      }, onError: (error) {
        debugPrint('Error handling deep link stream: $error');
      });
    });
  } catch (e) {
    debugPrint('Error during deep link setup: $e');
  }
}

void _handleDeepLinkDirectly(String uriString, {bool isInitialLink = false}) {
  debugPrint('Handling deep link directly: $uriString');

  try {
    if (uriString.contains('proposals')) {
      final regex = RegExp(r'proposals/([^/?&#]+)');
      final match = regex.firstMatch(uriString);
      
      if (match != null && match.groupCount >= 1) {
        final proposalId = match.group(1);
        debugPrint('Extracted proposal ID: $proposalId');
        
        if (proposalId != null && proposalId.isNotEmpty) {
          initialLink = uriString;
          
          Future.delayed(const Duration(milliseconds: 100), () {
            final route = '/proposals/$proposalId';
            debugPrint('🔗 Deep Link: Navigating to route: $route');
            
            if (isInitialLink) {
              router.go(route);
            } else {
              router.push(route);
            }
          });
        }
      } else {
        debugPrint('❌ Could not extract proposal ID from URI: $uriString');
      }
    }
    else if (uriString.contains('discussions')) {
      final regex = RegExp(r'discussions/([^/?&#]+)');
      final match = regex.firstMatch(uriString);
      
      if (match != null && match.groupCount >= 1) {
        final discussionId = match.group(1);
        debugPrint('Extracted discussion ID: $discussionId');
        
        if (discussionId != null && discussionId.isNotEmpty) {
          initialLink = uriString;
          
          Future.delayed(const Duration(milliseconds: 100), () {
            final route = '/discussions/$discussionId';
            debugPrint('🔗 Deep Link: Navigating to route: $route');
            
            if (isInitialLink) {
              router.go(route);
            } else {
              router.push(route);
            }
          });
        }
      } else {
        debugPrint('❌ Could not extract discussion ID from URI: $uriString');
      }
    } else if (uriString.contains('events')) {
      final regex = RegExp(r'events/([^/?&#]+)');
      final match = regex.firstMatch(uriString);
      
      if (match != null && match.groupCount >= 1) {
        final eventId = match.group(1);
        debugPrint('Extracted event ID: $eventId');
        
        if (eventId != null && eventId.isNotEmpty) {
          initialLink = uriString;
          
          Future.delayed(const Duration(milliseconds: 100), () {
            final route = '/events/$eventId';
            debugPrint('🔗 Deep Link: Navigating to route: $route');
            
            if (isInitialLink) {
              router.go(route);
            } else {
              router.push(route);
            }
          });
        }
      } else {
        debugPrint('❌ Could not extract event ID from URI: $uriString');
      }
    } else {
      debugPrint('⚠️ Unhandled deep link type: $uriString');
    }
  } catch (e) {
    debugPrint('❌ Error handling deep link: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (message.notification != null) {
    final notification = NotificationService();
    await notification.showPollNotification(
      title: message.notification!.title ?? 'New Poll',
      body: message.notification!.body ?? '',
      payload: message.data,
    );
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 10485760,
      sslEnabled: true,
    );
    
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('6LfyWvcqAAAAAKo3xn7N6Tx-dCrt4V3QahfRPGVo'),
      ).catchError((error) {
        debugPrint('Error activating App Check: $error');
      });
    } else {
      await FirebaseAppCheck.instance.activate().catchError((error) {
        debugPrint('Error activating App Check: $error');
      });
      
      Future.delayed(const Duration(milliseconds: 500), () async {
        await NotificationService().initialize().catchError((error) {
          debugPrint('Error initializing notifications: $error');
        });
      });

      _setupDeepLinkHandling();

      Timer.periodic(const Duration(minutes: 15), (_) {
        NotificationService().checkForPendingNotifications().catchError((error) {
          debugPrint('Error checking notifications: $error');
        });
      });
    }

    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top],
      );
    }

    runApp(
      MultiProvider(
        providers: [
          Provider<AuthService>(
            create: (_) => AuthService(),
            lazy: false,
          ),
          Provider<DatabaseService>(
            create: (_) => DatabaseService(),
            lazy: true,
          ),
          Provider<NotificationService>(
            create: (_) => NotificationService(),
            lazy: true,
          ),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService(),
            lazy: true,
          ),
          ChangeNotifierProvider<SettingsViewModel>(
            create: (_) => SettingsViewModel(),
            lazy: true,
          ),

          ChangeNotifierProxyProvider<AuthService, UserViewModel>(
            create: (context) => UserViewModel(),
            update: (context, authService, previousViewModel) => 
              previousViewModel!..updateAuthState(authService.currentUser),
            lazy: true,
          ),
          ChangeNotifierProvider<home.HomeViewModel>(
            create: (context) => home.HomeViewModel(),
            lazy: true,
          ),
          ChangeNotifierProvider<ProposalsViewModel>(
            create: (context) => ProposalsViewModel(
              Provider.of<AuthService>(context, listen: false)
            ),
            lazy: true,
          ),
          ChangeNotifierProvider<DiscussionsViewModel>(
            create: (context) => DiscussionsViewModel(
              Provider.of<AuthService>(context, listen: false)
            ),
            lazy: true,
          ),
          ChangeNotifierProvider<EventsViewModel>(
            create: (context) => EventsViewModel(),
            lazy: true,
          ),
          ChangeNotifierProvider<EventViewModel>(
            create: (context) => EventViewModel(),
            lazy: true,
          ),
          ChangeNotifierProvider<PollsViewModel>(
            create: (context) => PollsViewModel(
              Provider.of<AuthService>(context, listen: false),
            ),
            lazy: true,
          ),
          ChangeNotifierProvider<SurveyViewModel>(
            create: (context) => SurveyViewModel(
              Provider.of<AuthService>(context, listen: false),
            ),
            lazy: true,
          ),
          ChangeNotifierProvider<AdminPollsViewModel>(
            create: (context) => AdminPollsViewModel(
              Provider.of<AuthService>(context, listen: false),
            ),
            lazy: true,
          ),
          ChangeNotifierProvider<UserManagementViewModel>(
            create: (context) => UserManagementViewModel(),
            lazy: true,
          ),
          ChangeNotifierProvider(
            create: (_) => BookmarkProvider(),
            lazy: true,
          ),
        ],
        child: const AshesiEngageApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Error in main: $e\n$stackTrace');
  }
}

class AshesiEngageApp extends StatelessWidget {
  const AshesiEngageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (context, settings, child) {
        return MaterialApp.router(
          title: 'Ashesi Engage',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: settings.themeColor,
            brightness: Brightness.light,
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                TargetPlatform.android: SharedAxisPageTransitionsBuilder(
                  transitionType: SharedAxisTransitionType.horizontal,
                ),
                TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
                  transitionType: SharedAxisTransitionType.horizontal,
                ),
              },
            ),
            platform: TargetPlatform.android,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: settings.themeColor,
            brightness: Brightness.dark,
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                TargetPlatform.android: SharedAxisPageTransitionsBuilder(
                  transitionType: SharedAxisTransitionType.horizontal,
                ),
                TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
                  transitionType: SharedAxisTransitionType.horizontal,
                ),
              },
            ),
            platform: TargetPlatform.android,
          ),
          themeMode: settings.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _AuthenticatedUserHandler extends StatefulWidget {
  final User user;

  const _AuthenticatedUserHandler({
    required this.user,
  });

  @override
  State<_AuthenticatedUserHandler> createState() => _AuthenticatedUserHandlerState();
}

class _AuthenticatedUserHandlerState extends State<_AuthenticatedUserHandler> {
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupUserSubscription();
  }

  void _setupUserSubscription() {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
    
    _userSubscription = userDoc.snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        setState(() {
          _isLoading = false;
          _currentUser = null;
        });
        return;
      }

      final user = AppUser.fromMap(snapshot.data()!);
      
      if (user.isBanned && _currentUser != null && !_currentUser!.isBanned) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been banned.'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }, onError: (error) {
      debugPrint('Error in user subscription: $error');
      setState(() {
        _isLoading = false;
        _currentUser = null;
      });
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return const ProfileSetupPage();
    }

    if (_currentUser!.isBanned) {
      return BannedUserScreen(user: _currentUser!);
    }

    if (kIsWeb && _currentUser!.role <= 2) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminPollsViewModel>(
            create: (context) => AdminPollsViewModel(
              Provider.of<AuthService>(context, listen: false),
            ),
          ),
          ChangeNotifierProvider<UserManagementViewModel>(
            create: (context) => UserManagementViewModel(),
          ),
          Provider<ProposalService>(
            create: (context) => ProposalService(),
          ),
        ],
        child: const AdminScreen(),
      );
    }
    
    return const HomeScreen();
  }
}
