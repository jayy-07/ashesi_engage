import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingAction {
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String id;

  PendingAction({
    required this.type,
    required this.data,
    required this.id,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'data': data,
      'createdAt': createdAt,
      'id': id,
    };
  }

  factory PendingAction.fromMap(Map<String, dynamic> map) {
    return PendingAction(
      type: map['type'],
      data: map['data'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      id: map['id'],
    );
  }
}

mixin OfflineActionMixin on ChangeNotifier {
  final List<PendingAction> _pendingActions = [];
  bool _isSyncing = false;

  List<PendingAction> get pendingActions => List.unmodifiable(_pendingActions);
  bool get isSyncing => _isSyncing;
  bool get hasPendingActions => _pendingActions.isNotEmpty;

  void addPendingAction(PendingAction action) {
    _pendingActions.add(action);
    notifyListeners();
  }

  void removePendingAction(String id) {
    _pendingActions.removeWhere((action) => action.id == id);
    notifyListeners();
  }

  Future<void> syncPendingActions() async {
    if (_isSyncing || _pendingActions.isEmpty) return;

    try {
      _isSyncing = true;
      notifyListeners();

      // Process each pending action
      for (final action in List.from(_pendingActions)) {
        try {
          await processPendingAction(action);
          removePendingAction(action.id);
        } catch (e) {
          debugPrint('Error processing action ${action.id}: $e');
          // Keep the action in the queue if it fails
          continue;
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // This method should be implemented by the class using the mixin
  Future<void> processPendingAction(PendingAction action);
} 