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
      probeTags: state?.probeTags,
      systemPrompt: state?.systemPrompt,
      extendedDetectors: state?.extendedDetectors ?? false,
      deprefix: state?.deprefix ?? false,
      verbose: state?.verbose ?? 0,
      skipUnknown: state?.skipUnknown ?? false,
      buffsIncludeOriginalPrompt: state?.buffsIncludeOriginalPrompt ?? false,
      outputDir: state?.outputDir,
      noReport: state?.noReport ?? false,
      continueOnError: state?.continueOnError ?? false,
      excludeProbes: state?.excludeProbes,
      excludeDetectors: state?.excludeDetectors,
      timeoutPerProbe: state?.timeoutPerProbe,
      configFile: state?.configFile,
      hitRate: state?.hitRate,
      reportThreshold: state?.reportThreshold,
      collectTiming: state?.collectTiming ?? false,
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

  /// Set probe tags filter (e.g., 'owasp:llm01')
  void setProbeTags(String? tags) {
    if (state == null) return;
    state = state!.copyWith(probeTags: tags);
  }

  /// Set system prompt override
  void setSystemPrompt(String? prompt) {
    if (state == null) return;
    state = state!.copyWith(systemPrompt: prompt);
  }

  /// Set extended detectors mode
  void setExtendedDetectors(bool value) {
    if (state == null) return;
    state = state!.copyWith(extendedDetectors: value);
  }

  /// Set deprefix mode
  void setDeprefix(bool value) {
    if (state == null) return;
    state = state!.copyWith(deprefix: value);
  }

  /// Set verbose level
  void setVerbose(int level) {
    if (state == null) return;
    state = state!.copyWith(verbose: level);
  }

  /// Set skip unknown plugins mode
  void setSkipUnknown(bool value) {
    if (state == null) return;
    state = state!.copyWith(skipUnknown: value);
  }

  /// Set buffs include original prompt mode
  void setBuffsIncludeOriginalPrompt(bool value) {
    if (state == null) return;
    state = state!.copyWith(buffsIncludeOriginalPrompt: value);
  }

  /// Set output directory
  void setOutputDir(String? value) {
    if (state == null) return;
    state = state!.copyWith(outputDir: value);
  }

  /// Set no report mode
  void setNoReport(bool value) {
    if (state == null) return;
    state = state!.copyWith(noReport: value);
  }

  /// Set continue on error mode
  void setContinueOnError(bool value) {
    if (state == null) return;
    state = state!.copyWith(continueOnError: value);
  }

  /// Set exclude probes
  void setExcludeProbes(String? value) {
    if (state == null) return;
    state = state!.copyWith(excludeProbes: value);
  }

  /// Set exclude detectors
  void setExcludeDetectors(String? value) {
    if (state == null) return;
    state = state!.copyWith(excludeDetectors: value);
  }

  /// Set timeout per probe
  void setTimeoutPerProbe(int? value) {
    if (state == null) return;
    state = state!.copyWith(timeoutPerProbe: value);
  }

  /// Set config file path
  void setConfigFile(String? value) {
    if (state == null) return;
    state = state!.copyWith(configFile: value);
  }

  /// Set hit rate
  void setHitRate(double? value) {
    if (state == null) return;
    state = state!.copyWith(hitRate: value);
  }

  /// Set report threshold
  void setReportThreshold(double? value) {
    if (state == null) return;
    state = state!.copyWith(reportThreshold: value);
  }

  /// Set collect timing
  void setCollectTiming(bool value) {
    if (state == null) return;
    state = state!.copyWith(collectTiming: value);
  }

  /// Set entire configuration (used when resuming from background)
  void setConfig(ScanConfig config) {
    state = config;
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
