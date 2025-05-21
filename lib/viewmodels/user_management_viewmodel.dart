import 'package:flutter/foundation.dart';
import '../models/services/database_service.dart';
import '../auth/models/app_user.dart';

class UserManagementViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<AppUser> _users = [];
  bool _isLoading = false;
  String? _error;

  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _databaseService.getAllUsers();
      _users.sort((a, b) => b.accountCreationDate.compareTo(a.accountCreationDate));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _databaseService.deleteUser(uid);
      await loadUsers(); // Reload the list
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> permanentlyDeleteUser(String uid) async {
    try {
      await _databaseService.permanentlyDeleteUser(uid);
      await loadUsers(); // Reload the list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> banUser(String uid, {DateTime? until, String? reason}) async {
    try {
      await _databaseService.banUser(uid, until: until, reason: reason);
      await loadUsers(); // Reload the list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> unbanUser(String uid) async {
    await _databaseService.unbanUser(uid);
    await loadUsers();
  }

  Future<void> updateUserRole(String uid, int newRole) async {
    await _databaseService.updateUser(uid, {'role': newRole});
    await loadUsers();
  }

  String getRoleLabel(int role) {
    switch (role) {
      case 1:
        return 'Super Admin';
      case 2:
        return 'Admin';
      case 3:
        return 'User';
      default:
        return 'Unknown';
    }
  }

  String getBanStatus(AppUser user) {
    if (!user.isBanned) return 'Active';
    if (user.bannedUntil == null) return 'Permanently Banned';
    return 'Banned until ${user.bannedUntil!.toLocal().toString().split(' ')[0]}';
  }
} 