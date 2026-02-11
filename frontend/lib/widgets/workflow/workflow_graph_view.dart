import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../models/workflow/workflow_graph.dart';
import '../../models/workflow/workflow_node.dart';

/// Widget for displaying workflow graph visualization
class WorkflowGraphView extends StatefulWidget {
  final WorkflowGraph graph;
  final Function(String nodeId)? onNodeTap;

  const WorkflowGraphView({
    super.key,
    required this.graph,
    this.onNodeTap,
  });

  @override
  State<WorkflowGraphView> createState() => _WorkflowGraphViewState();
}

class _WorkflowGraphViewState extends State<WorkflowGraphView> {
  final Graph graph = Graph()..isTree = true;
  late BuchheimWalkerConfiguration builder;

  @override
  void initState() {
    super.initState();
    _initializeGraph();
  }

  void _initializeGraph() {
    builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = 100
      ..levelSeparation = 150
      ..subtreeSeparation = 150
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

    _buildGraph();
  }

  void _buildGraph() {
    // Clear existing graph
    graph.nodes.clear();
    graph.edges.clear();

    // Create nodes
    for (var node in widget.graph.nodes) {
      graph.addNode(Node.Id(node.nodeId));
    }

    // Create edges
    for (var edge in widget.graph.edges) {
      try {
        final source = graph.getNodeUsingId(edge.sourceId);
        final target = graph.getNodeUsingId(edge.targetId);
        graph.addEdge(source, target);
      } catch (e) {
        // Skip invalid edges
        debugPrint('Failed to add edge: ${edge.sourceId} -> ${edge.targetId}');
      }
    }
  }

  @override
  void didUpdateWidget(WorkflowGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph != widget.graph) {
      _buildGraph();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.graph.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No workflow data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 5.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: GraphView(
                graph: graph,
                algorithm:
                    BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
                paint: Paint()
                  ..color = Theme.of(context).colorScheme.primary
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  final nodeId = node.key!.value as String;
                  final workflowNode = widget.graph.getNodeById(nodeId);

                  if (workflowNode == null) {
                    return const SizedBox();
                  }

                  return _buildNodeWidget(workflowNode);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeWidget(WorkflowNode node) {
    final theme = Theme.of(context);
    final color = _getNodeColor(node.nodeType, theme);
    final icon = _getNodeIcon(node.nodeType);

    return InkWell(
      onTap: () => widget.onNodeTap?.call(node.nodeId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 180,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              node.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (node.description != null) ...[
              const SizedBox(height: 4),
              Text(
                node.description!,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getNodeColor(WorkflowNodeType type, ThemeData theme) {
    switch (type) {
      case WorkflowNodeType.probe:
        return Colors.blue;
      case WorkflowNodeType.generator:
        return Colors.green;
      case WorkflowNodeType.detector:
        return Colors.orange;
      case WorkflowNodeType.llmResponse:
        return Colors.purple;
      case WorkflowNodeType.vulnerability:
        return Colors.red;
    }
  }

  IconData _getNodeIcon(WorkflowNodeType type) {
    switch (type) {
      case WorkflowNodeType.probe:
        return Icons.search;
      case WorkflowNodeType.generator:
        return Icons.settings;
      case WorkflowNodeType.detector:
        return Icons.radar;
      case WorkflowNodeType.llmResponse:
        return Icons.psychology;
      case WorkflowNodeType.vulnerability:
        return Icons.warning;
    }
  }
}
