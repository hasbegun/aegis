import 'dart:async';
import 'package:logger/logger.dart';
import '../models/scan_status.dart';
import '../models/scan_config.dart';
import 'websocket_service.dart';
import 'api_service.dart';
import 'scan_persistence_service.dart';
import 'scan_notification_service.dart';

/// Represents a scan running in the background
class BackgroundScan {
  final String scanId;
  final String scanName;
  final DateTime startTime;
  final ScanConfig config;
  ScanStatusInfo? status;
  StreamSubscription<ScanStatusInfo>? wsSubscription;

  BackgroundScan({
    required this.scanId,
    required this.scanName,
    required this.startTime,
    required this.config,
    this.status,
    this.wsSubscription,
  });

  /// Check if scan is still active
  bool get isActive => status?.status.isActive ?? false;

  /// Check if scan is completed
  bool get isCompleted => status?.status == ScanStatus.completed;

  /// Check if scan has error
  bool get hasError => status?.status == ScanStatus.failed;

  /// Get progress percentage
  double? get progress => status?.progress;

  /// Get display name for the scan
  String get displayName {
    if (scanName.isNotEmpty) return scanName;
    return 'Scan ${scanId.substring(0, 8)}';
  }

  /// Clean up resources
  void dispose() {
    wsSubscription?.cancel();
    wsSubscription = null;
  }
}

/// Service for managing background scans
class BackgroundScanService {
  final WebSocketService _wsService;
  final ApiService _apiService;
  final ScanPersistenceService _persistenceService;
  final ScanNotificationService _notificationService;
  final Logger _logger = Logger();

  // Track all background scans
  final Map<String, BackgroundScan> _activeScans = {};

  // Stream controller for scan updates
  final _scansController = StreamController<List<BackgroundScan>>.broadcast();

  BackgroundScanService(
    this._wsService,
    this._apiService,
    this._persistenceService,
    this._notificationService,
  );

  /// Get stream of background scans
  Stream<List<BackgroundScan>> get scansStream => _scansController.stream;

  /// Get all background scans
  List<BackgroundScan> getActiveScans() {
    return _activeScans.values.toList();
  }

  /// Get specific background scan
  BackgroundScan? getScan(String scanId) {
    return _activeScans[scanId];
  }

  /// Check if scan is in background
  bool isInBackground(String scanId) {
    return _activeScans.containsKey(scanId);
  }

  /// Add scan to background
  void moveToBackground({
    required String scanId,
    required ScanConfig config,
    ScanStatusInfo? currentStatus,
  }) {
    if (_activeScans.containsKey(scanId)) {
      _logger.w('Scan $scanId already in background');
      return;
    }

    _logger.i('Moving scan $scanId to background');

    // Create background scan
    final scan = BackgroundScan(
      scanId: scanId,
      scanName: _generateScanName(config),
      startTime: DateTime.now(),
      config: config,
      status: currentStatus,
    );

    // Connect WebSocket for real-time updates
    _connectWebSocket(scan);

    // Add to active scans
    _activeScans[scanId] = scan;

    // Save to persistence
    _persistenceService.saveScan(scan, config);

    // Notify listeners
    _notifyListeners();
  }

  /// Generate friendly scan name from config
  String _generateScanName(ScanConfig config) {
    final modelName = config.targetName;
    final generatorType = config.targetType;
    return '$generatorType - $modelName';
  }

  /// Connect WebSocket for a background scan
  void _connectWebSocket(BackgroundScan scan) {
    try {
      final stream = _wsService.connectToScanProgress(scan.scanId);

      scan.wsSubscription = stream.listen(
        (statusInfo) {
          _logger.d('Received status update for scan ${scan.scanId}: progress=${statusInfo.progress}%, status=${statusInfo.status}');

          // Update scan status
          scan.status = statusInfo;

          // Update persistence
          _persistenceService.updateScan(scan.scanId, statusInfo);

          // If scan completed or failed, show notification and dispose WebSocket
          if (statusInfo.status == ScanStatus.completed) {
            _logger.i('Background scan ${scan.scanId} completed');
            _notificationService.showCompletionNotification(
              scanId: scan.scanId,
              scanName: scan.scanName,
              success: true,
            );
            // Dispose WebSocket but keep scan in list for history
            scan.dispose();
          } else if (statusInfo.status == ScanStatus.failed) {
            _logger.i('Background scan ${scan.scanId} failed');
            _notificationService.showErrorNotification(
              scanId: scan.scanId,
              scanName: scan.scanName,
              errorMessage: 'Scan failed - tap to view details',
            );
            // Dispose WebSocket but keep scan in list for history
            scan.dispose();
          }

          // Notify listeners of update
          _notifyListeners();

          // Schedule cleanup of old completed/failed scans
          if (statusInfo.status == ScanStatus.completed ||
              statusInfo.status == ScanStatus.failed) {
            _scheduleHistoryCleanup();
          }
        },
        onError: (error) {
          _logger.e('WebSocket error for scan ${scan.scanId}: $error');
          // Fall back to polling
          _startPolling(scan);
        },
        cancelOnError: false,
      );
    } catch (e) {
      _logger.e('Failed to connect WebSocket for scan ${scan.scanId}: $e');
      _startPolling(scan);
    }
  }

  /// Start polling for scan status (fallback when WebSocket fails)
  void _startPolling(BackgroundScan scan) {
    // Poll every 3 seconds
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_activeScans.containsKey(scan.scanId)) {
        timer.cancel();
        return;
      }

      try {
        final status = await _apiService.getScanStatus(scan.scanId);
        scan.status = status;

        // Update persistence
        _persistenceService.updateScan(scan.scanId, status);

        if (status.status == ScanStatus.completed ||
            status.status == ScanStatus.failed) {
          timer.cancel();

          // Show notification
          if (status.status == ScanStatus.completed) {
            _notificationService.showCompletionNotification(
              scanId: scan.scanId,
              scanName: scan.scanName,
              success: true,
            );
          } else {
            _notificationService.showErrorNotification(
              scanId: scan.scanId,
              scanName: scan.scanName,
            );
          }

          // Schedule cleanup of old completed/failed scans
          _scheduleHistoryCleanup();
        }

        _notifyListeners();
      } catch (e) {
        _logger.e('Failed to poll status for scan ${scan.scanId}: $e');
      }
    });
  }

  /// Remove scan from background (without canceling it)
  void removeFromBackground(String scanId) {
    final scan = _activeScans.remove(scanId);
    if (scan != null) {
      _logger.i('Removing scan $scanId from background');
      scan.dispose();

      // Remove from persistence
      _persistenceService.removeScan(scanId);

      // Cancel notification
      _notificationService.cancelNotification(scanId);

      _notifyListeners();
    }
  }

  /// Cancel specific background scan
  Future<void> cancelBackgroundScan(String scanId) async {
    final scan = _activeScans[scanId];
    if (scan == null) return;

    try {
      _logger.i('Canceling background scan $scanId');
      await _apiService.cancelScan(scanId);
      removeFromBackground(scanId);

      // Cancel notification
      _notificationService.cancelNotification(scanId);
    } catch (e) {
      _logger.e('Failed to cancel scan $scanId: $e');
      throw Exception('Failed to cancel scan: $e');
    }
  }

  /// Cancel all background scans
  Future<void> cancelAllScans() async {
    final scanIds = _activeScans.keys.toList();

    for (final scanId in scanIds) {
      try {
        await cancelBackgroundScan(scanId);
      } catch (e) {
        _logger.e('Failed to cancel scan $scanId: $e');
      }
    }
  }

  /// Get count of active scans
  int get activeCount => _activeScans.length;

  /// Get count of running scans
  int get runningCount =>
      _activeScans.values.where((s) => s.isActive).length;

  /// Get count of completed scans
  int get completedCount =>
      _activeScans.values.where((s) => s.isCompleted).length;

  /// Notify all listeners
  void _notifyListeners() {
    if (!_scansController.isClosed) {
      _scansController.add(getActiveScans());
    }
  }

  /// Restore scans from persistence
  Future<void> restoreScans() async {
    try {
      final persistedScans = _persistenceService.getAllScans();
      _logger.i('Found ${persistedScans.length} persisted scans to restore');

      for (final persisted in persistedScans) {
        // Check if scan is still active on backend
        try {
          final status = await _apiService.getScanStatus(persisted.scanId);

          // Only restore if still running
          if (status.status.isActive) {
            final config = _persistenceService.persistedToConfig(persisted);

            final scan = BackgroundScan(
              scanId: persisted.scanId,
              scanName: persisted.scanName,
              startTime: persisted.startTime,
              config: config,
              status: status,
            );

            // Connect WebSocket for real-time updates
            _connectWebSocket(scan);

            // Add to active scans
            _activeScans[persisted.scanId] = scan;

            _logger.i('Restored scan ${persisted.scanId}');
          } else {
            // Scan completed/failed while app was closed
            _logger.i('Scan ${persisted.scanId} is no longer active, removing');
            _persistenceService.removeScan(persisted.scanId);

            // Show completion notification
            if (status.status == ScanStatus.completed) {
              _notificationService.showCompletionNotification(
                scanId: persisted.scanId,
                scanName: persisted.scanName,
                success: true,
              );
            }
          }
        } catch (e) {
          _logger.w('Failed to restore scan ${persisted.scanId}: $e');
          // Remove failed restore
          _persistenceService.removeScan(persisted.scanId);
        }
      }

      if (_activeScans.isNotEmpty) {
        _notifyListeners();
      }

      // Cleanup old scans
      await _persistenceService.cleanupOldScans();
    } catch (e) {
      _logger.e('Failed to restore scans: $e');
    }
  }

  /// Schedule cleanup of old completed/failed scans
  void _scheduleHistoryCleanup() {
    // Clean up scans that have been completed/failed for more than 24 hours
    Future.delayed(const Duration(seconds: 5), () {
      _cleanupOldHistory();
    });
  }

  /// Clean up old completed/failed scans from memory
  void _cleanupOldHistory() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _activeScans.entries) {
      final scan = entry.value;
      // Remove completed/failed scans older than 24 hours
      if ((scan.isCompleted || scan.hasError)) {
        final scanDuration = now.difference(scan.startTime);
        if (scanDuration.inHours >= 24) {
          toRemove.add(entry.key);
        }
      }
    }

    for (final scanId in toRemove) {
      _logger.d('Removing old scan $scanId from history');
      final scan = _activeScans.remove(scanId);
      scan?.dispose();
      _persistenceService.removeScan(scanId);
    }

    if (toRemove.isNotEmpty) {
      _notifyListeners();
    }
  }

  /// Manually trigger cleanup of old scans
  void cleanupHistory() {
    _cleanupOldHistory();
  }

  /// Dispose service
  void dispose() {
    // Clean up all scans
    for (final scan in _activeScans.values) {
      scan.dispose();
    }
    _activeScans.clear();

    // Close stream
    _scansController.close();
  }
}
