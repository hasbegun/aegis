import 'package:json_annotation/json_annotation.dart';

part 'scan_config.g.dart';

/// Configuration for a garak scan
@JsonSerializable()
class ScanConfig {
  @JsonKey(name: 'target_type')
  final String targetType;

  @JsonKey(name: 'target_name')
  final String targetName;

  final List<String> probes;

  final List<String>? detectors;

  final List<String>? buffs;

  // Run parameters
  final int generations;

  @JsonKey(name: 'eval_threshold')
  final double evalThreshold;

  final int? seed;

  // System parameters
  @JsonKey(name: 'parallel_requests')
  final int? parallelRequests;

  @JsonKey(name: 'parallel_attempts')
  final int? parallelAttempts;

  // Options
  @JsonKey(name: 'generator_options')
  final Map<String, dynamic>? generatorOptions;

  @JsonKey(name: 'probe_options')
  final Map<String, dynamic>? probeOptions;

  // Reporting
  @JsonKey(name: 'report_prefix')
  final String? reportPrefix;

  // Filtering
  @JsonKey(name: 'probe_tags')
  final String? probeTags;

  // System prompt
  @JsonKey(name: 'system_prompt')
  final String? systemPrompt;

  // Extended detectors
  @JsonKey(name: 'extended_detectors')
  final bool extendedDetectors;

  // Deprefix
  @JsonKey(name: 'deprefix')
  final bool deprefix;

  // Verbose
  @JsonKey(name: 'verbose')
  final int verbose;

  // Skip unknown plugins
  @JsonKey(name: 'skip_unknown')
  final bool skipUnknown;

  // Buffs include original prompt
  @JsonKey(name: 'buffs_include_original_prompt')
  final bool buffsIncludeOriginalPrompt;

  // Output directory
  @JsonKey(name: 'output_dir')
  final String? outputDir;

  // No report
  @JsonKey(name: 'no_report')
  final bool noReport;

  // Continue on error
  @JsonKey(name: 'continue_on_error')
  final bool continueOnError;

  // Exclude probes
  @JsonKey(name: 'exclude_probes')
  final String? excludeProbes;

  // Exclude detectors
  @JsonKey(name: 'exclude_detectors')
  final String? excludeDetectors;

  // Timeout per probe
  @JsonKey(name: 'timeout_per_probe')
  final int? timeoutPerProbe;

  // Config file
  @JsonKey(name: 'config_file')
  final String? configFile;

  // Hit rate
  @JsonKey(name: 'hit_rate')
  final double? hitRate;

  // Report threshold
  @JsonKey(name: 'report_threshold')
  final double? reportThreshold;

  // Collect timing
  @JsonKey(name: 'collect_timing')
  final bool collectTiming;

  const ScanConfig({
    required this.targetType,
    required this.targetName,
    required this.probes,
    this.detectors,
    this.buffs,
    this.generations = 10,
    this.evalThreshold = 0.5,
    this.seed,
    this.parallelRequests,
    this.parallelAttempts,
    this.generatorOptions,
    this.probeOptions,
    this.reportPrefix,
    this.probeTags,
    this.systemPrompt,
    this.extendedDetectors = false,
    this.deprefix = false,
    this.verbose = 0,
    this.skipUnknown = false,
    this.buffsIncludeOriginalPrompt = false,
    this.outputDir,
    this.noReport = false,
    this.continueOnError = false,
    this.excludeProbes,
    this.excludeDetectors,
    this.timeoutPerProbe,
    this.configFile,
    this.hitRate,
    this.reportThreshold,
    this.collectTiming = false,
  });

  factory ScanConfig.fromJson(Map<String, dynamic> json) =>
      _$ScanConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ScanConfigToJson(this);

  ScanConfig copyWith({
    String? targetType,
    String? targetName,
    List<String>? probes,
    List<String>? detectors,
    List<String>? buffs,
    int? generations,
    double? evalThreshold,
    int? seed,
    int? parallelRequests,
    int? parallelAttempts,
    Map<String, dynamic>? generatorOptions,
    Map<String, dynamic>? probeOptions,
    String? reportPrefix,
    String? probeTags,
    String? systemPrompt,
    bool? extendedDetectors,
    bool? deprefix,
    int? verbose,
    bool? skipUnknown,
    bool? buffsIncludeOriginalPrompt,
    String? outputDir,
    bool? noReport,
    bool? continueOnError,
    String? excludeProbes,
    String? excludeDetectors,
    int? timeoutPerProbe,
    String? configFile,
    double? hitRate,
    double? reportThreshold,
    bool? collectTiming,
  }) {
    return ScanConfig(
      targetType: targetType ?? this.targetType,
      targetName: targetName ?? this.targetName,
      probes: probes ?? this.probes,
      detectors: detectors ?? this.detectors,
      buffs: buffs ?? this.buffs,
      generations: generations ?? this.generations,
      evalThreshold: evalThreshold ?? this.evalThreshold,
      seed: seed ?? this.seed,
      parallelRequests: parallelRequests ?? this.parallelRequests,
      parallelAttempts: parallelAttempts ?? this.parallelAttempts,
      generatorOptions: generatorOptions ?? this.generatorOptions,
      probeOptions: probeOptions ?? this.probeOptions,
      reportPrefix: reportPrefix ?? this.reportPrefix,
      probeTags: probeTags ?? this.probeTags,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      extendedDetectors: extendedDetectors ?? this.extendedDetectors,
      deprefix: deprefix ?? this.deprefix,
      verbose: verbose ?? this.verbose,
      skipUnknown: skipUnknown ?? this.skipUnknown,
      buffsIncludeOriginalPrompt: buffsIncludeOriginalPrompt ?? this.buffsIncludeOriginalPrompt,
      outputDir: outputDir ?? this.outputDir,
      noReport: noReport ?? this.noReport,
      continueOnError: continueOnError ?? this.continueOnError,
      excludeProbes: excludeProbes ?? this.excludeProbes,
      excludeDetectors: excludeDetectors ?? this.excludeDetectors,
      timeoutPerProbe: timeoutPerProbe ?? this.timeoutPerProbe,
      configFile: configFile ?? this.configFile,
      hitRate: hitRate ?? this.hitRate,
      reportThreshold: reportThreshold ?? this.reportThreshold,
      collectTiming: collectTiming ?? this.collectTiming,
    );
  }
}
