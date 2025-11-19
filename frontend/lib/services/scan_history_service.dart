import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_history.dart';

/// Service for managing scan history using Hive local storage
class ScanHistoryService {
  static const String _boxName = 'scan_history';
  Box<ScanHistoryItem>? _box;

  /// Initialize Hive and open the box
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ScanHistoryItemAdapter());
    }

    _box = await Hive.openBox<ScanHistoryItem>(_boxName);
  }

  /// Save a scan to history
  Future<void> saveScan(ScanHistoryItem scan) async {
    await _ensureInitialized();
    await _box!.put(scan.scanId, scan);
  }

  /// Get a specific scan from history
  ScanHistoryItem? getScan(String scanId) {
    return _box?.get(scanId);
  }

  /// Get all scans from history
  List<ScanHistoryItem> getAllScans() {
    if (_box == null) return [];
    return _box!.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  /// Get scans filtered by status
  List<ScanHistoryItem> getScansByStatus(String status) {
    return getAllScans()
        .where((scan) => scan.status.toLowerCase() == status.toLowerCase())
        .toList();
  }

  /// Get scans filtered by target type
  List<ScanHistoryItem> getScansByTargetType(String targetType) {
    return getAllScans()
        .where((scan) =>
            scan.targetType.toLowerCase() == targetType.toLowerCase())
        .toList();
  }

  /// Search scans by query (searches target name, type, probes)
  List<ScanHistoryItem> searchScans(String query) {
    if (query.isEmpty) return getAllScans();

    final lowerQuery = query.toLowerCase();
    return getAllScans().where((scan) {
      return scan.targetType.toLowerCase().contains(lowerQuery) ||
          scan.targetName.toLowerCase().contains(lowerQuery) ||
          scan.probes.any((probe) => probe.toLowerCase().contains(lowerQuery)) ||
          scan.scanId.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get scans within a date range
  List<ScanHistoryItem> getScansByDateRange(DateTime start, DateTime end) {
    return getAllScans()
        .where((scan) =>
            scan.createdAt.isAfter(start) && scan.createdAt.isBefore(end))
        .toList();
  }

  /// Delete a scan from history
  Future<void> deleteScan(String scanId) async {
    await _ensureInitialized();
    await _box!.delete(scanId);
  }

  /// Clear all scan history
  Future<void> clearHistory() async {
    await _ensureInitialized();
    await _box!.clear();
  }

  /// Get total number of scans
  int get totalScans => _box?.length ?? 0;

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    final scans = getAllScans();
    if (scans.isEmpty) {
      return {
        'totalScans': 0,
        'completedScans': 0,
        'failedScans': 0,
        'totalTests': 0,
        'totalPassed': 0,
        'totalFailed': 0,
        'averagePassRate': 0.0,
      };
    }

    final completed = scans.where((s) => s.status == 'completed').length;
    final failed = scans.where((s) => s.status == 'failed').length;
    final totalTests = scans.fold<int>(0, (sum, scan) => sum + scan.totalTests);
    final totalPassed = scans.fold<int>(0, (sum, scan) => sum + scan.passed);
    final totalFailed = scans.fold<int>(0, (sum, scan) => sum + scan.failed);
    final avgPassRate = scans.isEmpty
        ? 0.0
        : scans.fold<double>(0.0, (sum, scan) => sum + scan.passRate) /
            scans.length;

    return {
      'totalScans': scans.length,
      'completedScans': completed,
      'failedScans': failed,
      'totalTests': totalTests,
      'totalPassed': totalPassed,
      'totalFailed': totalFailed,
      'averagePassRate': avgPassRate,
    };
  }

  Future<void> _ensureInitialized() async {
    if (_box == null) {
      await init();
    }
  }

  /// Close the box
  Future<void> close() async {
    await _box?.close();
  }
}
