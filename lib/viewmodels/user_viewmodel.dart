import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/services/user_service.dart';
import '../auth/models/app_user.dart';

class UserViewModel extends ChangeNotifier {
  AppUser? _user;
  bool _isLoading = true;
  String? _error;

  // Getters
  String? get firstName => _user?.firstName;
  String? get lastName => _user?.lastName;
  String? get email => _user?.email;
  String? get profileImageUrl => _user?.photoURL;
  String? get classYear => _user?.classYear;
  String? get uid => _user?.uid;
  bool get isLoading => _isLoading;
  int get role => _user?.role ?? 3; // Default to regular user if not set
  bool get isAdmin => role <= 2; // Role 1 (superadmin) or 2 (admin)
  AppUser? get currentUser => _user;
  String? get error => _error;

  UserViewModel() {
    // Initial load
    _loadUserData();
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      // Instead of just updating state, we'll await the user data load
      await updateAuthState(user);
    });
  }

  Future<void> _loadUserData() async {
    _isLoading = true;
    notifyListeners();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Add retry logic for initial load after account creation
      for (int i = 0; i < 3; i++) {
        try {
          _user = await DatabaseService().getUser(currentUser.uid);
          if (_user != null) break;
          await Future.delayed(const Duration(milliseconds: 500)); // Wait before retry
        } catch (e) {
          debugPrint('Error loading user data (attempt ${i + 1}): $e');
          if (i == 2) _error = e.toString(); // Only set error on final attempt
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } else {
      _user = null;
    }
    
    _isLoading = false;
    notifyListeners();
    
    // If we still don't have user data after retries, try refreshing one more time
    if (currentUser != null && _user == null) {
      await Future.delayed(const Duration(seconds: 1));
      await refreshUserData();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await _loadUserData();
  }
  
  void clearUserData() {
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
  
  // Make updateAuthState async to properly handle the loading
  Future<UserViewModel> updateAuthState(User? user) async {
    if (user == null) {
      if (_user != null) {
        clearUserData();
      }
    } else {
      if (_user == null || _user?.uid != user.uid) {
        await _loadUserData();
      }
    }
    return this;
  }

  Future<void> updateProfilePhoto(String? photoURL) async {
    try {
      if (_user == null) throw Exception('No user signed in');
      
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'photoURL': photoURL});
      
      // Update locally
      _user = _user?.copyWith(photoURL: photoURL);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshUserData() async {
    try {
      _isLoading = true;
      notifyListeners();

      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null) {
        _user = await DatabaseService().getUser(user.uid);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error refreshing user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}