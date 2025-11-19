import 'package:json_annotation/json_annotation.dart';

part 'scan_status.g.dart';

/// Scan execution status enum
enum ScanStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('running')
  running,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
}

extension ScanStatusExtension on ScanStatus {
  String get displayName {
    switch (this) {
      case ScanStatus.pending:
        return 'Pending';
      case ScanStatus.running:
        return 'Running';
      case ScanStatus.completed:
        return 'Completed';
      case ScanStatus.failed:
        return 'Failed';
      case ScanStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => this == ScanStatus.pending || this == ScanStatus.running;
  bool get isCompleted => this == ScanStatus.completed;
  bool get isFailed => this == ScanStatus.failed;
  bool get isCancelled => this == ScanStatus.cancelled;
  bool get isFinished =>
      this == ScanStatus.completed ||
      this == ScanStatus.failed ||
      this == ScanStatus.cancelled;
}

/// Response when starting a scan
@JsonSerializable()
class ScanResponse {
  @JsonKey(name: 'scan_id')
  final String scanId;

  final ScanStatus status;

  final String message;

  @JsonKey(name: 'created_at')
  final String createdAt;

  const ScanResponse({
    required this.scanId,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory ScanResponse.fromJson(Map<String, dynamic> json) =>
      _$ScanResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ScanResponseToJson(this);
}

/// Detailed scan status information
@JsonSerializable()
class ScanStatusInfo {
  @JsonKey(name: 'scan_id')
  final String scanId;

  final ScanStatus status;

  final double progress;

  @JsonKey(name: 'current_probe')
  final String? currentProbe;

  @JsonKey(name: 'completed_probes')
  final int completedProbes;

  @JsonKey(name: 'total_probes')
  final int totalProbes;

  @JsonKey(name: 'current_iteration')
  final int currentIteration;

  @JsonKey(name: 'total_iterations')
  final int totalIterations;

  final int passed;

  final int failed;

  @JsonKey(name: 'elapsed_time')
  final String? elapsedTime;

  @JsonKey(name: 'estimated_remaining')
  final String? estimatedRemaining;

  @JsonKey(name: 'error_message')
  final String? errorMessage;

  const ScanStatusInfo({
    required this.scanId,
    required this.status,
    required this.progress,
    this.currentProbe,
    required this.completedProbes,
    required this.totalProbes,
    this.currentIteration = 0,
    this.totalIterations = 0,
    required this.passed,
    required this.failed,
    this.elapsedTime,
    this.estimatedRemaining,
    this.errorMessage,
  });

  factory ScanStatusInfo.fromJson(Map<String, dynamic> json) =>
      _$ScanStatusInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ScanStatusInfoToJson(this);

  ScanStatusInfo copyWith({
    String? scanId,
    ScanStatus? status,
    double? progress,
    String? currentProbe,
    int? completedProbes,
    int? totalProbes,
    int? currentIteration,
    int? totalIterations,
    int? passed,
    int? failed,
    String? elapsedTime,
    String? estimatedRemaining,
    String? errorMessage,
  }) {
    return ScanStatusInfo(
      scanId: scanId ?? this.scanId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentProbe: currentProbe ?? this.currentProbe,
      completedProbes: completedProbes ?? this.completedProbes,
      totalProbes: totalProbes ?? this.totalProbes,
      currentIteration: currentIteration ?? this.currentIteration,
      totalIterations: totalIterations ?? this.totalIterations,
      passed: passed ?? this.passed,
      failed: failed ?? this.failed,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      estimatedRemaining: estimatedRemaining ?? this.estimatedRemaining,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
