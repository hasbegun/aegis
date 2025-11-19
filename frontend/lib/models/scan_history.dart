import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'scan_history.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class ScanHistoryItem {
  @HiveField(0)
  final String scanId;

  @HiveField(1)
  final String targetType;

  @HiveField(2)
  final String targetName;

  @HiveField(3)
  final List<String> probes;

  @HiveField(4)
  final int passed;

  @HiveField(5)
  final int failed;

  @HiveField(6)
  final double passRate;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime? completedAt;

  @HiveField(10)
  final double? duration;

  @HiveField(11)
  final int generations;

  @HiveField(12)
  final double evalThreshold;

  @HiveField(13)
  final Map<String, dynamic>? fullResults;

  const ScanHistoryItem({
    required this.scanId,
    required this.targetType,
    required this.targetName,
    required this.probes,
    required this.passed,
    required this.failed,
    required this.passRate,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.duration,
    required this.generations,
    required this.evalThreshold,
    this.fullResults,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$ScanHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$ScanHistoryItemToJson(this);

  factory ScanHistoryItem.fromResults(Map<String, dynamic> results) {
    final scanResults = results['results'] ?? {};
    final summary = results['summary'] ?? {};
    final config = results['config'] ?? {};

    return ScanHistoryItem(
      scanId: results['scan_id'] ?? '',
      targetType: config['target_type'] ?? '',
      targetName: config['target_name'] ?? '',
      probes: (config['probes'] as List?)?.cast<String>() ?? [],
      passed: scanResults['passed'] ?? 0,
      failed: scanResults['failed'] ?? 0,
      passRate: summary['pass_rate'] ?? 0.0,
      status: summary['status'] ?? 'unknown',
      createdAt: DateTime.tryParse(results['created_at'] ?? '') ?? DateTime.now(),
      completedAt: results['completed_at'] != null
          ? DateTime.tryParse(results['completed_at'])
          : null,
      duration: results['duration']?.toDouble(),
      generations: config['generations'] ?? 0,
      evalThreshold: config['eval_threshold']?.toDouble() ?? 0.5,
      fullResults: results,
    );
  }

  int get totalTests => passed + failed;

  String get formattedDuration {
    if (duration == null) return 'N/A';
    final d = Duration(seconds: duration!.toInt());
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get statusEmoji {
    switch (status.toLowerCase()) {
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      case 'cancelled':
        return '🚫';
      case 'running':
        return '⏳';
      default:
        return '❓';
    }
  }
}
