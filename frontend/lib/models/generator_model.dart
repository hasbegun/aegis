import 'package:json_annotation/json_annotation.dart';

part 'generator_model.g.dart';

/// Represents a model available for a specific generator
@JsonSerializable()
class GeneratorModel {
  final String id;
  final String name;
  final String description;
  @JsonKey(name: 'context_length')
  final int? contextLength;
  final bool recommended;

  const GeneratorModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.recommended = false,
  });

  factory GeneratorModel.fromJson(Map<String, dynamic> json) =>
      _$GeneratorModelFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratorModelToJson(this);

  /// Display text for the model (used in dropdown)
  String get displayText => name;

  /// Subtitle text showing description
  String get subtitle => description;

  /// Badge text showing context length
  String? get badge => contextLength != null ? '${contextLength}K' : null;
}

/// Response from the models API for a specific generator type
@JsonSerializable()
class GeneratorModelsResponse {
  @JsonKey(name: 'generator_type')
  final String generatorType;

  final List<GeneratorModel> models;

  @JsonKey(name: 'requires_api_key')
  final bool requiresApiKey;

  @JsonKey(name: 'api_key_env_var')
  final String? apiKeyEnvVar;

  final String? note;

  const GeneratorModelsResponse({
    required this.generatorType,
    required this.models,
    required this.requiresApiKey,
    this.apiKeyEnvVar,
    this.note,
  });

  factory GeneratorModelsResponse.fromJson(Map<String, dynamic> json) =>
      _$GeneratorModelsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratorModelsResponseToJson(this);

  /// Get recommended models
  List<GeneratorModel> get recommendedModels =>
      models.where((m) => m.recommended).toList();

  /// Get all model IDs
  List<String> get modelIds => models.map((m) => m.id).toList();
}
