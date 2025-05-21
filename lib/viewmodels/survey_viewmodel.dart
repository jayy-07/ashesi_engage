import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/entities/survey.dart';
import '../models/services/auth_service.dart';
import '../models/services/user_service.dart';
import '../models/services/survey_service.dart';

class SurveyViewModel extends ChangeNotifier {
  final AuthService _authService;
  final SurveyService _surveyService = SurveyService();
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;
  List<Survey> _surveys = [];
  String? _error;
  Set<String> _availableClasses = {};
  Set<String> _availableCategories = {};
  List<String>? _userClasses;
  StreamSubscription<List<Survey>>? _surveysSubscription;

  // Filter states
  bool _showCompletedSurveys = false;
  bool _showPendingSurveys = false;
  final Set<String> _selectedCategories = {};

  bool get isLoading => _isLoading;
  
  // Get unfiltered surveys (for admin view)
  List<Survey> get adminSurveys {
    var filteredSurveys = List<Survey>.from(_surveys);
    
    // Apply status filters
    if (_showCompletedSurveys) {
      filteredSurveys = filteredSurveys.where((survey) => survey.isCompleted).toList();
    } else if (_showPendingSurveys) {
      filteredSurveys = filteredSurveys.where((survey) => !survey.isCompleted).toList();
    }

    // Apply category filters
    if (_selectedCategories.isNotEmpty) {
      filteredSurveys = filteredSurveys.where((survey) => 
        _selectedCategories.contains(survey.category)).toList();
    }

    // Sort by expiry date
    filteredSurveys.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    
    return filteredSurveys;
  }
  
  // Get class-filtered surveys (for user view)
  List<Survey> get userSurveys {
    final user = _authService.currentUser;
    if (user == null || _userClasses == null) return [];

    // Filter by class scope
    var filteredSurveys = _surveys.where((survey) {
      // Keep surveys for all classes
      if (survey.isAllClasses) return true;
      
      // Keep surveys targeted to user's class
      if (_userClasses!.isEmpty) return false;
      return survey.classScopes.any((scope) => _userClasses!.contains(scope));
    }).toList();
    
    // Apply status filters
    if (_showCompletedSurveys) {
      filteredSurveys = filteredSurveys.where((survey) => survey.isCompleted).toList();
    } else if (_showPendingSurveys) {
      filteredSurveys = filteredSurveys.where((survey) => !survey.isCompleted).toList();
    }

    // Apply category filters
    if (_selectedCategories.isNotEmpty) {
      filteredSurveys = filteredSurveys.where((survey) => 
        _selectedCategories.contains(survey.category)).toList();
    }

    // Sort by expiry date
    filteredSurveys.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    
    return filteredSurveys;
  }
  
  // Standard surveys getter - uses userSurveys by default
  List<Survey> get surveys => userSurveys;

  String? get error => _error;
  Set<String> get availableClasses => _availableClasses;
  Set<String> get availableCategories => _availableCategories;
  Set<String> get selectedCategories => _selectedCategories;

  // Filter getters
  bool get showCompletedSurveys => _showCompletedSurveys;
  bool get showPendingSurveys => _showPendingSurveys;

  SurveyViewModel(this._authService) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await Future.wait([
        _loadUserClasses(),
        _loadAvailableClasses(),
        _loadAvailableCategories(),
      ]);

      await _loadSurveys();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserClasses() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        _userClasses = [];
        return;
      }

      final userData = await _databaseService.getUserData(user.uid);

      final classYear = userData['classYear'] as String?;
      _userClasses = classYear != null && classYear.isNotEmpty ? [classYear] : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user classes: $e');
      }
      _error = e.toString();
      _userClasses = [];
    }
  }

  Future<void> _loadAvailableClasses() async {
    try {
      final classes = await _databaseService.getAvailableClasses();
      _availableClasses = classes.toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  Future<void> _loadAvailableCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('surveyCategories').get();
      if (doc.exists) {
        _availableCategories = Set.from(doc.data()?['available_categories'] ?? []);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading survey categories: $e');
    }
  }

  Future<void> _loadSurveys() async {
    try {
      _error = null;
      await _surveysSubscription?.cancel();
      
      // Determine if we should fetch all surveys (for admin on web)
      // or scoped surveys (for users on mobile)
      bool isAdminContext = kIsWeb; // Assuming admin uses web

      _surveysSubscription = _surveyService.getAllSurveys(
        classScopes: isAdminContext ? null : _userClasses, // Pass null classScopes if admin
        fetchAllForAdmin: isAdminContext
      ).listen(
        (surveys) {
          _surveys = surveys;
          notifyListeners();
        },
        onError: (e) {
          if (kDebugMode) {
            print('Error loading surveys: $e');
          }
          _error = e.toString();
          notifyListeners();
        }
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up surveys subscription: $e');
      }
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadSurveys();
  }

  Future<void> createSurvey({
    required String title,
    required String description,
    required String surveyLink,
    required dynamic imageFile,
    required DateTime expiresAt,
    required bool isAllClasses,
    required List<String> classScopes,
    required String category,
    required String organizer,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      String imageUrl = '';
      final user = _authService.currentUser;
      
      if (user == null) throw 'Not authorized to create surveys';

      if (imageFile != null) {
        final storageRef = _storage.ref().child('survey_images/${DateTime.now().millisecondsSinceEpoch}');
        if (kIsWeb) {
          await storageRef.putData(imageFile);
        } else {
          await storageRef.putFile(imageFile as File);
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      final survey = Survey(
        id: '',
        title: title,
        description: description,
        surveyLink: surveyLink,
        imageUrl: imageUrl,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        isAllClasses: isAllClasses,
        classScopes: classScopes,
        category: category,
        organizer: organizer,
        isCompleted: false,
      );

      await _surveyService.createSurvey(survey);
      await _loadSurveys();
      
    } catch (e) {
      _error = 'Failed to create survey: $e';
      notifyListeners();
      throw _error!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSurvey(String surveyId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get the survey to delete its image if it has one
      final survey = _surveys.firstWhere((s) => s.id == surveyId);
      if (survey.imageUrl.isNotEmpty) {
        try {
          final imageRef = FirebaseStorage.instance.refFromURL(survey.imageUrl);
          await imageRef.delete();
        } catch (e) {
          debugPrint('Error deleting survey image: $e');
        }
      }

      await _surveyService.deleteSurvey(surveyId);
      await _loadSurveys();
      
    } catch (e) {
      _error = 'Failed to delete survey: $e';
      notifyListeners();
      throw _error!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markSurveyAsCompleted(String surveyId) async {
    try {
      final survey = _surveys.firstWhere((s) => s.id == surveyId);
      await _surveyService.markSurveyAsCompleted(surveyId, !survey.isCompleted);
      await _loadSurveys();
    } catch (e) {
      _error = 'Failed to update survey completion status: $e';
      notifyListeners();
      throw _error!;
    }
  }

  Future<void> updateSurvey(Survey survey) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _surveyService.updateSurvey(survey);
      await _loadSurveys();
      
    } catch (e) {
      _error = 'Failed to update survey: $e';
      notifyListeners();
      throw _error!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Filter toggle methods
  void toggleCompletedSurveys() {
    _showCompletedSurveys = !_showCompletedSurveys;
    _showPendingSurveys = false;
    notifyListeners();
  }

  void togglePendingSurveys() {
    _showPendingSurveys = !_showPendingSurveys;
    _showCompletedSurveys = false;
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void clearFilters() {
    _showCompletedSurveys = false;
    _showPendingSurveys = false;
    _selectedCategories.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _surveysSubscription?.cancel();
    super.dispose();
  }
}