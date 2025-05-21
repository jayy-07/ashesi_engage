import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../viewmodels/mixins/offline_action_mixin.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  bool _wasOffline = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final List<OfflineActionMixin> _offlineCapableViewModels = [];

  bool get isOnline => _isOnline;
  bool get wasOffline => _wasOffline;

  void registerOfflineCapableViewModel(OfflineActionMixin viewModel) {
    if (!_offlineCapableViewModels.contains(viewModel)) {
      _offlineCapableViewModels.add(viewModel);
    }
  }

  void unregisterOfflineCapableViewModel(OfflineActionMixin viewModel) {
    _offlineCapableViewModels.remove(viewModel);
  }

  void _initialize() {
    if (!kIsWeb) {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
      // Check initial connection state
      _connectivity.checkConnectivity().then(_updateConnectionStatus);
    } else {
      // For web, we'll assume online by default and handle Firestore errors separately
      _isOnline = true;
      _wasOffline = false;
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    final wasOffline = !_isOnline;
    _isOnline = result != ConnectivityResult.none;
    _wasOffline = wasOffline;

    // If we're coming back online and we were offline before
    if (_isOnline && wasOffline) {
      await _syncPendingActions();
    }

    notifyListeners();
  }

  Future<void> _syncPendingActions() async {
    if (!_isOnline) return;

    for (final viewModel in _offlineCapableViewModels) {
      try {
        await viewModel.syncPendingActions();
      } catch (e) {
        debugPrint('Error syncing actions for viewModel: $e');
      }
    }
  }

  Future<void> retrySync() async {
    if (!_isOnline) return;
    await _syncPendingActions();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _offlineCapableViewModels.clear();
    super.dispose();
  }
} 