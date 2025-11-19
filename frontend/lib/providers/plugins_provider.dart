import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plugin.dart';
import 'api_provider.dart';

/// Provider for available generators
final generatorsProvider = FutureProvider<List<PluginInfo>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.listGenerators();
  return response.plugins;
});

/// Provider for available probes
final probesProvider = FutureProvider<List<PluginInfo>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.listProbes();
  return response.plugins;
});

/// Provider for available detectors
final detectorsProvider = FutureProvider<List<PluginInfo>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.listDetectors();
  return response.plugins;
});

/// Provider for available buffs
final buffsProvider = FutureProvider<List<PluginInfo>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.listBuffs();
  return response.plugins;
});

/// Provider for categorized probes (grouped by category)
final categorizedProbesProvider = FutureProvider<Map<String, List<PluginInfo>>>((ref) async {
  final probes = await ref.watch(probesProvider.future);

  final Map<String, List<PluginInfo>> categorized = {};

  for (final probe in probes) {
    // Extract category from full name (e.g., "probes.dan.Dan_11_0" -> "dan")
    final category = _extractCategory(probe.fullName);

    if (!categorized.containsKey(category)) {
      categorized[category] = [];
    }
    categorized[category]!.add(probe);
  }

  return categorized;
});

String _extractCategory(String fullName) {
  final parts = fullName.split('.');
  if (parts.length >= 2) {
    return parts[1];
  }
  return 'other';
}
