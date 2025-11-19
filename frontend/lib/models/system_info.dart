import 'package:json_annotation/json_annotation.dart';

part 'system_info.g.dart';

/// System and garak installation information
@JsonSerializable()
class SystemInfo {
  @JsonKey(name: 'garak_version')
  final String garakVersion;

  @JsonKey(name: 'python_version')
  final String pythonVersion;

  @JsonKey(name: 'backend_version')
  final String backendVersion;

  @JsonKey(name: 'garak_installed')
  final bool garakInstalled;

  @JsonKey(name: 'available_generators')
  final List<String> availableGenerators;

  const SystemInfo({
    required this.garakVersion,
    required this.pythonVersion,
    required this.backendVersion,
    required this.garakInstalled,
    required this.availableGenerators,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) =>
      _$SystemInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SystemInfoToJson(this);
}
