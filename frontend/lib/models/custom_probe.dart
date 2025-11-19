/// Custom probe models
class CustomProbe {
  final String name;
  final String filePath;
  final String? description;
  final String createdAt;
  final String updatedAt;
  final String? goal;
  final List<String>? tags;
  final String? primaryDetector;

  CustomProbe({
    required this.name,
    required this.filePath,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.goal,
    this.tags,
    this.primaryDetector,
  });

  factory CustomProbe.fromJson(Map<String, dynamic> json) {
    return CustomProbe(
      name: json['name'] as String,
      filePath: json['file_path'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      goal: json['goal'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      primaryDetector: json['primary_detector'] as String?,
    );
  }
}

class CustomProbeWithCode {
  final CustomProbe probe;
  final String code;

  CustomProbeWithCode({
    required this.probe,
    required this.code,
  });

  factory CustomProbeWithCode.fromJson(Map<String, dynamic> json) {
    return CustomProbeWithCode(
      probe: CustomProbe.fromJson(json['probe'] as Map<String, dynamic>),
      code: json['code'] as String,
    );
  }
}

class ValidationError {
  final int? line;
  final int? column;
  final String message;
  final String errorType;

  ValidationError({
    this.line,
    this.column,
    required this.message,
    required this.errorType,
  });

  factory ValidationError.fromJson(Map<String, dynamic> json) {
    return ValidationError(
      line: json['line'] as int?,
      column: json['column'] as int?,
      message: json['message'] as String,
      errorType: json['error_type'] as String,
    );
  }
}

class ProbeValidationResult {
  final bool valid;
  final List<ValidationError> errors;
  final List<String> warnings;
  final Map<String, dynamic>? probeInfo;

  ProbeValidationResult({
    required this.valid,
    required this.errors,
    required this.warnings,
    this.probeInfo,
  });

  factory ProbeValidationResult.fromJson(Map<String, dynamic> json) {
    return ProbeValidationResult(
      valid: json['valid'] as bool,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => ValidationError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      probeInfo: json['probe_info'] as Map<String, dynamic>?,
    );
  }
}

enum ProbeTemplate {
  minimal,
  basic,
  advanced;

  String get displayName {
    switch (this) {
      case ProbeTemplate.minimal:
        return 'Minimal';
      case ProbeTemplate.basic:
        return 'Basic';
      case ProbeTemplate.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case ProbeTemplate.minimal:
        return 'Just class definition';
      case ProbeTemplate.basic:
        return 'With prompts attribute';
      case ProbeTemplate.advanced:
        return 'Custom probe() method';
    }
  }
}
