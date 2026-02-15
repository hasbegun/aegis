import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/workflow/workflow_graph_view.dart';
import '../../models/workflow/workflow_node.dart';
import '../../models/workflow/workflow_edge.dart';
import '../../models/workflow/workflow_graph.dart';

/// Screen for viewing workflow visualization
class WorkflowViewerScreen extends ConsumerStatefulWidget {
  final String scanId;

  const WorkflowViewerScreen({
    super.key,
    required this.scanId,
  });

  @override
  ConsumerState<WorkflowViewerScreen> createState() =>
      _WorkflowViewerScreenState();
}

enum _ViewMode { graph, timeline }

class _WorkflowViewerScreenState extends ConsumerState<WorkflowViewerScreen> {
  _ViewMode _viewMode = _ViewMode.graph;
  Set<WorkflowNodeType> _visibleTypes = WorkflowNodeType.values.toSet();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(workflowProvider(widget.scanId).notifier).loadWorkflow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowProvider(widget.scanId));
    return _buildBody(state);
  }

  Widget _buildBody(WorkflowState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading workflow...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading workflow',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(workflowProvider(widget.scanId).notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!state.hasData || state.graph == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No workflow data available',
              style: TextStyle(
                fontSize: 16,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Workflow data will be available after a scan completes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Statistics bar with export button
        _buildStatisticsBar(state),
        // Legend + filter chips
        _buildLegendAndFilters(),
        // View toggle
        _buildViewToggle(),
        // Main content
        Expanded(
          child: _viewMode == _ViewMode.graph
              ? WorkflowGraphView(
                  graph: state.graph!.filtered(_visibleTypes),
                  onNodeTap: _showNodeDetails,
                )
              : _buildTimelineView(state),
        ),
      ],
    );
  }

  // ── Statistics bar ──────────────────────────────────────────────

  Widget _buildStatisticsBar(WorkflowState state) {
    final graph = state.graph!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'Nodes',
                  graph.nodes.length.toString(),
                  Icons.account_tree_outlined,
                ),
                _buildStat(
                  'Edges',
                  graph.edges.length.toString(),
                  Icons.arrow_forward,
                ),
                _buildStat(
                  'Interactions',
                  graph.totalInteractions.toString(),
                  Icons.swap_horiz,
                ),
                _buildStat(
                  'Vulnerabilities',
                  graph.vulnerabilitiesFound.toString(),
                  Icons.warning,
                  color: graph.hasVulnerabilities
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Export button
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            tooltip: 'Export workflow',
            onSelected: _handleExport,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mermaid',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Copy as Mermaid'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'json',
                child: ListTile(
                  leading: Icon(Icons.data_object),
                  title: Text('Copy as JSON'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ── Legend + filter chips ────────────────────────────────────────

  Widget _buildLegendAndFilters() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: WorkflowNodeType.values.map((type) {
          final color = WorkflowGraphView.getNodeColor(type);
          final label = WorkflowGraphView.getNodeTypeLabel(type);
          final icon = WorkflowGraphView.getNodeIcon(type);
          final selected = _visibleTypes.contains(type);

          return FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(icon, size: 16, color: selected ? color : Colors.grey),
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            selectedColor: color.withOpacity(0.15),
            side: BorderSide(
              color: selected ? color : Colors.grey.withOpacity(0.3),
            ),
            onSelected: (value) {
              setState(() {
                if (value) {
                  _visibleTypes.add(type);
                } else {
                  // Don't allow deselecting all
                  if (_visibleTypes.length > 1) {
                    _visibleTypes.remove(type);
                  }
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  // ── View toggle ─────────────────────────────────────────────────

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(
                value: _ViewMode.graph,
                icon: Icon(Icons.account_tree, size: 18),
                label: Text('Graph'),
              ),
              ButtonSegment(
                value: _ViewMode.timeline,
                icon: Icon(Icons.timeline, size: 18),
                label: Text('Timeline'),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (selected) {
              setState(() => _viewMode = selected.first);
              if (selected.first == _ViewMode.timeline) {
                ref
                    .read(workflowProvider(widget.scanId).notifier)
                    .loadTimeline();
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),
          if (_visibleTypes.length < WorkflowNodeType.values.length)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _visibleTypes = WorkflowNodeType.values.toSet();
                });
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Show all', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ── Timeline view ───────────────────────────────────────────────

  Widget _buildTimelineView(WorkflowState state) {
    final timeline = state.timeline;
    if (timeline == null || timeline.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No timeline data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final event = timeline[index];
        return _buildTimelineEvent(event, isLast: index == timeline.length - 1);
      },
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event, {bool isLast = false}) {
    final theme = Theme.of(context);
    final eventType = event['event_type'] as String? ?? 'unknown';
    final description = event['description'] as String? ?? '';
    final timestamp = event['timestamp'] as num?;
    final details = event['details'] as Map<String, dynamic>?;

    final color = _getTimelineEventColor(eventType);
    final icon = _getTimelineEventIcon(eventType);

    final time = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt())
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (time != null)
                        Text(
                          '${time.hour.toString().padLeft(2, '0')}:'
                          '${time.minute.toString().padLeft(2, '0')}:'
                          '${time.second.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: details.entries
                            .where((e) => e.value != null && e.value.toString().isNotEmpty)
                            .take(4)
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '${e.key}: ${e.value}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTimelineEventColor(String eventType) {
    switch (eventType) {
      case 'probe_start':
      case 'probe_complete':
        return Colors.blue;
      case 'generation':
        return Colors.green;
      case 'detection':
        return Colors.orange;
      case 'response':
        return Colors.purple;
      case 'vulnerability':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTimelineEventIcon(String eventType) {
    switch (eventType) {
      case 'probe_start':
        return Icons.play_arrow;
      case 'probe_complete':
        return Icons.check_circle_outline;
      case 'generation':
        return Icons.settings;
      case 'detection':
        return Icons.radar;
      case 'response':
        return Icons.psychology;
      case 'vulnerability':
        return Icons.warning;
      default:
        return Icons.circle_outlined;
    }
  }

  // ── Node details dialog ─────────────────────────────────────────

  void _showNodeDetails(String nodeId) {
    final graph = ref.read(workflowProvider(widget.scanId)).graph;
    final node = graph?.getNodeById(nodeId);

    if (node == null || graph == null) return;

    final color = WorkflowGraphView.getNodeColor(node.nodeType);
    final icon = WorkflowGraphView.getNodeIcon(node.nodeType);
    final incomingEdges = graph.getIncomingEdges(nodeId);
    final outgoingEdges = graph.getOutgoingEdges(nodeId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    WorkflowGraphView.getNodeTypeLabel(node.nodeType),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (node.description != null) ...[
                  Text(
                    node.description!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Metadata fields
                ..._buildMetadataRows(node.metadata),

                // Timestamp
                _buildDetailRow(
                  'Timestamp',
                  node.dateTime.toIso8601String(),
                ),

                const SizedBox(height: 12),

                // Incoming edges
                if (incomingEdges.isNotEmpty) ...[
                  _buildEdgeSection(
                    'Incoming',
                    incomingEdges,
                    graph,
                    isIncoming: true,
                  ),
                  const SizedBox(height: 8),
                ],

                // Outgoing edges
                if (outgoingEdges.isNotEmpty)
                  _buildEdgeSection(
                    'Outgoing',
                    outgoingEdges,
                    graph,
                    isIncoming: false,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMetadataRows(Map<String, dynamic> metadata) {
    // Show well-known keys with nice labels
    final knownKeys = {
      'status': 'Status',
      'progress': 'Progress',
      'passed': 'Passed',
      'failed': 'Failed',
      'model': 'Model',
      'severity': 'Severity',
      'score': 'Score',
      'probe_name': 'Probe',
      'detector_name': 'Detector',
      'generator_name': 'Generator',
      'total_attempts': 'Total Attempts',
      'pass_rate': 'Pass Rate',
      'fail_rate': 'Fail Rate',
    };

    final widgets = <Widget>[];
    final shown = <String>{};

    for (final entry in knownKeys.entries) {
      if (metadata.containsKey(entry.key) && metadata[entry.key] != null) {
        final value = metadata[entry.key];
        final display = value is double
            ? value.toStringAsFixed(2)
            : value.toString();
        if (display.isNotEmpty) {
          // Special handling for severity
          if (entry.key == 'severity') {
            widgets.add(_buildSeverityRow(display));
          } else {
            widgets.add(_buildDetailRow(entry.value, display));
          }
          shown.add(entry.key);
        }
      }
    }

    // Show remaining keys
    for (final entry in metadata.entries) {
      if (!shown.contains(entry.key) && entry.value != null) {
        final display = entry.value.toString();
        if (display.isNotEmpty && display != '{}' && display != '[]') {
          widgets.add(_buildDetailRow(
            entry.key.replaceAll('_', ' '),
            display,
          ));
        }
      }
    }

    return widgets;
  }

  Widget _buildSeverityRow(String severity) {
    Color badgeColor;
    switch (severity.toLowerCase()) {
      case 'critical':
        badgeColor = Colors.red.shade700;
        break;
      case 'high':
        badgeColor = Colors.red;
        break;
      case 'medium':
        badgeColor = Colors.orange;
        break;
      case 'low':
        badgeColor = Colors.yellow.shade700;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              'Severity:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor),
            ),
            child: Text(
              severity.toUpperCase(),
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeSection(
    String title,
    List<WorkflowEdge> edges,
    WorkflowGraph graph, {
    required bool isIncoming,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title connections (${edges.length})',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        ...edges.map((edge) {
          final edgeColor = WorkflowGraphView.getEdgeColor(edge.edgeType);
          final otherNodeId = isIncoming ? edge.sourceId : edge.targetId;
          final otherNode = graph.getNodeById(otherNodeId);
          final otherName = otherNode?.name ?? otherNodeId;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: edgeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: edgeColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isIncoming ? Icons.arrow_back : Icons.arrow_forward,
                  size: 14,
                  color: edgeColor,
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: edgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    edge.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: edgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    otherName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  // ── Export ───────────────────────────────────────────────────────

  Future<void> _handleExport(String format) async {
    final notifier = ref.read(workflowProvider(widget.scanId).notifier);
    final data = await notifier.exportWorkflow(format);

    if (!mounted) return;

    if (data != null) {
      await Clipboard.setData(ClipboardData(text: data));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workflow copied as ${format.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export workflow'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
