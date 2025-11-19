import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_status.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'api_provider.dart';
import 'scan_config_provider.dart';

/// State for active scan
class ActiveScanState {
  final String? scanId;
  final ScanStatusInfo? status;
  final bool isLoading;
  final String? error;

  const ActiveScanState({
    this.scanId,
    this.status,
    this.isLoading = false,
    this.error,
  });

  ActiveScanState copyWith({
    String? scanId,
    ScanStatusInfo? status,
    bool? isLoading,
    String? error,
  }) {
    return ActiveScanState(
      scanId: scanId ?? this.scanId,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing active scan
class ActiveScanNotifier extends StateNotifier<ActiveScanState> {
  final ApiService _apiService;
  final WebSocketService _wsService;
  final Ref _ref;
  StreamSubscription<ScanStatusInfo>? _wsSubscription;

  ActiveScanNotifier(this._apiService, this._wsService, this._ref)
      : super(const ActiveScanState());

  /// Start a new scan
  Future<void> startScan() async {
    final config = _ref.read(scanConfigProvider);

    if (config == null) {
      state = state.copyWith(error: 'No configuration provided');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.startScan(config);
      state = state.copyWith(
        scanId: response.scanId,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start scan: $e',
      );
    }
  }

  /// Update scan status
  Future<void> updateStatus() async {
    if (state.scanId == null) return;

    try {
      final status = await _apiService.getScanStatus(state.scanId!);
      state = state.copyWith(status: status);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: 'Failed to get status: $e');
    }
  }

  /// Cancel the active scan
  Future<void> cancelScan() async {
    if (state.scanId == null) return;

    try {
      await _apiService.cancelScan(state.scanId!);
      state = const ActiveScanState();
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: 'Failed to cancel scan: $e');
    }
  }

  /// Connect to scan via WebSocket for real-time updates
  void connectWebSocket(String scanId) {
    // Cancel any existing subscription
    _wsSubscription?.cancel();

    // Connect to WebSocket
    final stream = _wsService.connectToScanProgress(scanId);

    _wsSubscription = stream.listen(
      (statusInfo) {
        // Only update state if notifier is still mounted
        if (mounted) {
          // Update state with real-time data
          state = state.copyWith(status: statusInfo);
        }
      },
      onError: (error) {
        // Only update state if notifier is still mounted
        if (mounted) {
          // Fall back to polling on WebSocket error
          state = state.copyWith(
            error: 'WebSocket error: $error. Using polling instead.',
          );
        }
      },
      cancelOnError: false,
    );
  }

  /// Disconnect WebSocket
  void disconnectWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsService.disconnect();
  }

  /// Reset scan state
  void reset() {
    disconnectWebSocket();
    state = const ActiveScanState();
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}

/// Provider for WebSocket service
final wsServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Provider for active scan
final activeScanProvider = StateNotifierProvider<ActiveScanNotifier, ActiveScanState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(wsServiceProvider);
  return ActiveScanNotifier(apiService, wsService, ref);
});

/// Provider for scan history
final scanHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getScanHistory();
});
