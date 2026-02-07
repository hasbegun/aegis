import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity status enum
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// Connectivity state notifier that tracks network status
class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier() : super(ConnectivityStatus.unknown) {
    _init();
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Connectivity _connectivity = Connectivity();

  Future<void> _init() async {
    // Check initial connectivity
    await _checkConnectivity();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      state = ConnectivityStatus.unknown;
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      state = ConnectivityStatus.offline;
    } else {
      state = ConnectivityStatus.online;
    }
  }

  /// Manually refresh connectivity status
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for connectivity status
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  return ConnectivityNotifier();
});

/// Provider that returns true when offline
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider);
  return status == ConnectivityStatus.offline;
});

/// Provider that returns true when online
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider);
  return status == ConnectivityStatus.online;
});
