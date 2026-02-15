/// Workflow graph model
/// Complete workflow graph for a scan
import 'package:freezed_annotation/freezed_annotation.dart';
import 'workflow_node.dart';
import 'workflow_edge.dart';

part 'workflow_graph.freezed.dart';
part 'workflow_graph.g.dart';

/// Complete workflow graph for a scan
@freezed
class WorkflowGraph with _$WorkflowGraph {
  const WorkflowGraph._();

  const factory WorkflowGraph({
    @JsonKey(name: 'scan_id') required String scanId,
    @Default([]) List<WorkflowNode> nodes,
    @Default([]) List<WorkflowEdge> edges,
    @Default({}) Map<String, dynamic> statistics,
    @JsonKey(name: 'layout_hints') @Default({}) Map<String, dynamic> layoutHints,
  }) = _WorkflowGraph;

  factory WorkflowGraph.fromJson(Map<String, dynamic> json) =>
      _$WorkflowGraphFromJson(json);

  /// Get nodes by type
  List<WorkflowNode> getNodesByType(WorkflowNodeType type) {
    return nodes.where((node) => node.nodeType == type).toList();
  }

  /// Get edges for a specific node
  List<WorkflowEdge> getEdgesForNode(String nodeId) {
    return edges
        .where((edge) => edge.sourceId == nodeId || edge.targetId == nodeId)
        .toList();
  }

  /// Get outgoing edges from a node
  List<WorkflowEdge> getOutgoingEdges(String nodeId) {
    return edges.where((edge) => edge.sourceId == nodeId).toList();
  }

  /// Get incoming edges to a node
  List<WorkflowEdge> getIncomingEdges(String nodeId) {
    return edges.where((edge) => edge.targetId == nodeId).toList();
  }

  /// Get node by ID
  WorkflowNode? getNodeById(String nodeId) {
    try {
      return nodes.firstWhere((node) => node.nodeId == nodeId);
    } catch (e) {
      return null;
    }
  }

  /// Get total interactions count
  int get totalInteractions => statistics['total_interactions'] as int? ?? 0;

  /// Get vulnerabilities found count
  int get vulnerabilitiesFound =>
      statistics['vulnerabilities_found'] as int? ?? 0;

  /// Get total prompts count
  int get totalPrompts => statistics['total_prompts'] as int? ?? 0;

  /// Get total responses count
  int get totalResponses => statistics['total_responses'] as int? ?? 0;

  /// Check if graph is empty
  bool get isEmpty => nodes.isEmpty;

  /// Check if graph has vulnerabilities
  bool get hasVulnerabilities =>
      nodes.any((node) => node.nodeType == WorkflowNodeType.vulnerability);

  /// Return a filtered copy keeping only nodes of the given types
  /// and edges where both endpoints are visible.
  WorkflowGraph filtered(Set<WorkflowNodeType> visibleTypes) {
    final filteredNodes =
        nodes.where((n) => visibleTypes.contains(n.nodeType)).toList();
    final visibleNodeIds = filteredNodes.map((n) => n.nodeId).toSet();
    final filteredEdges = edges
        .where((e) =>
            visibleNodeIds.contains(e.sourceId) &&
            visibleNodeIds.contains(e.targetId))
        .toList();
    return copyWith(nodes: filteredNodes, edges: filteredEdges);
  }
}
