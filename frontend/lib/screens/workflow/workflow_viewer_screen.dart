import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/workflow/workflow_graph_view.dart';
import '../../models/workflow/workflow_node.dart';

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

class _WorkflowViewerScreenState extends ConsumerState<WorkflowViewerScreen> {
  @override
  void initState() {
    super.initState();
    // Load workflow data on init
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
        // Statistics bar
        _buildStatisticsBar(state),
        // Graph view
        Expanded(
          child: WorkflowGraphView(
            graph: state.graph!,
            onNodeTap: _showNodeDetails,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsBar(WorkflowState state) {
    final graph = state.graph!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
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

  void _showNodeDetails(String nodeId) {
    final graph = ref.read(workflowProvider(widget.scanId)).graph;
    final node = graph?.getNodeById(nodeId);

    if (node == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getNodeIcon(node.nodeType)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Type', node.nodeType.name),
              if (node.description != null)
                _buildDetailRow('Description', node.description!),
              _buildDetailRow(
                'Timestamp',
                node.dateTime.toIso8601String(),
              ),
              const SizedBox(height: 12),
              Text(
                'Metadata:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  node.metadata.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
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

  Future<void> _handleExport(String format) async {
    final notifier = ref.read(workflowProvider(widget.scanId).notifier);
    final data = await notifier.exportWorkflow(format);

    if (!mounted) return;

    if (data != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Export as $format'),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                data,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
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
