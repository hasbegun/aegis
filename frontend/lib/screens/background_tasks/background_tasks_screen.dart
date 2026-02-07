import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/background_scans_provider.dart';
import '../../services/background_scan_service.dart';
import '../../widgets/empty_state_widget.dart';

/// Screen for managing and tracking background scans
class BackgroundTasksScreen extends ConsumerStatefulWidget {
  const BackgroundTasksScreen({super.key});

  @override
  ConsumerState<BackgroundTasksScreen> createState() => _BackgroundTasksScreenState();
}

class _BackgroundTasksScreenState extends ConsumerState<BackgroundTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scansAsync = ref.watch(backgroundScansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: [
              _buildTab('Active', scansAsync),
              _buildTab('Completed', scansAsync),
              _buildTab('Failed', scansAsync),
              _buildTab('All', scansAsync),
            ],
          ),
        ),
        actions: [
          // Cancel All button
          scansAsync.maybeWhen(
            data: (scans) {
              final activeScans = scans.where((s) => s.isActive).toList();
              if (activeScans.length >= 2) {
                return TextButton.icon(
                  onPressed: () => _showCancelAllDialog(activeScans.length),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel All'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search scans...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Scan list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScanList(scansAsync, _filterActiveScans),
                _buildScanList(scansAsync, _filterCompletedScans),
                _buildScanList(scansAsync, _filterFailedScans),
                _buildScanList(scansAsync, _filterAllScans),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, AsyncValue<List<BackgroundScan>> scansAsync) {
    final count = scansAsync.maybeWhen(
      data: (scans) {
        switch (label) {
          case 'Active':
            return _filterActiveScans(scans).length;
          case 'Completed':
            return _filterCompletedScans(scans).length;
          case 'Failed':
            return _filterFailedScans(scans).length;
          case 'All':
            return _filterAllScans(scans).length;
          default:
            return 0;
        }
      },
      orElse: () => 0,
    );

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanList(
    AsyncValue<List<BackgroundScan>> scansAsync,
    List<BackgroundScan> Function(List<BackgroundScan>) filter,
  ) {
    return scansAsync.when(
      data: (scans) {
        var filteredScans = filter(scans);

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          filteredScans = filteredScans.where((scan) {
            return scan.displayName.toLowerCase().contains(_searchQuery) ||
                scan.config.targetName.toLowerCase().contains(_searchQuery) ||
                scan.config.targetType.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (filteredScans.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh is handled automatically by the stream
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredScans.length,
            itemBuilder: (context, index) {
              return _buildEnhancedScanCard(filteredScans[index]);
            },
          ),
        );
      },
      loading: () => _buildEmptyState(), // Show empty state instead of spinner
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('Error loading scans'),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return const EmptyStateWidget(
        type: EmptyStateType.searchNoResults,
        title: 'No Matches Found',
        message: 'No scans match your search',
      );
    }

    switch (_tabController.index) {
      case 0:
        return const EmptyStateWidget(
          type: EmptyStateType.noActiveTasks,
          title: 'All Clear',
          message: 'No active scans running',
        );
      case 1:
        return const EmptyStateWidget(
          type: EmptyStateType.noCompletedTasks,
          title: 'No Completed Scans',
          message: 'Completed background scans will appear here',
        );
      case 2:
        return const EmptyStateWidget(
          type: EmptyStateType.noFailedTasks,
          title: 'No Failed Scans',
          message: 'Great! No scans have failed',
        );
      default:
        return const EmptyStateWidget(
          type: EmptyStateType.searchNoResults,
          title: 'No Scans Found',
          message: 'No scans to display',
        );
    }
  }

  Widget _buildEnhancedScanCard(BackgroundScan scan) {
    final theme = Theme.of(context);
    final isActive = scan.isActive;
    final isCompleted = scan.isCompleted;
    final hasFailed = scan.hasError;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Status icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(scan, theme).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(scan),
                    color: _getStatusColor(scan, theme),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Scan info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${scan.config.targetType} • ${scan.config.targetName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Quick cancel button for active scans
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    tooltip: 'Cancel scan',
                    onPressed: () => _showCancelDialog(scan),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Status line
            Row(
              children: [
                Icon(
                  _getStatusIcon(scan),
                  size: 16,
                  color: _getStatusColor(scan, theme),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(scan),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _getStatusColor(scan, theme),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _getElapsedTime(scan.startTime, isCompleted || hasFailed),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: scan.progress != null ? scan.progress! / 100 : (isActive ? null : (isCompleted ? 1.0 : 0.0)),
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(scan, theme),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Progress details with ETA
            if (scan.progress != null || scan.status?.estimatedRemaining != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    scan.progress != null
                        ? '${scan.progress!.toStringAsFixed(1)}% complete'
                        : 'Starting...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Show ETA and elapsed time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ETA
                      if (scan.status?.estimatedRemaining != null && scan.isActive) ...[
                        Icon(
                          Icons.hourglass_bottom,
                          size: 14,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ETA: ${scan.status!.estimatedRemaining}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      // Elapsed time from garak output
                      if (scan.status?.elapsedTime != null && scan.isActive) ...[
                        if (scan.status?.estimatedRemaining != null)
                          const SizedBox(width: 12),
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scan.status!.elapsedTime!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

            // Error message for failed scans
            if (hasFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scan.status?.status.toString().split('.').last ?? 'Scan failed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // View Details button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewScanDetails(scan),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                // Stop/View Results button
                if (isActive)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showCancelDialog(scan),
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop Scan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                    ),
                  )
                else if (isCompleted)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _viewResults(scan),
                      icon: const Icon(Icons.assessment_outlined, size: 18),
                      label: const Text('View Results'),
                    ),
                  )
                else if (hasFailed)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _retryCheck(scan),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Details'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Filter functions
  List<BackgroundScan> _filterActiveScans(List<BackgroundScan> scans) {
    return scans.where((s) => s.isActive).toList();
  }

  List<BackgroundScan> _filterCompletedScans(List<BackgroundScan> scans) {
    return scans.where((s) => s.isCompleted).toList();
  }

  List<BackgroundScan> _filterFailedScans(List<BackgroundScan> scans) {
    return scans.where((s) => s.hasError).toList();
  }

  List<BackgroundScan> _filterAllScans(List<BackgroundScan> scans) {
    return scans;
  }

  // Helper functions
  IconData _getStatusIcon(BackgroundScan scan) {
    if (scan.isCompleted) return Icons.check_circle;
    if (scan.hasError) return Icons.error;
    return Icons.sync;
  }

  Color _getStatusColor(BackgroundScan scan, ThemeData theme) {
    if (scan.isCompleted) return theme.colorScheme.tertiary;
    if (scan.hasError) return theme.colorScheme.error;
    return theme.colorScheme.primary;
  }

  String _getStatusText(BackgroundScan scan) {
    if (scan.isCompleted) return 'Completed';
    if (scan.hasError) return 'Failed';
    if (scan.isActive) return 'Running...';
    return 'Unknown';
  }

  String _getElapsedTime(DateTime startTime, bool isFinished) {
    final elapsed = DateTime.now().difference(startTime);

    if (isFinished) {
      final now = DateTime.now();
      final diff = now.difference(startTime);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    }

    // For running scans, show elapsed time
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
    } else {
      return '${elapsed.inSeconds}s';
    }
  }

  // Action handlers
  Future<void> _showCancelDialog(BackgroundScan scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Scan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will stop "${scan.displayName}".'),
            const SizedBox(height: 12),
            if (scan.progress != null)
              Text(
                'Current progress: ${scan.progress!.toStringAsFixed(1)}%',
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Running'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Stop Scan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(backgroundScanActionsProvider).cancelScan(scan.scanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan "${scan.displayName}" cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showCancelAllDialog(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel All Scans?'),
        content: Text('This will stop all $count running scans.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(backgroundScanActionsProvider).cancelAllScans();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All scans cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewScanDetails(BackgroundScan scan) {
    // TODO: Navigate to detailed view (view-only mode)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scan.displayName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Scan ID', scan.scanId.substring(0, 8)),
              _buildDetailRow('Target Type', scan.config.targetType),
              _buildDetailRow('Target Name', scan.config.targetName),
              _buildDetailRow('Probes', scan.config.probes.join(', ')),
              _buildDetailRow('Generations', scan.config.generations.toString()),
              _buildDetailRow('Threshold', scan.config.evalThreshold.toString()),
              _buildDetailRow('Started', scan.startTime.toString()),
              _buildDetailRow('Status', _getStatusText(scan)),
              if (scan.progress != null)
                _buildDetailRow('Progress', '${scan.progress!.toStringAsFixed(1)}%'),
              if (scan.status?.elapsedTime != null)
                _buildDetailRow('Elapsed Time', scan.status!.elapsedTime!),
              if (scan.status?.estimatedRemaining != null)
                _buildDetailRow('Estimated Remaining', scan.status!.estimatedRemaining!),
              if (scan.status?.currentProbe != null)
                _buildDetailRow('Current Probe', scan.status!.currentProbe!),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _viewResults(BackgroundScan scan) {
    // TODO: Navigate to results screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Results view coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _retryCheck(BackgroundScan scan) {
    // For failed scans, show details
    _viewScanDetails(scan);
  }
}
