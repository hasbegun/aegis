import 'package:dio/dio.dart';
import '../models/custom_probe.dart';

class CustomProbeService {
  final Dio _dio;

  CustomProbeService(this._dio);

  /// Get a probe template
  Future<String> getTemplate(ProbeTemplate template) async {
    try {
      final response = await _dio.get(
        '/probes/custom/templates/${template.name}',
      );
      return response.data['template'] as String;
    } catch (e) {
      throw Exception('Failed to get template: $e');
    }
  }

  /// Validate probe code
  Future<ProbeValidationResult> validateCode(String code) async {
    try {
      final response = await _dio.post(
        '/probes/custom/validate',
        data: {'code': code},
      );
      return ProbeValidationResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to validate code: $e');
    }
  }

  /// Create a new custom probe
  Future<CustomProbe> createProbe({
    required String name,
    required String code,
    String? description,
  }) async {
    try {
      final response = await _dio.post(
        '/probes/custom',
        data: {
          'name': name,
          'code': code,
          if (description != null) 'description': description,
        },
      );
      return CustomProbe.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw Exception(e.response?.data['detail'] ?? 'Failed to create probe');
      }
      throw Exception('Failed to create probe: $e');
    }
  }

  /// List all custom probes
  Future<List<CustomProbe>> listProbes() async {
    try {
      final response = await _dio.get(
        '/probes/custom',
      );
      final data = response.data as Map<String, dynamic>;
      final probes = (data['probes'] as List<dynamic>)
          .map((e) => CustomProbe.fromJson(e as Map<String, dynamic>))
          .toList();
      return probes;
    } catch (e) {
      throw Exception('Failed to list probes: $e');
    }
  }

  /// Get a specific custom probe with code
  Future<CustomProbeWithCode> getProbe(String name) async {
    try {
      final response = await _dio.get(
        '/probes/custom/$name',
      );
      return CustomProbeWithCode.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw Exception('Probe not found');
      }
      throw Exception('Failed to get probe: $e');
    }
  }

  /// Update an existing custom probe
  Future<CustomProbe> updateProbe({
    required String name,
    required String code,
    String? description,
  }) async {
    try {
      final response = await _dio.put(
        '/probes/custom/$name',
        data: {
          'name': name,
          'code': code,
          if (description != null) 'description': description,
        },
      );
      return CustomProbe.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw Exception(e.response?.data['detail'] ?? 'Failed to update probe');
      }
      throw Exception('Failed to update probe: $e');
    }
  }

  /// Delete a custom probe
  Future<void> deleteProbe(String name) async {
    try {
      await _dio.delete(
        '/probes/custom/$name',
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw Exception('Probe not found');
      }
      throw Exception('Failed to delete probe: $e');
    }
  }
}
