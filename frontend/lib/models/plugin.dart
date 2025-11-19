import 'package:json_annotation/json_annotation.dart';

part 'plugin.g.dart';

/// Information about a garak plugin (probe, detector, generator, buff)
@JsonSerializable()
class PluginInfo {
  final String name;

  @JsonKey(name: 'full_name')
  final String fullName;

  final String? description;

  final bool active;

  final List<String>? tags;

  @JsonKey(name: 'primary_detector')
  final String? primaryDetector;

  final String? goal;

  const PluginInfo({
    required this.name,
    required this.fullName,
    this.description,
    required this.active,
    this.tags,
    this.primaryDetector,
    this.goal,
  });

  factory PluginInfo.fromJson(Map<String, dynamic> json) =>
      _$PluginInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PluginInfoToJson(this);
}

/// Response containing list of plugins
@JsonSerializable()
class PluginListResponse {
  final List<PluginInfo> plugins;

  @JsonKey(name: 'total_count')
  final int totalCount;

  const PluginListResponse({
    required this.plugins,
    required this.totalCount,
  });

  factory PluginListResponse.fromJson(Map<String, dynamic> json) =>
      _$PluginListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PluginListResponseToJson(this);
}

/// Categorized plugin for UI display
class CategorizedPlugin {
  final String category;
  final String name;
  final String fullName;
  final String? description;
  final bool active;
  final List<String>? tags;

  const CategorizedPlugin({
    required this.category,
    required this.name,
    required this.fullName,
    this.description,
    required this.active,
    this.tags,
  });

  factory CategorizedPlugin.fromPluginInfo(
    PluginInfo info, {
    String? category,
  }) {
    return CategorizedPlugin(
      category: category ?? _extractCategory(info.fullName),
      name: info.name,
      fullName: info.fullName,
      description: info.description,
      active: info.active,
      tags: info.tags,
    );
  }

  static String _extractCategory(String fullName) {
    // Extract category from fullName (e.g., "probes.dan.Dan_11_0" -> "dan")
    final parts = fullName.split('.');
    if (parts.length >= 2) {
      return parts[1];
    }
    return 'other';
  }
}
