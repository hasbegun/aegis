import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import '../models/scan_config.dart';
import '../models/scan_status.dart';
import '../models/plugin.dart';
import '../models/system_info.dart';
import '../models/pagination.dart';

/// Service for communicating with the garak backend API
class ApiService {
  late final Dio _dio;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final String baseUrl;
  final int connectionTimeout;
  final int receiveTimeout;

  ApiService({
    this.baseUrl = AppConstants.apiBaseUrl,
    this.connectionTimeout = AppConstants.connectionTimeout,
    this.receiveTimeout = AppConstants.receiveTimeout,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: connectionTimeout),
        receiveTimeout: Duration(seconds: receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('REQUEST[${options.method}] => ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d(
            'RESPONSE[${response.statusCode}] <= ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          _logger.e(
            'ERROR[${error.response?.statusCode}] => ${error.requestOptions.path}',
          );
          return handler.next(error);
        },
      ),
    );
  }

  // ============================================================================
  // Scan Operations
  // ============================================================================

  /// Start a new vulnerability scan
  Future<ScanResponse> startScan(ScanConfig config) async {
    try {
      final response = await _dio.post(
        '/scan/start',
        data: config.toJson(),
      );

      return ScanResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error starting scan: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get current status of a scan
  Future<ScanStatusInfo> getScanStatus(String scanId) async {
    try {
      final response = await _dio.get('/scan/$scanId/status');
      return ScanStatusInfo.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error getting scan status: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Cancel a running scan
  Future<void> cancelScan(String scanId) async {
    try {
      await _dio.delete('/scan/$scanId/cancel');
    } on DioException catch (e) {
      _logger.e('Error cancelling scan: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get scan history (legacy - returns all scans)
  Future<List<Map<String, dynamic>>> getScanHistory() async {
    try {
      final response = await _dio.get('/scan/history');
      final scans = response.data['scans'] as List;
      return scans.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      _logger.e('Error getting scan history: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get paginated scan history
  Future<ScanHistoryResponse> getScanHistoryPaginated({
    int page = 1,
    int pageSize = 20,
    ScanSortField sortBy = ScanSortField.startedAt,
    SortOrder sortOrder = SortOrder.desc,
    String? status,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy.value,
        'sort_order': sortOrder.value,
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final response = await _dio.get(
        '/scan/history',
        queryParameters: queryParams,
      );

      return ScanHistoryResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error getting paginated scan history: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get detailed scan results
  Future<Map<String, dynamic>> getScanResults(String scanId) async {
    try {
      final response = await _dio.get('/scan/$scanId/results');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('Error getting scan results: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get detailed JSONL report for a scan
  Future<Map<String, dynamic>> getDetailedReport(String scanId) async {
    try {
      final response = await _dio.get('/scan/$scanId/report/detailed');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('Error getting detailed report: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Delete a scan and its reports
  Future<void> deleteScan(String scanId) async {
    try {
      await _dio.delete('/scan/$scanId');
      _logger.i('Scan $scanId deleted successfully');
    } on DioException catch (e) {
      _logger.e('Error deleting scan: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  // ============================================================================
  // Plugin Discovery
  // ============================================================================

  /// List available generator plugins
  Future<PluginListResponse> listGenerators() async {
    try {
      final response = await _dio.get('/plugins/generators');
      return PluginListResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error listing generators: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// List available probe plugins
  Future<PluginListResponse> listProbes() async {
    try {
      final response = await _dio.get('/plugins/probes');
      return PluginListResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error listing probes: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// List available detector plugins
  Future<PluginListResponse> listDetectors() async {
    try {
      final response = await _dio.get('/plugins/detectors');
      return PluginListResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error listing detectors: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// List available buff plugins
  Future<PluginListResponse> listBuffs() async {
    try {
      final response = await _dio.get('/plugins/buffs');
      return PluginListResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error listing buffs: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Validate an API key for a specific provider
  Future<ApiKeyValidationResult> validateApiKey(String provider, String apiKey) async {
    try {
      final response = await _dio.post(
        '/models/validate-api-key',
        data: {
          'provider': provider,
          'api_key': apiKey,
        },
      );
      return ApiKeyValidationResult.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error validating API key: ${e.message}');
      // Return invalid result instead of throwing
      return ApiKeyValidationResult(
        valid: false,
        provider: provider,
        message: 'Validation failed: ${e.message}',
      );
    }
  }

  /// Get detailed information about a specific plugin
  Future<Map<String, dynamic>> getPluginInfo(
    String pluginType,
    String pluginName,
  ) async {
    try {
      final response = await _dio.get('/plugins/$pluginType/$pluginName/info');
      return response.data;
    } on DioException catch (e) {
      _logger.e('Error getting plugin info: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  // ============================================================================
  // Configuration
  // ============================================================================

  /// List available configuration presets
  Future<List<Map<String, dynamic>>> listPresets() async {
    try {
      final response = await _dio.get('/config/presets');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      _logger.e('Error listing presets: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get a specific configuration preset
  Future<Map<String, dynamic>> getPreset(String presetName) async {
    try {
      final response = await _dio.get('/config/presets/$presetName');
      return response.data;
    } on DioException catch (e) {
      _logger.e('Error getting preset: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Validate a configuration
  Future<Map<String, dynamic>> validateConfig(
    Map<String, dynamic> config,
  ) async {
    try {
      final response = await _dio.post('/config/validate', data: config);
      return response.data;
    } on DioException catch (e) {
      _logger.e('Error validating config: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  // ============================================================================
  // System
  // ============================================================================

  /// Get system information
  Future<SystemInfo> getSystemInfo() async {
    try {
      final response = await _dio.get('/system/info');
      return SystemInfo.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error getting system info: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Check backend health
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get('/system/health');
      return response.data;
    } on DioException catch (e) {
      _logger.e('Error checking health: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  // ============================================================================
  // Probe Details
  // ============================================================================

  /// Get per-probe breakdown with security context
  Future<Map<String, dynamic>> getProbeDetails(
    String scanId, {
    int page = 1,
    int pageSize = 50,
    String? probeFilter,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (probeFilter != null && probeFilter.isNotEmpty) {
        queryParams['probe_filter'] = probeFilter;
      }
      final response = await _dio.get(
        '/scan/$scanId/probes',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('Error getting probe details: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get individual test attempts for a specific probe
  Future<Map<String, dynamic>> getProbeAttempts(
    String scanId,
    String probeClassname, {
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      final response = await _dio.get(
        '/scan/$scanId/probes/$probeClassname/attempts',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('Error getting probe attempts: ${e.message}');
      throw ApiException.fromDioException(e);
    }
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioException(DioException error) {
    String message = 'An error occurred';
    int? statusCode = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout. Please check your network connection.';
    } else if (error.type == DioExceptionType.badResponse) {
      message = error.response?.data['detail'] ??
          'Server error: ${error.response?.statusCode}';
    } else if (error.type == DioExceptionType.cancel) {
      message = 'Request cancelled';
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'Connection refused. Is the backend running?';
    } else {
      message = error.message ?? 'Unknown error occurred';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      data: error.response?.data,
    );
  }

  @override
  String toString() => message;
}

/// Result of API key validation
class ApiKeyValidationResult {
  final bool valid;
  final String provider;
  final String message;
  final Map<String, dynamic>? details;

  ApiKeyValidationResult({
    required this.valid,
    required this.provider,
    required this.message,
    this.details,
  });

  factory ApiKeyValidationResult.fromJson(Map<String, dynamic> json) {
    return ApiKeyValidationResult(
      valid: json['valid'] as bool,
      provider: json['provider'] as String,
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}
