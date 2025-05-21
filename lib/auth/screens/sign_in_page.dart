import 'package:flutter/material.dart';
import '../../models/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import '../../models/services/user_service.dart';
import '../../config/platform_config.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _isLoading = false;
  final DatabaseService _databaseService = DatabaseService();
  
  // User roles
  static const int roleSuperAdmin = 1;
  static const int roleAdmin = 2;

  Future<void> handleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Starting Microsoft sign in...');
      final user = await AuthService().signInWithMicrosoft();
      debugPrint('Sign in completed. User is ${user == null ? 'new' : 'existing'}');
      
      if (!mounted) return;
      
      // Manual navigation based on user state
      if (user == null) {
        // New user - go to profile setup
        debugPrint('New user - navigating to profile setup');
        context.go('/profile-setup');
      } else {
        // Existing user - check role and platform
        final isAdmin = user.role == roleSuperAdmin || user.role == roleAdmin;
        
        if (PlatformConfig.isWeb) {
          if (isAdmin) {
            debugPrint('Admin on web - navigating to admin page');
            context.go('/admin');
          } else {
            debugPrint('Regular user on web - navigating to mobile-only');
            context.go('/mobile-only');
          }
        } else {
          // On mobile, everyone goes to home
          debugPrint('User on mobile - navigating to home');
          context.go('/');
        }
      }
      
    } on BannedUserException catch (e) {
      debugPrint('User is banned: ${e.bannedUser.banReason}');
      if (!mounted) return;
      
      // Navigate to banned screen with the banned user data
      context.go('/banned', extra: e.bannedUser);
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ashesi Logo
                  Image.asset(
                    'assets/images/Ashesi_University_Logo-5.webp',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 48),
                  
                  // Welcome Text
                  Text(
                    'Welcome to Ashesi Engage',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in with your Ashesi email to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Sign in with Microsoft Button
                  OutlinedButton(
                    onPressed: _isLoading ? null : handleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading)
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        else
                          Image.asset(
                            'assets/icons/microsoft_logo.png',
                            height: 24,
                            width: 24,
                          ),
                        const SizedBox(width: 12),
                        Text(
                          _isLoading ? 'Signing in...' : 'Sign in with Microsoft',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  // Optional: Add additional info or links here
                  Text(
                    'Only @ashesi.edu.gh accounts are allowed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}