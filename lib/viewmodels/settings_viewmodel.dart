import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsViewModel extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isLoading = true;
  String? _error;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Theme settings
  static const String _themeModeKey = 'themeMode';
  static const String _themeColorKey = 'themeColor';
  static const String systemDefaultTheme = 'System Default';
  
  // Available theme colors
  static const Map<String, Color> themeColors = {
    'Default Blue': Color(0xFF2234FF),
    'Royal Purple': Color(0xFF7B1FA2),
    'Forest Green': Color(0xFF2E7D32),
    'Deep Orange': Color(0xFFE64A19),
    'Teal': Color(0xFF00796B),
    'Pink': Color(0xFFE91E63),
    'Amber': Color(0xFFFFB300),
  };

  // Poll notification settings
  static const String _notifyNewPollKey = 'notifyNewPoll';
  static const String _notifyPollDeadlineKey = 'notifyPollDeadline';
  static const String _notifyPollResultsKey = 'notifyPollResults';

  // Proposal notification settings
  static const String _notifyProposalEndorsementKey = 'notifyProposalEndorsement';
  static const String _notifyProposalEndorsementCompleteKey = 'notifyProposalEndorsementComplete';
  static const String _notifyProposalReplyKey = 'notifyProposalReply';

  // Article notification settings
  static const String _notifyArticleKey = 'notifyArticle';

  // Event notification settings
  static const String _notifyNewEventKey = 'notifyNewEvent';
  static const String _notifyEventReminderKey = 'notifyEventReminder';

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Theme color getter
  Color get themeColor {
    final colorName = _prefs?.getString(_themeColorKey) ?? systemDefaultTheme;
    if (colorName == systemDefaultTheme) {
      if (_context != null) {
        // Get the system accent color from Android
        final platformBrightness = MediaQuery.platformBrightnessOf(_context!);
        final systemTheme = Theme.of(_context!);
        
        // Use the appropriate system color scheme based on the platform brightness
        return platformBrightness == Brightness.dark
          ? systemTheme.colorScheme.primary
          : systemTheme.colorScheme.primary;
      }
      return themeColors['Default Blue']!;
    }
    return themeColors[colorName] ?? themeColors['Default Blue']!;
  }

  // Add BuildContext for accessing Theme
  BuildContext? _context;
  void setContext(BuildContext context) {
    _context = context;
    // Force a rebuild when context changes to update system colors
    if (themeColorName == systemDefaultTheme) {
      notifyListeners();
    }
  }

  String get themeColorName {
    return _prefs?.getString(_themeColorKey) ?? systemDefaultTheme;
  }

  Future<void> setThemeColor(String colorName) async {
    if (_prefs == null) return;
    if (colorName != systemDefaultTheme && !themeColors.containsKey(colorName)) return;
    if (themeColorName == colorName) return;

    try {
      await _prefs!.setString(_themeColorKey, colorName);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  SettingsViewModel() {
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Load preferences from Firestore if available
      await _loadPreferencesFromFirestore();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPreferencesFromFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final data = userDoc.data();
      if (data == null) return;

      // Only update SharedPreferences if Firestore has the value
      if (data[_notifyNewPollKey] != null) {
        await _prefs?.setBool(_notifyNewPollKey, data[_notifyNewPollKey]);
      }
      if (data[_notifyPollDeadlineKey] != null) {
        await _prefs?.setBool(_notifyPollDeadlineKey, data[_notifyPollDeadlineKey]);
      }
      if (data[_notifyPollResultsKey] != null) {
        await _prefs?.setBool(_notifyPollResultsKey, data[_notifyPollResultsKey]);
      }
      if (data[_notifyProposalEndorsementKey] != null) {
        await _prefs?.setBool(_notifyProposalEndorsementKey, data[_notifyProposalEndorsementKey]);
      }
      if (data[_notifyProposalEndorsementCompleteKey] != null) {
        await _prefs?.setBool(_notifyProposalEndorsementCompleteKey, data[_notifyProposalEndorsementCompleteKey]);
      }
      if (data[_notifyProposalReplyKey] != null) {
        await _prefs?.setBool(_notifyProposalReplyKey, data[_notifyProposalReplyKey]);
      }
      if (data[_notifyArticleKey] != null) {
        await _prefs?.setBool(_notifyArticleKey, data[_notifyArticleKey]);
      }
      if (data[_notifyNewEventKey] != null) {
        await _prefs?.setBool(_notifyNewEventKey, data[_notifyNewEventKey]);
      }
      if (data[_notifyEventReminderKey] != null) {
        await _prefs?.setBool(_notifyEventReminderKey, data[_notifyEventReminderKey]);
      }
    } catch (e) {
      debugPrint('Error loading preferences from Firestore: $e');
    }
  }

  Future<void> _syncPreferencesToFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).set({
        _notifyNewPollKey: notifyNewPoll,
        _notifyPollDeadlineKey: notifyPollDeadline,
        _notifyPollResultsKey: notifyPollResults,
        _notifyProposalEndorsementKey: notifyProposalEndorsement,
        _notifyProposalEndorsementCompleteKey: notifyProposalEndorsementComplete,
        _notifyProposalReplyKey: notifyProposalReply,
        _notifyArticleKey: notifyArticle,
        _notifyNewEventKey: notifyNewEvent,
        _notifyEventReminderKey: notifyEventReminder,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing preferences to Firestore: $e');
    }
  }

  // Theme settings
  ThemeMode get themeMode {
    final value = _prefs?.getString(_themeModeKey) ?? 'system';
    return ThemeMode.values.firstWhere(
      (mode) => mode.toString() == 'ThemeMode.$value',
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_prefs == null) return;
    if (themeMode == mode) return;
    try {
      await _prefs!.setString(_themeModeKey, mode.toString().split('.').last);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Poll notification settings
  bool get notifyNewPoll => _prefs?.getBool(_notifyNewPollKey) ?? true;
  bool get notifyPollDeadline => _prefs?.getBool(_notifyPollDeadlineKey) ?? true;
  bool get notifyPollResults => _prefs?.getBool(_notifyPollResultsKey) ?? true;

  Future<void> setNotifyNewPoll(bool value) async {
    if (_prefs == null) return;
    if (notifyNewPoll == value) return;
    try {
      await _prefs!.setBool(_notifyNewPollKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setNotifyPollDeadline(bool value) async {
    if (_prefs == null) return;
    if (notifyPollDeadline == value) return;
    try {
      await _prefs!.setBool(_notifyPollDeadlineKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setNotifyPollResults(bool value) async {
    if (_prefs == null) return;
    if (notifyPollResults == value) return;
    try {
      await _prefs!.setBool(_notifyPollResultsKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Proposal notification settings
  bool get notifyProposalEndorsement => _prefs?.getBool(_notifyProposalEndorsementKey) ?? true;
  bool get notifyProposalEndorsementComplete => _prefs?.getBool(_notifyProposalEndorsementCompleteKey) ?? true;
  bool get notifyProposalReply => _prefs?.getBool(_notifyProposalReplyKey) ?? true;

  Future<void> setNotifyProposalEndorsement(bool value) async {
    if (_prefs == null) return;
    if (notifyProposalEndorsement == value) return;
    try {
      await _prefs!.setBool(_notifyProposalEndorsementKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setNotifyProposalEndorsementComplete(bool value) async {
    if (_prefs == null) return;
    if (notifyProposalEndorsementComplete == value) return;
    try {
      await _prefs!.setBool(_notifyProposalEndorsementCompleteKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setNotifyProposalReply(bool value) async {
    if (_prefs == null) return;
    if (notifyProposalReply == value) return;
    try {
      await _prefs!.setBool(_notifyProposalReplyKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Article notification settings
  bool get notifyArticle => _prefs?.getBool(_notifyArticleKey) ?? true;

  Future<void> setNotifyArticle(bool value) async {
    if (_prefs == null) return;
    if (notifyArticle == value) return;
    try {
      await _prefs!.setBool(_notifyArticleKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Event notification settings
  bool get notifyNewEvent => _prefs?.getBool(_notifyNewEventKey) ?? true;
  bool get notifyEventReminder => _prefs?.getBool(_notifyEventReminderKey) ?? true;

  Future<void> setNotifyNewEvent(bool value) async {
    if (_prefs == null) return;
    if (notifyNewEvent == value) return;
    try {
      await _prefs!.setBool(_notifyNewEventKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setNotifyEventReminder(bool value) async {
    if (_prefs == null) return;
    if (notifyEventReminder == value) return;
    try {
      await _prefs!.setBool(_notifyEventReminderKey, value);
      await _syncPreferencesToFirestore();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}