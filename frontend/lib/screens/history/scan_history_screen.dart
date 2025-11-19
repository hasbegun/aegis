import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:innox_security/l10n/app_localizations.dart';
import '../../config/constants.dart';
import '../../providers/api_provider.dart';
import '../results/enhanced_results_screen.dart';

class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  List<Map<String, dynamic>>? _scanHistory;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final history = await apiService.getScanHistory();

      setState(() {
        _scanHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAndSortedScans {
    if (_scanHistory == null) return [];

    var scans = _scanHistory!;

    if (_searchQuery.isNotEmpty) {
      scans = scans.where((scan) {
        final scanId = scan['scan_id']?.toString().toLowerCase() ?? '';
        final targetName = scan['target_name']?.toString().toLowerCase() ?? '';
        final status = scan['status']?.toString().toLowerCase() ?? '';
        return scanId.contains(_searchQuery) ||
               targetName.contains(_searchQuery) ||
               status.contains(_searchQuery);
      }).toList();
    }

    scans.sort((a, b) {
      switch (_sortBy) {
        case 'date':
          final dateA = DateTime.tryParse(a['started_at'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['started_at'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        case 'status':
          return (a['status']?.toString() ?? '').compareTo(b['status']?.toString() ?? '');
        case 'name':
          return (a['target_name']?.toString() ?? '').compareTo(b['target_name']?.toString() ?? '');
        default:
          return 0;
      }
    });

    return scans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: l10n.refresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'date', child: Text(l10n.sortByDate)),
              PopupMenuItem(value: 'status', child: Text(l10n.sortByStatus)),
              PopupMenuItem(value: 'name', child: Text(l10n.sortByName)),
            ],
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(l10n.failedToLoadScanHistory),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_scanHistory == null || _scanHistory!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(l10n.noScanHistory, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.noScanHistoryMessage, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    final filteredScans = _filteredAndSortedScans;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.searchScans,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: filteredScans.isEmpty
              ? const Center(child: Text('No matching scans'))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: filteredScans.length,
                  itemBuilder: (context, index) => _buildScanCard(theme, filteredScans[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildScanCard(ThemeData theme, Map<String, dynamic> scan) {
    final scanId = scan['scan_id'] as String?;
    final targetName = scan['target_name'] as String? ?? 'Unknown';
    final status = scan['status'] as String? ?? 'unknown';
    final startedAt = scan['started_at'] as String?;
    final passed = scan['passed'] as int? ?? 0;
    final failed = scan['failed'] as int? ?? 0;
    final total = passed + failed;

    final startDate = startedAt != null ? DateTime.tryParse(startedAt) : null;
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: InkWell(
        onTap: scanId != null && status == 'completed'
            ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => EnhancedResultsScreen(scanId: scanId)))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getStatusIcon(status), color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(targetName, style: theme.textTheme.titleMedium)),
                  Chip(label: Text(status.toUpperCase()), labelStyle: theme.textTheme.labelSmall, backgroundColor: statusColor.withValues(alpha: 0.1)),
                ],
              ),
              if (scanId != null) ...[
                const SizedBox(height: 8),
                Text(scanId, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              ],
              if (startDate != null) ...[
                const SizedBox(height: 8),
                Text(DateFormat('MMM d, y HH:mm').format(startDate), style: theme.textTheme.bodySmall),
              ],
              if (status == 'completed' && total > 0) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildResultBadge(theme, 'PASS', passed, total, Colors.green),
                    const SizedBox(width: 8),
                    _buildResultBadge(theme, 'FAIL', failed, total, Colors.red),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBadge(ThemeData theme, String label, int count, int total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text('$count/$total', style: theme.textTheme.labelSmall?.copyWith(color: color)),
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'running':
        return Icons.pending;
      case 'failed':
      case 'error':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
