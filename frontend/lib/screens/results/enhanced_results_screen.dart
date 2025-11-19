import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:innox_security/l10n/app_localizations.dart';
import '../../config/constants.dart';
import '../../models/scan_status.dart';
import '../../services/export_service.dart';
import '../../providers/api_provider.dart';
import 'detailed_report_screen.dart';

/// Enhanced results screen with charts and detailed breakdown
class EnhancedResultsScreen extends ConsumerStatefulWidget {
  final String scanId;
  final ScanStatusInfo? scanStatus;

  const EnhancedResultsScreen({
    super.key,
    required this.scanId,
    this.scanStatus,
  });

  @override
  ConsumerState<EnhancedResultsScreen> createState() => _EnhancedResultsScreenState();
}

class _EnhancedResultsScreenState extends ConsumerState<EnhancedResultsScreen> {
  Map<String, dynamic>? _results;
  bool _isLoading = true;
  String? _error;
  int _touchedIndex = -1;
  final _exportService = ExportService();

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
      final results = await apiService.getScanResults(widget.scanId);

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load results: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.scanResults),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResults,
            tooltip: AppLocalizations.of(context)!.shareResults,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context)!.export,
            onSelected: _handleExport,
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: 'json',
                child: Text(AppLocalizations.of(menuContext)!.exportAsJson),
              ),
              PopupMenuItem(
                value: 'html',
                child: Text(AppLocalizations.of(menuContext)!.exportAsHtml),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Text(AppLocalizations.of(menuContext)!.exportAsPdf),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(theme)
              : _buildResultsView(theme),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.errorLoadingResults, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadResults,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    final summary = _results?['summary'] ?? {};
    final results = _results?['results'] ?? {};
    final passed = results['passed'] ?? 0;
    final failed = results['failed'] ?? 0;
    final total = passed + failed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildSummaryCard(theme, summary, passed, failed, total),
          const SizedBox(height: AppConstants.defaultPadding),

          // Charts Section
          if (total > 0) ...[
            _buildChartsCard(theme, passed, failed, total),
            const SizedBox(height: AppConstants.defaultPadding),
          ],

          // Detailed Metrics
          _buildMetricsCard(theme, results),
          const SizedBox(height: AppConstants.defaultPadding),

          // Configuration Details
          _buildConfigCard(theme, _results?['config'] ?? {}),
          const SizedBox(height: AppConstants.defaultPadding),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, Map<String, dynamic> summary, int passed, int failed, int total) {
    final status = ScanStatus.values.firstWhere(
      (s) => s.name == (summary['status'] ?? 'completed'),
      orElse: () => ScanStatus.completed,
    );
    final passRate = summary['pass_rate'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(theme, status),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan ${status.displayName}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (summary['error_message'] != null)
                        Text(
                          summary['error_message'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    AppLocalizations.of(context)!.passRate,
                    '${passRate.toStringAsFixed(1)}%',
                    Icons.check_circle,
                    _getPassRateColor(passRate),
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    AppLocalizations.of(context)!.totalTests,
                    total.toString(),
                    Icons.assignment,
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildChartsCard(ThemeData theme, int passed, int failed, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Results Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Pie Chart
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: Colors.green,
                            value: passed.toDouble(),
                            title: passed.toString(),
                            radius: _touchedIndex == 0 ? 60 : 50,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.red,
                            value: failed.toDouble(),
                            title: failed.toString(),
                            radius: _touchedIndex == 1 ? 60 : 50,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Legend
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(AppLocalizations.of(context)!.passed, passed, Colors.green),
                        const SizedBox(height: 12),
                        _buildLegendItem(AppLocalizations.of(context)!.failed, failed, Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('$label: $value'),
      ],
    );
  }

  Widget _buildMetricsCard(ThemeData theme, Map<String, dynamic> results) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Metrics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(Icons.check_circle, 'Tests Passed', results['passed'].toString(), Colors.green),
            const SizedBox(height: 8),
            _buildMetricRow(Icons.error, 'Tests Failed', results['failed'].toString(), Colors.red),
            const SizedBox(height: 8),
            _buildMetricRow(Icons.science, 'Total Probes', results['total_probes'].toString(), theme.colorScheme.primary),
            const SizedBox(height: 8),
            _buildMetricRow(Icons.done_all, 'Completed Probes', results['completed_probes'].toString(), theme.colorScheme.primary),
            if (_results?['duration'] != null) ...[
              const SizedBox(height: 8),
              _buildMetricRow(Icons.timer, 'Duration', _formatDuration(_results!['duration']), theme.colorScheme.secondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(ThemeData theme, Map<String, dynamic> config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Configuration',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildConfigRow('Target Type', config['target_type']?.toString() ?? 'N/A'),
            _buildConfigRow('Model', config['target_name']?.toString() ?? 'N/A'),
            _buildConfigRow('Probes', (config['probes'] as List?)?.join(', ') ?? 'N/A'),
            _buildConfigRow('Generations', config['generations']?.toString() ?? 'N/A'),
            _buildConfigRow('Threshold', config['eval_threshold']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: Text(AppLocalizations.of(context)!.backToHome),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _viewDetailedReport,
            icon: const Icon(Icons.article),
            label: Text(AppLocalizations.of(context)!.detailedReport),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(ScanStatus status) {
    switch (status) {
      case ScanStatus.pending:
        return Icons.pending;
      case ScanStatus.running:
        return Icons.play_circle;
      case ScanStatus.completed:
        return Icons.check_circle;
      case ScanStatus.failed:
        return Icons.error;
      case ScanStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(ThemeData theme, ScanStatus status) {
    switch (status) {
      case ScanStatus.pending:
        return Colors.orange;
      case ScanStatus.running:
        return theme.colorScheme.primary;
      case ScanStatus.completed:
        return Colors.green;
      case ScanStatus.failed:
        return Colors.red;
      case ScanStatus.cancelled:
        return Colors.grey;
    }
  }

  Color _getPassRateColor(double passRate) {
    if (passRate >= 80) return Colors.green;
    if (passRate >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Future<void> _shareResults() async {
    if (_results == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Preparing to share...'),
            ],
          ),
        ),
      );

      // Share as JSON by default
      await _exportService.shareResults(_results!, widget.scanId, 'json');

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleExport(String format) async {
    if (_results == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text('Exporting as $format...'),
            ],
          ),
        ),
      );

      String filePath;
      switch (format.toLowerCase()) {
        case 'json':
          filePath = await _exportService.exportAsJson(_results!, widget.scanId);
          break;
        case 'html':
          filePath = await _exportService.exportAsHtml(_results!, widget.scanId);
          break;
        case 'pdf':
          filePath = await _exportService.exportAsPdf(_results!, widget.scanId);
          break;
        default:
          throw Exception('Unsupported format');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show success dialog
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(AppLocalizations.of(dialogContext)!.exportSuccessful),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File saved to:'),
                const SizedBox(height: 8),
                SelectableText(
                  filePath,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(dialogContext)!.ok),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _viewDetailedReport() async {
    if (_results == null) return;

    // Navigate to detailed report screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedReportScreen(scanId: widget.scanId),
      ),
    );
  }

  Future<void> _openHtmlReport() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final reportUrl = Uri.parse('${apiService.baseUrl}/scan/${widget.scanId}/report/html');

      if (await canLaunchUrl(reportUrl)) {
        await launchUrl(reportUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open HTML report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOutputLinesDialog() {
    final outputLines = _results!['output_lines'] as List?;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(dialogContext)!.detailedScanReport),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ),
          body: outputLines != null && outputLines.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: outputLines.length,
                  itemBuilder: (context, index) {
                    final line = outputLines[index].toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: _getLogLineColor(line),
                        ),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No detailed report available'),
                      SizedBox(height: 8),
                      Text(
                        'HTML report was not generated',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Color? _getLogLineColor(String line) {
    final lowerLine = line.toLowerCase();
    if (lowerLine.contains('error') || lowerLine.contains('failed')) {
      return Colors.red[300];
    } else if (lowerLine.contains('warning')) {
      return Colors.orange[300];
    } else if (lowerLine.contains('success') || lowerLine.contains('passed')) {
      return Colors.green[300];
    } else if (lowerLine.contains('probes.')) {
      return Colors.blue[300];
    }
    return null;
  }
}
