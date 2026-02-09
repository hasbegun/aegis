import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/api_provider.dart';
import 'probe_detail_screen.dart';

/// Scrollable list of probes with pass/fail breakdown and security metadata
class ProbeListView extends ConsumerStatefulWidget {
  final String scanId;

  const ProbeListView({super.key, required this.scanId});

  @override
  ConsumerState<ProbeListView> createState() => _ProbeListViewState();
}

class _ProbeListViewState extends ConsumerState<ProbeListView> {
  List<Map<String, dynamic>> _probes = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProbes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProbes({String? filter}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getProbeDetails(
        widget.scanId,
        probeFilter: filter,
        pageSize: 200,
      );

      setState(() {
        _probes = (result['probes'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load probes: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Filter probes...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadProbes();
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _loadProbes(filter: value);
              } else {
                _loadProbes();
              }
            },
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView(theme)
                  : _probes.isEmpty
                      ? _buildEmptyView(theme)
                      : _buildProbeList(theme),
        ),
      ],
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _loadProbes(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No probe results found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProbeList(ThemeData theme) {
    // Filter locally if search query present but not submitted
    final filtered = _searchQuery.isNotEmpty
        ? _probes.where((p) {
            final name = (p['probe_classname'] as String? ?? '').toLowerCase();
            final cat = (p['category'] as String? ?? '').toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || cat.contains(q);
          }).toList()
        : _probes;

    return RefreshIndicator(
      onRefresh: () => _loadProbes(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: filtered.length + 1, // +1 for summary header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSummaryHeader(theme, filtered);
          }
          return _buildProbeCard(theme, filtered[index - 1]);
        },
      ),
    );
  }

  Widget _buildSummaryHeader(ThemeData theme, List<Map<String, dynamic>> probes) {
    final totalFailed = probes.where((p) => (p['failed'] as int? ?? 0) > 0).length;
    final totalPassed = probes.where((p) => (p['failed'] as int? ?? 0) == 0).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '${probes.length} probes',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          if (totalFailed > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$totalFailed with failures',
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (totalPassed > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$totalPassed all passed',
                style: const TextStyle(fontSize: 11, color: Colors.green),
              ),
            ),
          const Spacer(),
          Text(
            'Worst first',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbeCard(ThemeData theme, Map<String, dynamic> probe) {
    final className = probe['probe_classname'] as String? ?? 'unknown';
    final shortName = className.split('.').last;
    final category = probe['category'] as String? ?? '';
    final passed = probe['passed'] as int? ?? 0;
    final failed = probe['failed'] as int? ?? 0;
    final total = probe['total'] as int? ?? 0;
    final passRate = (probe['pass_rate'] as num?)?.toDouble() ?? 0.0;
    final goal = probe['goal'] as String?;
    final security = probe['security'] as Map<String, dynamic>? ?? {};
    final severity = security['severity'] as String? ?? 'info';

    final severityColor = _getSeverityColor(severity);
    final hasFailures = failed > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProbeDetailScreen(
                scanId: widget.scanId,
                probeClassname: className,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + severity + pass rate
              Row(
                children: [
                  // Severity indicator
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                severity.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: severityColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Pass rate badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${passRate.toStringAsFixed(0)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasFailures ? Colors.red : Colors.green,
                        ),
                      ),
                      Text(
                        '$passed/$total passed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Pass/fail progress bar
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? passed / total : 0,
                  backgroundColor: Colors.red.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                  minHeight: 6,
                ),
              ),

              // Goal text
              if (goal != null && goal.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  goal,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
