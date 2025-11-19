// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanResponse _$ScanResponseFromJson(Map<String, dynamic> json) => ScanResponse(
      scanId: json['scan_id'] as String,
      status: $enumDecode(_$ScanStatusEnumMap, json['status']),
      message: json['message'] as String,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$ScanResponseToJson(ScanResponse instance) =>
    <String, dynamic>{
      'scan_id': instance.scanId,
      'status': _$ScanStatusEnumMap[instance.status]!,
      'message': instance.message,
      'created_at': instance.createdAt,
    };

const _$ScanStatusEnumMap = {
  ScanStatus.pending: 'pending',
  ScanStatus.running: 'running',
  ScanStatus.completed: 'completed',
  ScanStatus.failed: 'failed',
  ScanStatus.cancelled: 'cancelled',
};

ScanStatusInfo _$ScanStatusInfoFromJson(Map<String, dynamic> json) =>
    ScanStatusInfo(
      scanId: json['scan_id'] as String,
      status: $enumDecode(_$ScanStatusEnumMap, json['status']),
      progress: (json['progress'] as num).toDouble(),
      currentProbe: json['current_probe'] as String?,
      completedProbes: (json['completed_probes'] as num).toInt(),
      totalProbes: (json['total_probes'] as num).toInt(),
      currentIteration: (json['current_iteration'] as num?)?.toInt() ?? 0,
      totalIterations: (json['total_iterations'] as num?)?.toInt() ?? 0,
      passed: (json['passed'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      elapsedTime: json['elapsed_time'] as String?,
      estimatedRemaining: json['estimated_remaining'] as String?,
      errorMessage: json['error_message'] as String?,
    );

Map<String, dynamic> _$ScanStatusInfoToJson(ScanStatusInfo instance) =>
    <String, dynamic>{
      'scan_id': instance.scanId,
      'status': _$ScanStatusEnumMap[instance.status]!,
      'progress': instance.progress,
      'current_probe': instance.currentProbe,
      'completed_probes': instance.completedProbes,
      'total_probes': instance.totalProbes,
      'current_iteration': instance.currentIteration,
      'total_iterations': instance.totalIterations,
      'passed': instance.passed,
      'failed': instance.failed,
      'elapsed_time': instance.elapsedTime,
      'estimated_remaining': instance.estimatedRemaining,
      'error_message': instance.errorMessage,
    };
