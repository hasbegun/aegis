import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../models/generator_model.dart';
import 'package:logger/logger.dart';

/// Service for fetching available models for each generator type
class ModelsService {
  final Dio _dio;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // Cache for model lists to avoid repeated API calls
  final Map<String, GeneratorModelsResponse> _cache = {};

  ModelsService(this._dio);

  /// Fetch available models for a specific generator type
  Future<GeneratorModelsResponse> getModelsForGenerator(String generatorType) async {
    // Check cache first
    if (_cache.containsKey(generatorType)) {
      _logger.d('Returning cached models for $generatorType');
      return _cache[generatorType]!;
    }

    try {
      _logger.d('Fetching models for generator: $generatorType');

      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/generators/$generatorType/models',
      );

      if (response.statusCode == 200) {
        final modelsResponse = GeneratorModelsResponse.fromJson(response.data);

        // Cache the response
        _cache[generatorType] = modelsResponse;

        _logger.d('Successfully fetched ${modelsResponse.models.length} models for $generatorType');
        return modelsResponse;
      } else {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _logger.e('Error fetching models for $generatorType: $e');

      if (e.response?.statusCode == 404) {
        throw Exception('Generator type not found: $generatorType');
      }

      throw Exception('Failed to fetch models: ${e.message}');
    } catch (e) {
      _logger.e('Unexpected error fetching models: $e');
      throw Exception('Failed to fetch models: $e');
    }
  }

  /// Get recommended models for a generator type
  Future<List<GeneratorModel>> getRecommendedModels(String generatorType) async {
    final response = await getModelsForGenerator(generatorType);
    return response.models.where((m) => m.recommended).toList();
  }

  /// Clear the cache (useful for forcing refresh)
  void clearCache() {
    _cache.clear();
    _logger.d('Model cache cleared');
  }

  /// Get all available models for all generator types
  Future<Map<String, GeneratorModelsResponse>> getAllModels() async {
    try {
      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/generators/models/all',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final generators = data['generators'] as Map<String, dynamic>;

        final result = <String, GeneratorModelsResponse>{};

        for (final entry in generators.entries) {
          result[entry.key] = GeneratorModelsResponse.fromJson({
            'generator_type': entry.key,
            ...entry.value as Map<String, dynamic>,
          });

          // Cache each generator's models
          _cache[entry.key] = result[entry.key]!;
        }

        return result;
      } else {
        throw Exception('Failed to fetch all models: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching all models: $e');
      throw Exception('Failed to fetch all models: $e');
    }
  }
}
