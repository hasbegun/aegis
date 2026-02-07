// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanConfig _$ScanConfigFromJson(Map<String, dynamic> json) => ScanConfig(
      targetType: json['target_type'] as String,
      targetName: json['target_name'] as String,
      probes:
          (json['probes'] as List<dynamic>).map((e) => e as String).toList(),
      detectors: (json['detectors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      buffs:
          (json['buffs'] as List<dynamic>?)?.map((e) => e as String).toList(),
      generations: (json['generations'] as num?)?.toInt() ?? 10,
      evalThreshold: (json['eval_threshold'] as num?)?.toDouble() ?? 0.5,
      seed: (json['seed'] as num?)?.toInt(),
      parallelRequests: (json['parallel_requests'] as num?)?.toInt(),
      parallelAttempts: (json['parallel_attempts'] as num?)?.toInt(),
      generatorOptions: json['generator_options'] as Map<String, dynamic>?,
      probeOptions: json['probe_options'] as Map<String, dynamic>?,
      reportPrefix: json['report_prefix'] as String?,
      probeTags: json['probe_tags'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      extendedDetectors: json['extended_detectors'] as bool? ?? false,
      deprefix: json['deprefix'] as bool? ?? false,
      verbose: (json['verbose'] as num?)?.toInt() ?? 0,
      skipUnknown: json['skip_unknown'] as bool? ?? false,
      buffsIncludeOriginalPrompt:
          json['buffs_include_original_prompt'] as bool? ?? false,
      outputDir: json['output_dir'] as String?,
      noReport: json['no_report'] as bool? ?? false,
      continueOnError: json['continue_on_error'] as bool? ?? false,
      excludeProbes: json['exclude_probes'] as String?,
      excludeDetectors: json['exclude_detectors'] as String?,
      timeoutPerProbe: (json['timeout_per_probe'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ScanConfigToJson(ScanConfig instance) =>
    <String, dynamic>{
      'target_type': instance.targetType,
      'target_name': instance.targetName,
      'probes': instance.probes,
      'detectors': instance.detectors,
      'buffs': instance.buffs,
      'generations': instance.generations,
      'eval_threshold': instance.evalThreshold,
      'seed': instance.seed,
      'parallel_requests': instance.parallelRequests,
      'parallel_attempts': instance.parallelAttempts,
      'generator_options': instance.generatorOptions,
      'probe_options': instance.probeOptions,
      'report_prefix': instance.reportPrefix,
      'probe_tags': instance.probeTags,
      'system_prompt': instance.systemPrompt,
      'extended_detectors': instance.extendedDetectors,
      'deprefix': instance.deprefix,
      'verbose': instance.verbose,
      'skip_unknown': instance.skipUnknown,
      'buffs_include_original_prompt': instance.buffsIncludeOriginalPrompt,
      'output_dir': instance.outputDir,
      'no_report': instance.noReport,
      'continue_on_error': instance.continueOnError,
      'exclude_probes': instance.excludeProbes,
      'exclude_detectors': instance.excludeDetectors,
      'timeout_per_probe': instance.timeoutPerProbe,
    };
