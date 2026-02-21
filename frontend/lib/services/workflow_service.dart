import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import '../models/workflow/workflow_graph.dart';

/// Service for communicating with the workflow API endpoints
class WorkflowService {
  late final Dio _dio;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final String baseUrl;
  final int connectionTimeout;
  final int receiveTimeout;

  WorkflowService({
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
          _logger.d('WORKFLOW REQUEST[${options.method}] => ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d(
            'WORKFLOW RESPONSE[${response.statusCode}] <= ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          _logger.e(
            'WORKFLOW ERROR[${error.response?.statusCode}] => ${error.requestOptions.path}',
          );
          return handler.next(error);
        },
      ),
    );
  }

  // ============================================================================
  // Workflow Operations
  // ============================================================================

  /// Get workflow graph for a scan
  Future<WorkflowGraph> getWorkflowGraph(String scanId) async {
    try {
      final response = await _dio.get('/scan/$scanId/workflow');
      return WorkflowGraph.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _logger.w('No workflow found for scan $scanId');
        throw WorkflowNotFoundException('No workflow found for scan $scanId');
      }
      _logger.e('Error getting workflow graph: ${e.message}');
      throw WorkflowException.fromDioException(e);
    }
  }

  /// Get workflow timeline for a scan
  Future<List<Map<String, dynamic>>> getWorkflowTimeline(String scanId) async {
    try {
      final response = await _dio.get('/scan/$scanId/workflow/timeline');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _logger.w('No workflow timeline found for scan $scanId');
        throw WorkflowNotFoundException(
          'No workflow timeline found for scan $scanId',
        );
      }
      _logger.e('Error getting workflow timeline: ${e.message}');
      throw WorkflowException.fromDioException(e);
    }
  }

  /// Export workflow in specified format
  Future<String> exportWorkflow(String scanId, String format) async {
    try {
      final response = await _dio.post(
        '/scan/$scanId/workflow/export',
        data: {'format': format},
      );
      return response.data['data'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _logger.w('No workflow found for scan $scanId');
        throw WorkflowNotFoundException('No workflow found for scan $scanId');
      }
      _logger.e('Error exporting workflow: ${e.message}');
      throw WorkflowException.fromDioException(e);
    }
  }

  /// Delete workflow data for a scan
  Future<void> deleteWorkflow(String scanId) async {
    try {
      await _dio.delete('/scan/$scanId/workflow');
      _logger.i('Workflow deleted for scan $scanId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _logger.w('No workflow found for scan $scanId');
        throw WorkflowNotFoundException('No workflow found for scan $scanId');
      }
      _logger.e('Error deleting workflow: ${e.message}');
      throw WorkflowException.fromDioException(e);
    }
  }

  /// Check if workflow exists for a scan
  Future<bool> hasWorkflow(String scanId) async {
    try {
      await _dio.get('/scan/$scanId/workflow');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      throw WorkflowException.fromDioException(e);
    }
  }
}

/// Custom exception for workflow errors
class WorkflowException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  WorkflowException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory WorkflowException.fromDioException(DioException error) {
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
    } else {
      message = error.message ?? 'Unknown error occurred';
    }

    return WorkflowException(
      message: message,
      statusCode: statusCode,
      data: error.response?.data,
    );
  }

  @override
  String toString() => message;
}

/// Exception for when workflow is not found
class WorkflowNotFoundException extends WorkflowException {
  WorkflowNotFoundException(String message)
      : super(message: message, statusCode: 404);
}
