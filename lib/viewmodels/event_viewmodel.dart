import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/entities/event.dart';
import '../models/services/event_service.dart';
import '../models/services/user_service.dart';

class EventViewModel extends ChangeNotifier {
  final EventService _eventService = EventService();
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<List<Event>>? _eventsSubscription;
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;
  List<String> _availableClasses = [];

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get availableClasses => _availableClasses;

  EventViewModel() {
    _listenToEvents();
    _loadAvailableClasses();
  }

  Future<void> _loadAvailableClasses() async {
    try {
      _availableClasses = await _databaseService.getAvailableClasses();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load available classes: $e';
      notifyListeners();
    }
  }

  void _listenToEvents() {
    _eventsSubscription = _eventService.getEvents().listen(
      (events) {
        _events = events;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load events: $error';
        notifyListeners();
      },
    );
  }

  Future<void> createEvent({
    dynamic imageFile,
    required String title,
    required String shortDescription,
    required String longDescription,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
    required bool isAllDay,
    required String organizer,
    required List<String> classScopes,
    required bool isAllClasses,
    bool isVirtual = false,
    String? meetingLink,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _eventService.createEvent(
        imageFile: imageFile,
        title: title.trim(),
        shortDescription: shortDescription.trim(),
        longDescription: longDescription.trim(),
        location: location.trim(),
        startTime: startTime,
        endTime: endTime,
        isAllDay: isAllDay,
        organizer: organizer.trim(),
        classScopes: classScopes,
        isAllClasses: isAllClasses,
        isVirtual: isVirtual,
        meetingLink: meetingLink,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to create event: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteEvent(Event event) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _eventService.deleteEvent(event);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to delete event: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateEvent(Event event) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _eventService.updateEvent(event);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to update event: $e';
      notifyListeners();
      rethrow;
    }
  }

  List<Event> get upcomingEvents => _events
      .where((event) => event.endTime.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }
}