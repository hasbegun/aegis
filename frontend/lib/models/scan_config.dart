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
    );
  }
}
