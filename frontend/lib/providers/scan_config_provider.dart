import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_config.dart';
import '../config/constants.dart';

/// State notifier for scan configuration
class ScanConfigNotifier extends StateNotifier<ScanConfig?> {
  ScanConfigNotifier() : super(null);

  /// Set the target (generator type and name)
  void setTarget(String targetType, String targetName) {
    state = ScanConfig(
      targetType: targetType,
      targetName: targetName,
      probes: state?.probes ?? ['all'],
      generations: state?.generations ?? AppConstants.defaultGenerations,
      evalThreshold: state?.evalThreshold ?? AppConstants.defaultEvalThreshold,
      detectors: state?.detectors,
      buffs: state?.buffs,
      seed: state?.seed,
      parallelRequests: state?.parallelRequests,
      parallelAttempts: state?.parallelAttempts,
      generatorOptions: state?.generatorOptions,
      probeOptions: state?.probeOptions,
      reportPrefix: state?.reportPrefix,
    );
  }

  /// Set selected probes
  void setProbes(List<String> probes) {
    if (state == null) return;
    state = state!.copyWith(probes: probes);
  }

  /// Set detectors
  void setDetectors(List<String>? detectors) {
    if (state == null) return;
    state = state!.copyWith(detectors: detectors);
  }

  /// Set buffs
  void setBuffs(List<String>? buffs) {
    if (state == null) return;
    state = state!.copyWith(buffs: buffs);
  }

  /// Set generations count
  void setGenerations(int generations) {
    if (state == null) return;
    state = state!.copyWith(generations: generations);
  }

  /// Set evaluation threshold
  void setEvalThreshold(double threshold) {
    if (state == null) return;
    state = state!.copyWith(evalThreshold: threshold);
  }

  /// Set seed
  void setSeed(int? seed) {
    if (state == null) return;
    state = state!.copyWith(seed: seed);
  }

  /// Set parallel requests
  void setParallelRequests(int? parallelRequests) {
    if (state == null) return;
    state = state!.copyWith(parallelRequests: parallelRequests);
  }

  /// Set parallel attempts
  void setParallelAttempts(int? parallelAttempts) {
    if (state == null) return;
    state = state!.copyWith(parallelAttempts: parallelAttempts);
  }

  /// Set generator options (including API key)
  void setGeneratorOptions(Map<String, dynamic>? options) {
    if (state == null) return;
    state = state!.copyWith(generatorOptions: options);
  }

  /// Set probe options
  void setProbeOptions(Map<String, dynamic>? options) {
    if (state == null) return;
    state = state!.copyWith(probeOptions: options);
  }

  /// Set report prefix
  void setReportPrefix(String? prefix) {
    if (state == null) return;
    state = state!.copyWith(reportPrefix: prefix);
  }

  /// Reset configuration
  void reset() {
    state = null;
  }

  /// Load from preset
  void loadPreset(Map<String, dynamic> preset) {
    final config = preset['config'] as Map<String, dynamic>;

    if (state != null) {
      state = ScanConfig(
        targetType: state!.targetType,
        targetName: state!.targetName,
        probes: (config['probes'] as List?)?.cast<String>() ?? ['all'],
        generations: config['generations'] as int? ?? AppConstants.defaultGenerations,
        evalThreshold: (config['eval_threshold'] as num?)?.toDouble() ?? AppConstants.defaultEvalThreshold,
        detectors: (config['detectors'] as List?)?.cast<String>(),
        buffs: (config['buffs'] as List?)?.cast<String>(),
        parallelRequests: config['parallel_requests'] as int?,
        parallelAttempts: config['parallel_attempts'] as int?,
        generatorOptions: state!.generatorOptions,
      );
    }
  }
}

/// Provider for scan configuration
final scanConfigProvider = StateNotifierProvider<ScanConfigNotifier, ScanConfig?>((ref) {
  return ScanConfigNotifier();
});
