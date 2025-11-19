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
    };
