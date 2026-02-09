import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../models/persisted_scan.dart';
import '../models/scan_config.dart';
import '../models/scan_status.dart';
import 'background_scan_service.dart';

/// Service for persisting background scans to local storage
class ScanPersistenceService {
  static const String _boxName = 'background_scans';
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  Box<PersistedScan>? _box;

  /// Initialize Hive and open box
  Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PersistedScanAdapter());
      }

      _box = await Hive.openBox<PersistedScan>(_boxName);
      _logger.i('Scan persistence initialized with ${_box!.length} stored scans');
    } catch (e) {
      _logger.e('Failed to initialize scan persistence: $e');
    }
  }

  /// Save a background scan
  Future<void> saveScan(BackgroundScan scan, ScanConfig config) async {
    if (_box == null) {
      _logger.w('Box not initialized, cannot save scan');
      return;
    }

    try {
      final persisted = PersistedScan(
        scanId: scan.scanId,
        scanName: scan.scanName,
        startTime: scan.startTime,
        targetType: config.targetType,
        targetName: config.targetName,
        probes: config.probes,
        generations: config.generations,
        evalThreshold: config.evalThreshold,
        lastStatus: scan.status?.status.toString(),
        lastProgress: scan.progress,
        lastUpdate: DateTime.now(),
      );

      await _box!.put(scan.scanId, persisted);
      _logger.d('Saved scan ${scan.scanId} to storage');
    } catch (e) {
      _logger.e('Failed to save scan ${scan.scanId}: $e');
    }
  }

  /// Update scan status
  Future<void> updateScan(String scanId, ScanStatusInfo status) async {
    if (_box == null) return;

    try {
      final persisted = _box!.get(scanId);
      if (persisted != null) {
        persisted.updateStatus(status.status.toString(), status.progress);
        _logger.d('Updated scan $scanId in storage');
      }
    } catch (e) {
      _logger.e('Failed to update scan $scanId: $e');
    }
  }

  /// Remove a scan from storage
  Future<void> removeScan(String scanId) async {
    if (_box == null) return;

    try {
      await _box!.delete(scanId);
      _logger.d('Removed scan $scanId from storage');
    } catch (e) {
      _logger.e('Failed to remove scan $scanId: $e');
    }
  }

  /// Get all persisted scans
  List<PersistedScan> getAllScans() {
    if (_box == null) return [];

    try {
      return _box!.values.toList();
    } catch (e) {
      _logger.e('Failed to get all scans: $e');
      return [];
    }
  }

  /// Get specific scan
  PersistedScan? getScan(String scanId) {
    if (_box == null) return null;

    try {
      return _box!.get(scanId);
    } catch (e) {
      _logger.e('Failed to get scan $scanId: $e');
      return null;
    }
  }

  /// Clear all scans
  Future<void> clearAll() async {
    if (_box == null) return;

    try {
      await _box!.clear();
      _logger.i('Cleared all persisted scans');
    } catch (e) {
      _logger.e('Failed to clear scans: $e');
    }
  }

  /// Clean up old completed/failed scans
  Future<void> cleanupOldScans({Duration maxAge = const Duration(days: 7)}) async {
    if (_box == null) return;

    try {
      final now = DateTime.now();
      final toRemove = <String>[];

      for (final scan in _box!.values) {
        // Remove if older than maxAge and completed/failed
        if (scan.lastUpdate != null &&
            now.difference(scan.lastUpdate!) > maxAge &&
            (scan.lastStatus == 'completed' || scan.lastStatus == 'failed')) {
          toRemove.add(scan.scanId);
        }
      }

      for (final scanId in toRemove) {
        await _box!.delete(scanId);
      }

      if (toRemove.isNotEmpty) {
        _logger.i('Cleaned up ${toRemove.length} old scans');
      }
    } catch (e) {
      _logger.e('Failed to cleanup old scans: $e');
    }
  }

  /// Convert persisted scan to ScanConfig
  ScanConfig persistedToConfig(PersistedScan persisted) {
    return ScanConfig(
      targetType: persisted.targetType,
      targetName: persisted.targetName,
      probes: persisted.probes,
      generations: persisted.generations,
      evalThreshold: persisted.evalThreshold,
    );
  }

  /// Dispose
  Future<void> dispose() async {
    await _box?.close();
    _logger.d('Scan persistence disposed');
  }
}
