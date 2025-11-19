// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SystemInfo _$SystemInfoFromJson(Map<String, dynamic> json) => SystemInfo(
      garakVersion: json['garak_version'] as String,
      pythonVersion: json['python_version'] as String,
      backendVersion: json['backend_version'] as String,
      garakInstalled: json['garak_installed'] as bool,
      availableGenerators: (json['available_generators'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SystemInfoToJson(SystemInfo instance) =>
    <String, dynamic>{
      'garak_version': instance.garakVersion,
      'python_version': instance.pythonVersion,
      'backend_version': instance.backendVersion,
      'garak_installed': instance.garakInstalled,
      'available_generators': instance.availableGenerators,
    };
