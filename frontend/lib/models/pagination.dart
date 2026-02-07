import 'package:json_annotation/json_annotation.dart';

part 'pagination.g.dart';

/// Pagination metadata returned from API
@JsonSerializable()
class PaginationMeta {
  final int page;

  @JsonKey(name: 'page_size')
  final int pageSize;

  @JsonKey(name: 'total_items')
  final int totalItems;

  @JsonKey(name: 'total_pages')
  final int totalPages;

  @JsonKey(name: 'has_next')
  final bool hasNext;

  @JsonKey(name: 'has_previous')
  final bool hasPrevious;

  const PaginationMeta({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) =>
      _$PaginationMetaFromJson(json);

  Map<String, dynamic> toJson() => _$PaginationMetaToJson(this);
}

/// Scan history item from paginated response
@JsonSerializable()
class ScanHistoryItem {
  @JsonKey(name: 'scan_id')
  final String scanId;

  final String status;

  @JsonKey(name: 'target_type')
  final String? targetType;

  @JsonKey(name: 'target_name')
  final String? targetName;

  @JsonKey(name: 'started_at')
  final String? startedAt;

  @JsonKey(name: 'completed_at')
  final String? completedAt;

  final int passed;
  final int failed;

  @JsonKey(name: 'total_tests')
  final int totalTests;

  final double progress;

  @JsonKey(name: 'html_report_path')
  final String? htmlReportPath;

  @JsonKey(name: 'jsonl_report_path')
  final String? jsonlReportPath;

  const ScanHistoryItem({
    required this.scanId,
    required this.status,
    this.targetType,
    this.targetName,
    this.startedAt,
    this.completedAt,
    this.passed = 0,
    this.failed = 0,
    this.totalTests = 0,
    this.progress = 0.0,
    this.htmlReportPath,
    this.jsonlReportPath,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$ScanHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$ScanHistoryItemToJson(this);

  /// Convert to Map for backward compatibility
  Map<String, dynamic> toMap() => {
    'scan_id': scanId,
    'status': status,
    'target_type': targetType,
    'target_name': targetName,
    'started_at': startedAt,
    'completed_at': completedAt,
    'passed': passed,
    'failed': failed,
    'total_tests': totalTests,
    'progress': progress,
    'html_report_path': htmlReportPath,
    'jsonl_report_path': jsonlReportPath,
  };
}

/// Paginated scan history response
@JsonSerializable()
class ScanHistoryResponse {
  final List<ScanHistoryItem> scans;
  final PaginationMeta pagination;

  @JsonKey(name: 'total_count')
  final int totalCount;

  const ScanHistoryResponse({
    required this.scans,
    required this.pagination,
    required this.totalCount,
  });

  factory ScanHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$ScanHistoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ScanHistoryResponseToJson(this);
}

/// Sort field options for scan history
enum ScanSortField {
  @JsonValue('started_at')
  startedAt,
  @JsonValue('completed_at')
  completedAt,
  @JsonValue('status')
  status,
  @JsonValue('target_name')
  targetName,
  @JsonValue('pass_rate')
  passRate,
}

extension ScanSortFieldExtension on ScanSortField {
  String get value {
    switch (this) {
      case ScanSortField.startedAt:
        return 'started_at';
      case ScanSortField.completedAt:
        return 'completed_at';
      case ScanSortField.status:
        return 'status';
      case ScanSortField.targetName:
        return 'target_name';
      case ScanSortField.passRate:
        return 'pass_rate';
    }
  }

  String get displayName {
    switch (this) {
      case ScanSortField.startedAt:
        return 'Date Started';
      case ScanSortField.completedAt:
        return 'Date Completed';
      case ScanSortField.status:
        return 'Status';
      case ScanSortField.targetName:
        return 'Model Name';
      case ScanSortField.passRate:
        return 'Pass Rate';
    }
  }
}

/// Sort order options
enum SortOrder {
  @JsonValue('asc')
  asc,
  @JsonValue('desc')
  desc,
}

extension SortOrderExtension on SortOrder {
  String get value {
    switch (this) {
      case SortOrder.asc:
        return 'asc';
      case SortOrder.desc:
        return 'desc';
    }
  }
}
