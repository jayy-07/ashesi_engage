import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../auth/models/app_user.dart';
import 'user_service.dart';
import '../../services/token_service.dart';
import 'package:flutter/material.dart';
import '../../views/screens/banned_user_screen.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TokenService _tokenService = TokenService();
  final DatabaseService _databaseService = DatabaseService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  bool isValidAshesiEmail(String email) {
    return email.endsWith('@ashesi.edu.gh') || 
           email.endsWith('@aucampus.onmicrosoft.com');
  }

  Future<AppUser?> signInWithMicrosoft() async {
    try {
      final microsoftProvider = OAuthProvider('microsoft.com')
        ..addScope('openid')
        ..addScope('profile')
        ..addScope('email')
        ..setCustomParameters({
          'prompt': 'select_account',
        });

      UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(microsoftProvider);
      } else {
        credential = await _auth.signInWithProvider(microsoftProvider);
      }

      if (credential.user != null) {
        // Print both ID token and access token for API testing
        final idToken = await credential.user!.getIdToken();
        final accessToken = await credential.user!.getIdToken(true);
        final customToken = await credential.user!.getIdTokenResult();
        debugPrint('ID Token for API Testing: $idToken');
        debugPrint('Access Token for API Testing: $accessToken');
        debugPrint('Custom Claims: ${customToken.claims}');
        
        if (!isValidAshesiEmail(credential.user!.email!)) {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'invalid-email',
            message: 'Only Ashesi email addresses are allowed',
          );
        }

        // Check if email is permanently banned
        final isEmailBanned = await _databaseService.isEmailBanned(credential.user!.email!);
        if (isEmailBanned) {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'email-banned',
            message: 'This email address has been permanently banned from creating an account.',
          );
        }

        // Get user data
        final user = await _databaseService.getUser(credential.user!.uid);
        if (user != null) {
          // Check if user is banned
          if (user.isBanned) {
            final now = DateTime.now();
            if (user.bannedUntil == null || user.bannedUntil!.isAfter(now)) {
              // User is still banned
              throw FirebaseAuthException(
                code: 'user-banned',
                message: 'Your account is banned.',
              );
            } else {
              // Ban has expired, update user status
              await _databaseService.unbanUser(user.uid);
            }
          }

          // Update login date for existing users
          await _databaseService.updateUserLoginDate(credential.user!.uid);
          
          // Save FCM token for notifications
          await _tokenService.saveToken(credential.user!.uid);
          
          return user;
        }

        // For new users, save FCM token and return null to trigger profile setup
        await _tokenService.saveToken(credential.user!.uid);
        
        return null;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-banned') {
        // Get the banned user data to show in the banned screen
        final bannedUser = await _databaseService.getUser(currentUser!.uid);
        if (bannedUser != null) {
          throw BannedUserException(bannedUser);
        }
      }
      debugPrint('Sign in error: $e');
      rethrow;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Check if user is banned
        final user = await _databaseService.getUser(result.user!.uid);
        if (user != null && user.isBanned) {
          final now = DateTime.now();
          if (user.bannedUntil == null || user.bannedUntil!.isAfter(now)) {
            // User is still banned
            throw BannedUserException(user);
          } else {
            // Ban has expired, update user status
            await _databaseService.unbanUser(user.uid);
          }
        }

        // Save FCM token after successful sign in
        await _tokenService.saveToken(result.user!.uid);
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Delete FCM token before signing out
        await _tokenService.deleteToken(userId);
      }
      await _auth.signOut();
      
      if (kIsWeb) {
        // Additional web-specific cleanup if needed
        // This helps ensure a clean state for the next sign-in
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error during sign out: $e');
      rethrow;
    }
  }
}

class BannedUserException implements Exception {
  final AppUser bannedUser;

  BannedUserException(this.bannedUser);
}
