import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/api_provider.dart';
import '../../widgets/attempt_card.dart';
import '../../widgets/breadcrumb_nav.dart';

/// Detail screen for a single probe showing security context and individual attempts
class ProbeDetailScreen extends ConsumerStatefulWidget {
  final String scanId;
  final String probeClassname;

  const ProbeDetailScreen({
    super.key,
    required this.scanId,
    required this.probeClassname,
  });

  @override
  ConsumerState<ProbeDetailScreen> createState() => _ProbeDetailScreenState();
}

class _ProbeDetailScreenState extends ConsumerState<ProbeDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  String? _statusFilter;
  late TabController _tabController;

  // Stable counts from the initial unfiltered load
  int? _totalCount;
  int? _failedCount;
  int? _passedCount;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final filters = [null, 'failed', 'passed'];
        _loadAttempts(statusFilter: filters[_tabController.index]);
      }
    });
    _loadAttempts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttempts({String? statusFilter}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _statusFilter = statusFilter;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getProbeAttempts(
        widget.scanId,
        widget.probeClassname,
        status: statusFilter,
        pageSize: 100,
      );

      // Capture stable counts from the initial unfiltered load
      if (statusFilter == null) {
        final attempts = result['attempts'] as List? ?? [];
        _totalCount = result['total_attempts'] as int? ?? attempts.length;
        _failedCount = attempts.where((a) => a['status'] == 'failed').length;
        _passedCount = attempts.where((a) => a['status'] == 'passed').length;
      }

      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attempts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortName = widget.probeClassname.split('.').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(shortName),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All${_getTabCount(null)}'),
            Tab(text: 'Failed${_getTabCount('failed')}'),
            Tab(text: 'Passed${_getTabCount('passed')}'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Breadcrumbs
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
                BreadcrumbPaths.results(scanId: widget.scanId),
                BreadcrumbPaths.probeDetail(widget.probeClassname),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView(theme)
                    : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  String _getTabCount(String? filter) {
    if (filter == null) {
      return _totalCount != null ? ' ($_totalCount)' : '';
    } else if (filter == 'failed') {
      return _failedCount != null ? ' ($_failedCount)' : '';
    } else if (filter == 'passed') {
      return _passedCount != null ? ' ($_passedCount)' : '';
    }
    return '';
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
            onPressed: () => _loadAttempts(statusFilter: _statusFilter),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final security = _data!['security'] as Map<String, dynamic>? ?? {};
    final attempts = (_data!['attempts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAttemptsList(theme, security, attempts),
        _buildAttemptsList(theme, security, attempts),
        _buildAttemptsList(theme, security, attempts),
      ],
    );
  }

  Widget _buildAttemptsList(
    ThemeData theme,
    Map<String, dynamic> security,
    List<Map<String, dynamic>> attempts,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Security context card
        _buildSecurityCard(theme, security),
        const SizedBox(height: 16),

        // Attempts header
        Text(
          '${attempts.length} attempt${attempts.length == 1 ? '' : 's'}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Attempt cards
        if (attempts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No attempts found',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...attempts.asMap().entries.map((entry) {
            return AttemptCard(
              attempt: entry.value,
              index: entry.key,
            );
          }),
      ],
    );
  }

  Widget _buildSecurityCard(ThemeData theme, Map<String, dynamic> security) {
    final severity = security['severity'] as String? ?? 'info';
    final description = security['description'] as String? ?? '';
    final riskExplanation = security['risk_explanation'] as String? ?? '';
    final mitigation = security['mitigation'] as String? ?? '';
    final cweIds = (security['cwe_ids'] as List?)?.cast<String>() ?? [];
    final owaspLlm = (security['owasp_llm'] as List?)?.cast<String>() ?? [];
    final severityColor = _getSeverityColor(severity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.shield, color: severityColor),
                const SizedBox(width: 8),
                Text(
                  'Security Context',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSecuritySection(theme, 'What is this vulnerability?', description, Icons.help_outline),
            ],

            if (riskExplanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSecuritySection(theme, 'Risk', riskExplanation, Icons.warning_amber),
            ],

            if (mitigation.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSecuritySection(theme, 'Mitigation', mitigation, Icons.security),
            ],

            // References
            if (cweIds.isNotEmpty || owaspLlm.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...cweIds.map((id) => Chip(
                        label: Text(id, style: const TextStyle(fontSize: 11)),
                        avatar: const Icon(Icons.link, size: 14),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      )),
                  ...owaspLlm.map((ref) => Chip(
                        label: Text(ref, style: const TextStyle(fontSize: 11)),
                        avatar: const Icon(Icons.policy, size: 14),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.purple.withValues(alpha: 0.1),
                      )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(ThemeData theme, String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: theme.textTheme.bodyMedium,
        ),
      ],
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
