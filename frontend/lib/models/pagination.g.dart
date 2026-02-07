// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pagination.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginationMeta _$PaginationMetaFromJson(Map<String, dynamic> json) =>
    PaginationMeta(
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      totalItems: (json['total_items'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
      hasNext: json['has_next'] as bool,
      hasPrevious: json['has_previous'] as bool,
    );

Map<String, dynamic> _$PaginationMetaToJson(PaginationMeta instance) =>
    <String, dynamic>{
      'page': instance.page,
      'page_size': instance.pageSize,
      'total_items': instance.totalItems,
      'total_pages': instance.totalPages,
      'has_next': instance.hasNext,
      'has_previous': instance.hasPrevious,
    };

ScanHistoryItem _$ScanHistoryItemFromJson(Map<String, dynamic> json) =>
    ScanHistoryItem(
      scanId: json['scan_id'] as String,
      status: json['status'] as String,
      targetType: json['target_type'] as String?,
      targetName: json['target_name'] as String?,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      passed: (json['passed'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      totalTests: (json['total_tests'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      htmlReportPath: json['html_report_path'] as String?,
      jsonlReportPath: json['jsonl_report_path'] as String?,
    );

Map<String, dynamic> _$ScanHistoryItemToJson(ScanHistoryItem instance) =>
    <String, dynamic>{
      'scan_id': instance.scanId,
      'status': instance.status,
      'target_type': instance.targetType,
      'target_name': instance.targetName,
      'started_at': instance.startedAt,
      'completed_at': instance.completedAt,
      'passed': instance.passed,
      'failed': instance.failed,
      'total_tests': instance.totalTests,
      'progress': instance.progress,
      'html_report_path': instance.htmlReportPath,
      'jsonl_report_path': instance.jsonlReportPath,
    };

ScanHistoryResponse _$ScanHistoryResponseFromJson(Map<String, dynamic> json) =>
    ScanHistoryResponse(
      scans: (json['scans'] as List<dynamic>)
          .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          PaginationMeta.fromJson(json['pagination'] as Map<String, dynamic>),
      totalCount: (json['total_count'] as num).toInt(),
    );

Map<String, dynamic> _$ScanHistoryResponseToJson(
        ScanHistoryResponse instance) =>
    <String, dynamic>{
      'scans': instance.scans,
      'pagination': instance.pagination,
      'total_count': instance.totalCount,
    };
