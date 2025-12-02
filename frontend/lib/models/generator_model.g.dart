// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generator_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneratorModel _$GeneratorModelFromJson(Map<String, dynamic> json) =>
    GeneratorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      contextLength: (json['context_length'] as num?)?.toInt(),
      recommended: json['recommended'] as bool? ?? false,
    );

Map<String, dynamic> _$GeneratorModelToJson(GeneratorModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'context_length': instance.contextLength,
      'recommended': instance.recommended,
    };

GeneratorModelsResponse _$GeneratorModelsResponseFromJson(
        Map<String, dynamic> json) =>
    GeneratorModelsResponse(
      generatorType: json['generator_type'] as String,
      models: (json['models'] as List<dynamic>)
          .map((e) => GeneratorModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiresApiKey: json['requires_api_key'] as bool,
      apiKeyEnvVar: json['api_key_env_var'] as String?,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$GeneratorModelsResponseToJson(
        GeneratorModelsResponse instance) =>
    <String, dynamic>{
      'generator_type': instance.generatorType,
      'models': instance.models,
      'requires_api_key': instance.requiresApiKey,
      'api_key_env_var': instance.apiKeyEnvVar,
      'note': instance.note,
    };
