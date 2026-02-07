import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../providers/api_provider.dart';
import '../../widgets/breadcrumb_nav.dart';

/// Screen for comparing two scan results side by side
class ScanComparisonScreen extends ConsumerStatefulWidget {
  final String scanIdA;
  final String scanIdB;
  final String? labelA;
  final String? labelB;

  const ScanComparisonScreen({
    super.key,
    required this.scanIdA,
    required this.scanIdB,
    this.labelA,
    this.labelB,
  });

  @override
  ConsumerState<ScanComparisonScreen> createState() => _ScanComparisonScreenState();
}

class _ScanComparisonScreenState extends ConsumerState<ScanComparisonScreen> {
  Map<String, dynamic>? _resultsA;
  Map<String, dynamic>? _resultsB;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);

      // Load both results in parallel
      final futures = await Future.wait([
        apiService.getScanResults(widget.scanIdA),
        apiService.getScanResults(widget.scanIdB),
      ]);

      setState(() {
        _resultsA = futures[0];
        _resultsB = futures[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load scan results: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Scans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _swapScans,
            tooltip: 'Swap scans',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResults,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb navigation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: BreadcrumbNav(
              items: [
                BreadcrumbPaths.home(context),
                BreadcrumbPaths.history(context),
                BreadcrumbPaths.compare(),
              ],
            ),
          ),
          // Main content
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  void _swapScans() {
    // Navigate to new comparison with swapped IDs
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScanComparisonScreen(
          scanIdA: widget.scanIdB,
          scanIdB: widget.scanIdA,
          labelA: widget.labelB,
          labelB: widget.labelA,
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading scan results...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading results', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan headers
          _buildScanHeaders(theme),
          const SizedBox(height: 24),

          // Pass rate comparison
          _buildPassRateComparison(theme),
          const SizedBox(height: 16),

          // Key metrics comparison
          _buildMetricsComparison(theme),
          const SizedBox(height: 16),

          // Configuration comparison
          _buildConfigComparison(theme),
          const SizedBox(height: 16),

          // Probe results comparison (if available)
          _buildProbeComparison(theme),
        ],
      ),
    );
  }

  Widget _buildScanHeaders(ThemeData theme) {
    final configA = _resultsA?['config'] ?? {};
    final configB = _resultsB?['config'] ?? {};
    final summaryA = _resultsA?['summary'] ?? {};
    final summaryB = _resultsB?['summary'] ?? {};

    final targetNameA = configA['target_name']?.toString() ?? 'Unknown';
    final targetNameB = configB['target_name']?.toString() ?? 'Unknown';
    final statusA = summaryA['status']?.toString() ?? 'unknown';
    final statusB = summaryB['status']?.toString() ?? 'unknown';

    return Row(
      children: [
        Expanded(
          child: _buildScanHeader(
            theme,
            widget.labelA ?? 'Scan A',
            targetNameA,
            widget.scanIdA,
            statusA,
            Colors.blue,
          ),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Icon(
            Icons.compare_arrows,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: _buildScanHeader(
            theme,
            widget.labelB ?? 'Scan B',
            targetNameB,
            widget.scanIdB,
            statusB,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildScanHeader(
    ThemeData theme,
    String label,
    String targetName,
    String scanId,
    String status,
    Color accentColor,
  ) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: accentColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              targetName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              scanId.length > 16 ? '${scanId.substring(0, 16)}...' : scanId,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPassRateComparison(ThemeData theme) {
    final summaryA = _resultsA?['summary'] ?? {};
    final summaryB = _resultsB?['summary'] ?? {};
    final passRateA = (summaryA['pass_rate'] ?? 0.0).toDouble();
    final passRateB = (summaryB['pass_rate'] ?? 0.0).toDouble();
    final diff = passRateA - passRateB;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pass Rate Comparison',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPassRateDisplay(
                    theme,
                    passRateA,
                    Colors.blue,
                    diff > 0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Icon(
                        diff > 0
                            ? Icons.arrow_back
                            : diff < 0
                                ? Icons.arrow_forward
                                : Icons.remove,
                        color: diff == 0
                            ? Colors.grey
                            : diff > 0
                                ? Colors.blue
                                : Colors.purple,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        diff == 0
                            ? 'Equal'
                            : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: diff == 0
                              ? Colors.grey
                              : diff > 0
                                  ? Colors.blue
                                  : Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildPassRateDisplay(
                    theme,
                    passRateB,
                    Colors.purple,
                    diff < 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassRateDisplay(
    ThemeData theme,
    double passRate,
    Color accentColor,
    bool isBetter,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: passRate / 100,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getPassRateColor(passRate),
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  '${passRate.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getPassRateColor(passRate),
                  ),
                ),
                if (isBetter)
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 16,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsComparison(ThemeData theme) {
    final resultsA = _resultsA?['results'] ?? {};
    final resultsB = _resultsB?['results'] ?? {};

    final metrics = [
      _ComparisonMetric(
        'Tests Passed',
        Icons.check_circle,
        resultsA['passed'] ?? 0,
        resultsB['passed'] ?? 0,
        Colors.green,
        higherIsBetter: true,
      ),
      _ComparisonMetric(
        'Tests Failed',
        Icons.error,
        resultsA['failed'] ?? 0,
        resultsB['failed'] ?? 0,
        Colors.red,
        higherIsBetter: false,
      ),
      _ComparisonMetric(
        'Total Probes',
        Icons.science,
        resultsA['total_probes'] ?? 0,
        resultsB['total_probes'] ?? 0,
        theme.colorScheme.primary,
        higherIsBetter: null,
      ),
      _ComparisonMetric(
        'Completed Probes',
        Icons.done_all,
        resultsA['completed_probes'] ?? 0,
        resultsB['completed_probes'] ?? 0,
        theme.colorScheme.primary,
        higherIsBetter: null,
      ),
    ];

    // Add duration if available
    final durationA = _resultsA?['duration'];
    final durationB = _resultsB?['duration'];
    if (durationA != null || durationB != null) {
      metrics.add(_ComparisonMetric(
        'Duration',
        Icons.timer,
        durationA ?? 0,
        durationB ?? 0,
        theme.colorScheme.secondary,
        higherIsBetter: false,
        isDuration: true,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Key Metrics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...metrics.map((metric) => _buildMetricRow(theme, metric)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(ThemeData theme, _ComparisonMetric metric) {
    final valueA = metric.isDuration
        ? _formatDuration(metric.valueA.toDouble())
        : metric.valueA.toString();
    final valueB = metric.isDuration
        ? _formatDuration(metric.valueB.toDouble())
        : metric.valueB.toString();

    final numericA = metric.valueA is num ? (metric.valueA as num).toDouble() : 0.0;
    final numericB = metric.valueB is num ? (metric.valueB as num).toDouble() : 0.0;
    final diff = numericA - numericB;

    Widget? betterIndicator;
    if (metric.higherIsBetter != null && diff != 0) {
      betterIndicator = const Icon(
        Icons.star,
        size: 14,
        color: Colors.amber,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(metric.icon, size: 18, color: metric.color),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              metric.label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (metric.higherIsBetter != null && diff != 0 && (metric.higherIsBetter! ? diff > 0 : diff < 0))
                  betterIndicator ?? const SizedBox.shrink(),
                const SizedBox(width: 4),
                Text(
                  valueA,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: _buildDiffIndicator(diff, metric.higherIsBetter, metric.isDuration),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  valueB,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 4),
                if (metric.higherIsBetter != null && diff != 0 && (metric.higherIsBetter! ? diff < 0 : diff > 0))
                  betterIndicator ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffIndicator(double diff, bool? higherIsBetter, bool isDuration) {
    if (diff == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '=',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final isPositive = diff > 0;
    final diffText = isDuration
        ? _formatDurationDiff(diff)
        : '${isPositive ? '+' : ''}${diff.toInt()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        diffText,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildConfigComparison(ThemeData theme) {
    final configA = _resultsA?['config'] ?? {};
    final configB = _resultsB?['config'] ?? {};

    final configItems = [
      _ConfigComparisonItem('Target Type', configA['target_type'], configB['target_type']),
      _ConfigComparisonItem('Model', configA['target_name'], configB['target_name']),
      _ConfigComparisonItem('Generations', configA['generations'], configB['generations']),
      _ConfigComparisonItem('Threshold', configA['eval_threshold'], configB['eval_threshold']),
    ];

    // Compare probes
    final probesA = (configA['probes'] as List?)?.cast<String>() ?? [];
    final probesB = (configB['probes'] as List?)?.cast<String>() ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Configuration Comparison',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...configItems.map((item) => _buildConfigRow(theme, item)),
            const Divider(height: 24),
            _buildProbesComparison(theme, probesA, probesB),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(ThemeData theme, _ConfigComparisonItem item) {
    final valueA = item.valueA?.toString() ?? 'N/A';
    final valueB = item.valueB?.toString() ?? 'N/A';
    final isDifferent = valueA != valueB;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium,
                ),
                if (isDifferent) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                ],
              ],
            ),
          ),
          Expanded(
            child: Text(
              valueA,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isDifferent ? Colors.blue : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              valueB,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isDifferent ? Colors.purple : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbesComparison(ThemeData theme, List<String> probesA, List<String> probesB) {
    final setA = probesA.toSet();
    final setB = probesB.toSet();
    final common = setA.intersection(setB);
    final onlyA = setA.difference(setB);
    final onlyB = setB.difference(setA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Probes',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildProbeCountBadge('Common', common.length, Colors.grey),
            const SizedBox(width: 8),
            _buildProbeCountBadge('Only A', onlyA.length, Colors.blue),
            const SizedBox(width: 8),
            _buildProbeCountBadge('Only B', onlyB.length, Colors.purple),
          ],
        ),
        if (onlyA.isNotEmpty || onlyB.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (onlyA.isNotEmpty)
            _buildProbeList(theme, 'Only in Scan A', onlyA.toList(), Colors.blue),
          if (onlyB.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildProbeList(theme, 'Only in Scan B', onlyB.toList(), Colors.purple),
          ],
        ],
      ],
    );
  }

  Widget _buildProbeCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProbeList(ThemeData theme, String title, List<String> probes, Color color) {
    return ExpansionTile(
      title: Text(
        '$title (${probes.length})',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 16),
      children: probes.map((probe) {
        final parts = probe.split('.');
        final shortName = parts.length > 1 ? parts.last : probe;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shortName,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProbeComparison(ThemeData theme) {
    // This section could show per-probe results comparison if the digest data is available
    final digestA = _resultsA?['digest'] as Map<String, dynamic>?;
    final digestB = _resultsB?['digest'] as Map<String, dynamic>?;

    if (digestA == null && digestB == null) {
      return const SizedBox.shrink();
    }

    final allProbes = <String>{
      ...digestA?.keys ?? [],
      ...digestB?.keys ?? [],
    };

    if (allProbes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Per-Probe Results',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${allProbes.length} probes compared',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...allProbes.take(10).map((probe) {
              final dataA = digestA?[probe] as Map<String, dynamic>?;
              final dataB = digestB?[probe] as Map<String, dynamic>?;
              return _buildProbeResultRow(theme, probe, dataA, dataB);
            }),
            if (allProbes.length > 10) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '... and ${allProbes.length - 10} more probes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProbeResultRow(
    ThemeData theme,
    String probeName,
    Map<String, dynamic>? dataA,
    Map<String, dynamic>? dataB,
  ) {
    final parts = probeName.split('.');
    final shortName = parts.length > 1 ? parts.last : probeName;

    final passRateA = dataA?['pass_rate']?.toDouble();
    final passRateB = dataB?['pass_rate']?.toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              shortName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              passRateA != null ? '${passRateA.toStringAsFixed(0)}%' : '-',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: passRateA != null ? _getPassRateColor(passRateA) : Colors.grey,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              passRateB != null ? '${passRateB.toStringAsFixed(0)}%' : '-',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: passRateB != null ? _getPassRateColor(passRateB) : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'running':
        return Colors.blue;
      case 'failed':
      case 'error':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getPassRateColor(double passRate) {
    if (passRate >= 80) return Colors.green;
    if (passRate >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '-';
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  String _formatDurationDiff(double diffSeconds) {
    final absDiff = diffSeconds.abs();
    final sign = diffSeconds > 0 ? '+' : '-';

    if (absDiff >= 3600) {
      return '$sign${(absDiff / 3600).toStringAsFixed(1)}h';
    } else if (absDiff >= 60) {
      return '$sign${(absDiff / 60).toStringAsFixed(0)}m';
    } else {
      return '$sign${absDiff.toStringAsFixed(0)}s';
    }
  }
}

class _ComparisonMetric {
  final String label;
  final IconData icon;
  final dynamic valueA;
  final dynamic valueB;
  final Color color;
  final bool? higherIsBetter;
  final bool isDuration;

  _ComparisonMetric(
    this.label,
    this.icon,
    this.valueA,
    this.valueB,
    this.color, {
    this.higherIsBetter,
    this.isDuration = false,
  });
}

class _ConfigComparisonItem {
  final String label;
  final dynamic valueA;
  final dynamic valueB;

  _ConfigComparisonItem(this.label, this.valueA, this.valueB);
}
