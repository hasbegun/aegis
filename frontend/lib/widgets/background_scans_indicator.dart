import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/background_scans_provider.dart';
import '../services/background_scan_service.dart';
import '../screens/scan/scan_execution_screen.dart';

/// Floating indicator showing active background scans
class BackgroundScansIndicator extends ConsumerWidget {
  const BackgroundScansIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(backgroundScansProvider);

    return scansAsync.when(
      data: (scans) {
        // Only show ACTIVE scans in the floating indicator
        final activeScans = scans.where((scan) => scan.isActive).toList();

        if (activeScans.isEmpty) return const SizedBox.shrink();

        return Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showAllScans(context, ref, activeScans),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeScans.length == 1
                                ? '1 scan running'
                                : '${activeScans.length} scans running',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (activeScans.length == 1 && activeScans.first.progress != null)
                            Text(
                              '${activeScans.first.progress!.toStringAsFixed(0)}% complete',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.expand_less,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showAllScans(BuildContext context, WidgetRef ref, List<BackgroundScan> scans) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.alt_route,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Background Scans',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (scans.length > 1)
                      TextButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Cancel All Scans?'),
                              content: Text('This will stop all ${scans.length} running scans.'),
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

                          if (confirmed == true) {
                            await ref.read(backgroundScanActionsProvider).cancelAllScans();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel All'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scan list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    return _buildScanCard(context, ref, scans[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanCard(BuildContext context, WidgetRef ref, BackgroundScan scan) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
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
                      Text(
                        _getStatusText(scan),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(scan, theme),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Cancel Scan?'),
                        content: Text('This will stop "${scan.displayName}".'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('No'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            child: const Text('Cancel Scan'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await ref.read(backgroundScanActionsProvider).cancelScan(scan.scanId);
                    }
                  },
                  tooltip: 'Cancel scan',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            if (scan.progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: scan.progress! / 100,  // Convert percentage (0-100) to fraction (0-1)
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(scan, theme),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${scan.progress!.toStringAsFixed(0)}% complete',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    _getElapsedTime(scan.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ] else ...[
              LinearProgressIndicator(
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(
                _getElapsedTime(scan.startTime),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  ref.read(backgroundScanActionsProvider).resumeScan(scan.scanId);
                  // Navigate to scan execution screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ScanExecutionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility),
                label: const Text('View Progress'),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  String _getElapsedTime(DateTime startTime) {
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
    } else {
      return '${elapsed.inSeconds}s';
    }
  }
}
