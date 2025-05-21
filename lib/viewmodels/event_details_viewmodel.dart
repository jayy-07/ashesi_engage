import 'package:flutter/foundation.dart';
import '../models/entities/event.dart';

class EventDetailsViewModel extends ChangeNotifier {
  final Event _event;
  bool _isAddingToCalendar = false;

  EventDetailsViewModel(this._event);

  Event get event => _event;
  bool get isAddingToCalendar => _isAddingToCalendar;

  Future<void> addToCalendar() async {
    _isAddingToCalendar = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('Adding event ${_event.id} to calendar');
    } finally {
      _isAddingToCalendar = false;
      notifyListeners();
    }
  }
}