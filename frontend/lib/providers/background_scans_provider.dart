import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/background_scan_service.dart';
import '../services/scan_persistence_service.dart';
import '../services/scan_notification_service.dart';
import '../models/scan_config.dart';
import '../models/scan_status.dart';
import 'api_provider.dart';
import 'scan_provider.dart';
import 'scan_config_provider.dart';

/// Provider for scan persistence service
final scanPersistenceServiceProvider = Provider<ScanPersistenceService>((ref) {
  final service = ScanPersistenceService();

  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for scan notification service
final scanNotificationServiceProvider = Provider<ScanNotificationService>((ref) {
  final service = ScanNotificationService();

  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for background scan service
final backgroundScanServiceProvider = Provider<BackgroundScanService>((ref) {
  final wsService = ref.watch(wsServiceProvider);
  final apiService = ref.watch(apiServiceProvider);
  final persistenceService = ref.watch(scanPersistenceServiceProvider);
  final notificationService = ref.watch(scanNotificationServiceProvider);

  final service = BackgroundScanService(
    wsService,
    apiService,
    persistenceService,
    notificationService,
  );

  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for list of background scans
final backgroundScansProvider = StreamProvider<List<BackgroundScan>>((ref) {
  final service = ref.watch(backgroundScanServiceProvider);
  return service.scansStream;
});

/// Provider for background scan count
final backgroundScanCountProvider = Provider<int>((ref) {
  final scansAsync = ref.watch(backgroundScansProvider);
  return scansAsync.maybeWhen(
    data: (scans) => scans.length,
    orElse: () => 0,
  );
});

/// Provider for active (running) background scan count
final activeBackgroundScanCountProvider = Provider<int>((ref) {
  final scansAsync = ref.watch(backgroundScansProvider);
  return scansAsync.maybeWhen(
    data: (scans) => scans.where((s) => s.isActive).length,
    orElse: () => 0,
  );
});

/// Provider for checking if specific scan is in background
final isScanInBackgroundProvider = Provider.family<bool, String>((ref, scanId) {
  final service = ref.watch(backgroundScanServiceProvider);
  return service.isInBackground(scanId);
});

/// Notifier for background scan actions
class BackgroundScanActions {
  final Ref _ref;

  BackgroundScanActions(this._ref);

  /// Move current active scan to background
  void moveCurrentScanToBackground() {
    final activeScan = _ref.read(activeScanProvider);
    final config = _ref.read(scanConfigProvider);

    if (activeScan.scanId != null && config != null) {
      final service = _ref.read(backgroundScanServiceProvider);

      service.moveToBackground(
        scanId: activeScan.scanId!,
        config: config,
        currentStatus: activeScan.status,
      );

      // Don't disconnect WebSocket - it's now managed by background service
      // Just reset the active scan provider
      _ref.read(activeScanProvider.notifier).reset();
    }
  }

  /// Move specific scan to background
  void moveScanToBackground({
    required String scanId,
    required ScanConfig config,
    ScanStatusInfo? currentStatus,
  }) {
    final service = _ref.read(backgroundScanServiceProvider);
    service.moveToBackground(
      scanId: scanId,
      config: config,
      currentStatus: currentStatus,
    );
  }

  /// Remove scan from background (resume viewing)
  void resumeScan(String scanId) {
    final service = _ref.read(backgroundScanServiceProvider);
    final scan = service.getScan(scanId);

    if (scan != null) {
      // Transfer ownership back to active scan provider
      final activeScanNotifier = _ref.read(activeScanProvider.notifier);

      // Remove from background (this will dispose the WebSocket)
      service.removeFromBackground(scanId);

      // Resume in active scan provider with current state
      activeScanNotifier.resumeWithState(scanId, scan.status);

      // Also set the scan config so it's available in the execution screen
      _ref.read(scanConfigProvider.notifier).setConfig(scan.config);
    }
  }

  /// Cancel specific background scan
  Future<void> cancelScan(String scanId) async {
    final service = _ref.read(backgroundScanServiceProvider);
    await service.cancelBackgroundScan(scanId);
  }

  /// Cancel all background scans
  Future<void> cancelAllScans() async {
    final service = _ref.read(backgroundScanServiceProvider);
    await service.cancelAllScans();
  }
}

/// Provider for background scan actions
final backgroundScanActionsProvider = Provider<BackgroundScanActions>((ref) {
  return BackgroundScanActions(ref);
});
