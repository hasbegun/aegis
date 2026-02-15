import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../models/workflow/workflow_graph.dart';
import '../../models/workflow/workflow_node.dart';
import '../../models/workflow/workflow_edge.dart';

/// Widget for displaying workflow graph visualization.
///
/// Uses SugiyamaAlgorithm for DAG layout (supports multiple parents per node),
/// then renders nodes and edges manually so edges connect at node borders
/// instead of going through node centers.
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

  /// Public static helpers so other widgets (legend, filters) can reuse colors/icons.
  static Color getNodeColor(WorkflowNodeType type) {
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

  static IconData getNodeIcon(WorkflowNodeType type) {
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

  static Color getEdgeColor(WorkflowEdgeType type) {
    switch (type) {
      case WorkflowEdgeType.prompt:
        return Colors.blue.shade400;
      case WorkflowEdgeType.chain:
        return Colors.green.shade400;
      case WorkflowEdgeType.detection:
        return Colors.orange.shade400;
      case WorkflowEdgeType.response:
        return Colors.purple.shade400;
    }
  }

  static String getNodeTypeLabel(WorkflowNodeType type) {
    switch (type) {
      case WorkflowNodeType.probe:
        return 'Probe';
      case WorkflowNodeType.generator:
        return 'Generator';
      case WorkflowNodeType.detector:
        return 'Detector';
      case WorkflowNodeType.llmResponse:
        return 'LLM Response';
      case WorkflowNodeType.vulnerability:
        return 'Vulnerability';
    }
  }
}

class _WorkflowGraphViewState extends State<WorkflowGraphView> {
  final Graph _graph = Graph();
  late SugiyamaConfiguration _config;

  static const double _nodeWidth = 170.0;
  static const double _nodeHeight = 130.0;
  static const double _padding = 40.0;

  @override
  void initState() {
    super.initState();
    _config = SugiyamaConfiguration()
      ..nodeSeparation = 80
      ..levelSeparation = 100
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
    _buildAndLayout();
  }

  @override
  void didUpdateWidget(WorkflowGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph != widget.graph) {
      _buildAndLayout();
    }
  }

  void _buildAndLayout() {
    _graph.nodes.clear();
    _graph.edges.clear();

    for (var node in widget.graph.nodes) {
      final n = Node.Id(node.nodeId);
      n.size = const Size(_nodeWidth, _nodeHeight);
      _graph.addNode(n);
    }

    for (var edge in widget.graph.edges) {
      try {
        final source = _graph.getNodeUsingId(edge.sourceId);
        final target = _graph.getNodeUsingId(edge.targetId);
        _graph.addEdge(source, target);
      } catch (e) {
        debugPrint('Failed to add edge: ${edge.sourceId} -> ${edge.targetId}');
      }
    }

    // Run Sugiyama layout — computes x, y for each node
    final algorithm = SugiyamaAlgorithm(_config);
    algorithm.run(_graph, _padding, _padding);
  }

  /// Build a lookup map from "sourceId->targetId" to edge info for the painter.
  Map<String, _EdgeInfo> _buildEdgeInfoMap() {
    final map = <String, _EdgeInfo>{};
    for (var edge in widget.graph.edges) {
      final key = '${edge.sourceId}->${edge.targetId}';
      map[key] = _EdgeInfo(
        type: edge.edgeType,
        label: edge.label,
        color: WorkflowGraphView.getEdgeColor(edge.edgeType),
      );
    }
    return map;
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

    // Compute canvas size from node positions
    double maxX = 0, maxY = 0;
    for (var node in _graph.nodes) {
      maxX = max(maxX, node.x + node.width);
      maxY = max(maxY, node.y + node.height);
    }
    final canvasWidth = maxX + _padding;
    final canvasHeight = maxY + _padding;

    final edgeInfoMap = _buildEdgeInfoMap();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = max(canvasWidth, constraints.maxWidth);
        final totalHeight = max(canvasHeight, constraints.maxHeight);
        // Center the graph horizontally when viewport is wider
        final offsetX = max(0.0, (totalWidth - canvasWidth) / 2);

        return InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 5.0,
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              children: [
                // Edge layer (behind nodes)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EdgePainter(
                      graph: _graph,
                      edgeInfoMap: edgeInfoMap,
                      fallbackColor: Theme.of(context).colorScheme.primary,
                      offsetX: offsetX,
                    ),
                  ),
                ),
                // Node widgets
                for (var node in _graph.nodes)
                  if (widget.graph.getNodeById(node.key!.value as String) !=
                      null)
                    Positioned(
                      left: node.x + offsetX,
                      top: node.y,
                      child: SizedBox(
                        width: _nodeWidth,
                        height: _nodeHeight,
                        child: _buildNodeWidget(
                          widget.graph
                              .getNodeById(node.key!.value as String)!,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeWidget(WorkflowNode node) {
    final theme = Theme.of(context);
    final color = WorkflowGraphView.getNodeColor(node.nodeType);
    final icon = WorkflowGraphView.getNodeIcon(node.nodeType);

    return InkWell(
      onTap: () => widget.onNodeTap?.call(node.nodeId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: color,
            ),
            const SizedBox(height: 6),
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

}

/// Edge metadata for the painter.
class _EdgeInfo {
  final WorkflowEdgeType type;
  final String label;
  final Color color;

  const _EdgeInfo({required this.type, required this.label, required this.color});
}

/// Custom painter that draws edges from bottom-center of source node
/// to top-center of target node with a smooth cubic bezier curve.
/// Edges are color-coded by type and labeled at the midpoint.
class _EdgePainter extends CustomPainter {
  final Graph graph;
  final Map<String, _EdgeInfo> edgeInfoMap;
  final Color fallbackColor;
  final double offsetX;

  _EdgePainter({
    required this.graph,
    required this.edgeInfoMap,
    required this.fallbackColor,
    this.offsetX = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var edge in graph.edges) {
      final src = edge.source;
      final dst = edge.destination;

      // Look up edge type info
      final srcId = src.key!.value as String;
      final dstId = dst.key!.value as String;
      final info = edgeInfoMap['$srcId->$dstId'];
      final edgeColor = info?.color ?? fallbackColor;

      final linePaint = Paint()
        ..color = edgeColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final arrowPaint = Paint()
        ..color = edgeColor
        ..style = PaintingStyle.fill;

      // Bottom-center of source
      final startX = src.x + src.width / 2 + offsetX;
      final startY = src.y + src.height;

      // Top-center of target
      final endX = dst.x + dst.width / 2 + offsetX;
      final endY = dst.y;

      // Smooth cubic bezier with control points at the midpoint height
      final midY = (startY + endY) / 2;
      final path = Path()
        ..moveTo(startX, startY)
        ..cubicTo(startX, midY, endX, midY, endX, endY);

      canvas.drawPath(path, linePaint);

      // Arrow head at target top
      final arrowPath = Path()
        ..moveTo(endX, endY)
        ..lineTo(endX - 5, endY - 8)
        ..lineTo(endX + 5, endY - 8)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      // Draw edge label at the curve midpoint
      if (info != null) {
        // The bezier midpoint (t=0.5) for our cubic is at ((startX+endX)/2, midY)
        final labelX = (startX + endX) / 2;
        final labelY = midY;

        final paragraphBuilder = ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: TextAlign.center,
            fontSize: 10,
          ),
        )
          ..pushStyle(ui.TextStyle(
            color: edgeColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ))
          ..addText(info.label);

        final paragraph = paragraphBuilder.build()
          ..layout(const ui.ParagraphConstraints(width: 80));

        // Background pill behind the label for readability
        final textWidth = paragraph.longestLine + 8;
        final textHeight = paragraph.height + 4;
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(labelX, labelY),
            width: textWidth,
            height: textHeight,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(
          bgRect,
          Paint()..color = const Color(0xE0121212), // dark background
        );
        canvas.drawRRect(
          bgRect,
          Paint()
            ..color = edgeColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        canvas.drawParagraph(
          paragraph,
          Offset(labelX - paragraph.longestLine / 2, labelY - paragraph.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.graph != graph ||
      old.edgeInfoMap != edgeInfoMap ||
      old.fallbackColor != fallbackColor ||
      old.offsetX != offsetX;
}
