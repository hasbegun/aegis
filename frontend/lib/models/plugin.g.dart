// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PluginInfo _$PluginInfoFromJson(Map<String, dynamic> json) => PluginInfo(
      name: json['name'] as String,
      fullName: json['full_name'] as String,
      description: json['description'] as String?,
      active: json['active'] as bool,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      primaryDetector: json['primary_detector'] as String?,
      goal: json['goal'] as String?,
    );

Map<String, dynamic> _$PluginInfoToJson(PluginInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'full_name': instance.fullName,
      'description': instance.description,
      'active': instance.active,
      'tags': instance.tags,
      'primary_detector': instance.primaryDetector,
      'goal': instance.goal,
    };

PluginListResponse _$PluginListResponseFromJson(Map<String, dynamic> json) =>
    PluginListResponse(
      plugins: (json['plugins'] as List<dynamic>)
          .map((e) => PluginInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num).toInt(),
    );

Map<String, dynamic> _$PluginListResponseToJson(PluginListResponse instance) =>
    <String, dynamic>{
      'plugins': instance.plugins,
      'total_count': instance.totalCount,
    };
