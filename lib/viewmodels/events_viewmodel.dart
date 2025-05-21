import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;
import '../models/entities/event.dart';
import '../models/services/user_service.dart';

enum EventFilter {
  all,
  today,
  thisWeek,
  thisMonth,
}

class EventsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  bool _isLoading = true;
  Map<String, List<Event>> _eventsByMonth = {};
  String? _userClass;
  EventFilter _currentFilter = EventFilter.all;

  // Getters
  bool get isLoading => _isLoading;
  Map<String, List<Event>> get eventsByMonth => _filteredEvents;
  EventFilter get currentFilter => _currentFilter;

  Map<String, List<Event>> get _filteredEvents {
    final now = DateTime.now();
    final Map<String, List<Event>> filtered = {};
    
    for (final entry in _eventsByMonth.entries) {
      final List<Event> filteredList = entry.value.where((event) {
        switch (_currentFilter) {
          case EventFilter.today:
            return event.startTime.year == now.year &&
                   event.startTime.month == now.month &&
                   event.startTime.day == now.day;
          case EventFilter.thisWeek:
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 7));
            return event.startTime.isAfter(weekStart) && 
                   event.startTime.isBefore(weekEnd);
          case EventFilter.thisMonth:
            return event.startTime.year == now.year &&
                   event.startTime.month == now.month;
          case EventFilter.all:
            return true;
        }
      }).toList();

      if (filteredList.isNotEmpty) {
        filtered[entry.key] = filteredList;
      }
    }
    
    return filtered;
  }

  EventsViewModel() {
    loadUserClassAndEvents();
  }

  void setFilter(EventFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> loadUserClassAndEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        _userClass = user.classYear;
        await loadEvents();
      }
    } catch (e) {
      debugPrint('Error loading user class: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEvents() async {
    try {
      final QuerySnapshot eventSnapshot = await _firestore
          .collection('events')
          .orderBy('startTime')
          .get();

      final events = eventSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Event.fromMap({...data, 'id': doc.id});
      }).where((event) {
        // Filter events based on user's class and date
        if (_userClass == null) return false;
        if (event.startTime.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
          return false; // Don't show past events
        }
        return event.isAllClasses || event.classScopes.contains(_userClass);
      }).toList();

      // Group events by month
      _eventsByMonth = {};
      for (final event in events) {
        final monthKey = '${event.startTime.year}-${event.startTime.month.toString().padLeft(2, '0')}';
        if (!_eventsByMonth.containsKey(monthKey)) {
          _eventsByMonth[monthKey] = [];
        }
        _eventsByMonth[monthKey]!.add(event);
      }

      // Sort events within each month
      for (final events in _eventsByMonth.values) {
        events.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  Future<void> addToCalendar(Event event) async {
    try {
      final calendarEvent = calendar.Event(
        title: event.title,
        description: event.shortDescription,
        location: event.location,
        startDate: event.startTime,
        endDate: event.endTime,
        allDay: event.isAllDay,
      );
      
      await calendar.Add2Calendar.addEvent2Cal(calendarEvent);
    } catch (e) {
      debugPrint('Error adding event to calendar: $e');
      rethrow;
    }
  }
}