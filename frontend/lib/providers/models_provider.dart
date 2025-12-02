import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/models_service.dart';
import '../models/generator_model.dart';

// Dio instance provider (shared with other services)
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  return dio;
});

// Models service provider
final modelsServiceProvider = Provider<ModelsService>((ref) {
  final dio = ref.watch(dioProvider);
  return ModelsService(dio);
});

// Provider for fetching models for a specific generator type
final generatorModelsProvider = FutureProvider.family<GeneratorModelsResponse, String>(
  (ref, generatorType) async {
    final service = ref.watch(modelsServiceProvider);
    return service.getModelsForGenerator(generatorType);
  },
);

// Provider for recommended models only
final recommendedModelsProvider = FutureProvider.family<List<GeneratorModel>, String>(
  (ref, generatorType) async {
    final service = ref.watch(modelsServiceProvider);
    return service.getRecommendedModels(generatorType);
  },
);
