import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innox_security/l10n/app_localizations.dart';
import '../../config/constants.dart';
import '../../providers/plugins_provider.dart';
import '../../providers/scan_config_provider.dart';
import '../../utils/ui_helpers.dart';
import '../scan/scan_execution_screen.dart';
import 'advanced_config_screen.dart';

class ProbeSelectionScreen extends ConsumerStatefulWidget {
  const ProbeSelectionScreen({super.key});

  @override
  ConsumerState<ProbeSelectionScreen> createState() => _ProbeSelectionScreenState();
}

class _ProbeSelectionScreenState extends ConsumerState<ProbeSelectionScreen> {
  final Set<String> _selectedProbes = {};
  bool _selectAll = false;
  String _searchQuery = '';

  void _startScan() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedProbes.isEmpty && !_selectAll) {
      context.showError(l10n.selectAtLeastOneProbe);
      return;
    }

    // Update scan config with selected probes
    ref.read(scanConfigProvider.notifier).setProbes(
          _selectAll ? ['all'] : _selectedProbes.toList(),
        );

    // Navigate to scan execution
    Navigator.push(
      context,
      UIHelpers.slideRoute(const ScanExecutionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categorizedProbes = ref.watch(categorizedProbesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectProbes),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showProbeInfo(context),
          ),
        ],
      ),
      body: categorizedProbes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Failed to load probes'),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(categorizedProbesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (probesByCategory) {
          final categories = probesByCategory.keys.toList()..sort();

          return Column(
            children: [
              // Header with search and select all
              Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: l10n.searchProbes,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: theme.colorScheme.primaryContainer,
                            child: CheckboxListTile(
                              title: Text(l10n.selectAllProbes),
                              subtitle: Text(l10n.runComprehensiveScan),
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    _selectedProbes.clear();
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedProbes.clear();
                              _selectAll = false;
                            });
                          },
                          icon: const Icon(Icons.clear_all),
                          label: Text(l10n.clear),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Probe categories list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final probes = probesByCategory[category]!;

                    // Filter by search
                    final filteredProbes = _searchQuery.isEmpty
                        ? probes
                        : probes.where((p) =>
                            p.name.toLowerCase().contains(_searchQuery) ||
                            category.toLowerCase().contains(_searchQuery) ||
                            (p.description?.toLowerCase().contains(_searchQuery) ?? false),
                          ).toList();

                    if (filteredProbes.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return _buildCategorySection(
                      context,
                      category,
                      filteredProbes,
                    );
                  },
                ),
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectAll
                                ? 'All probes selected'
                                : '${_selectedProbes.length} probe(s) selected',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!_selectAll && _selectedProbes.isNotEmpty)
                            Text(
                              _selectedProbes
                                  .take(3)
                                  .map((fullName) {
                                    // Extract short name from fullName (e.g., "probes.dan.Dan_11_0" -> "Dan_11_0")
                                    final parts = fullName.split('.');
                                    return parts.isNotEmpty ? parts.last : fullName;
                                  })
                                  .join(', ') +
                                  (_selectedProbes.length > 3 ? '...' : ''),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _goToAdvancedOptions,
                      icon: const Icon(Icons.tune),
                      label: Text(l10n.advanced),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.quickStart),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _goToAdvancedOptions() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedProbes.isEmpty && !_selectAll) {
      context.showError(l10n.selectAtLeastOneProbe);
      return;
    }

    // Update scan config with selected probes
    ref.read(scanConfigProvider.notifier).setProbes(
          _selectAll ? ['all'] : _selectedProbes.toList(),
        );

    // Navigate to advanced configuration
    Navigator.push(
      context,
      UIHelpers.slideRoute(const AdvancedConfigScreen()),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<dynamic> probes,
  ) {
    final theme = Theme.of(context);

    // Count how many probes in this category are selected
    final selectedCount = probes.where((p) => _selectedProbes.contains(p.fullName)).length;
    final allSelected = selectedCount == probes.length && selectedCount > 0;
    final someSelected = selectedCount > 0 && selectedCount < probes.length;

    // Determine checkbox state
    bool? checkboxValue;
    if (_selectAll) {
      checkboxValue = false; // Don't show checked when "Select All" is active
    } else if (allSelected) {
      checkboxValue = true;
    } else if (someSelected) {
      checkboxValue = null; // Indeterminate state
    } else {
      checkboxValue = false;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: ExpansionTile(
        leading: Icon(
          _getCategoryIcon(category),
          color: theme.colorScheme.primary,
        ),
        title: Text(
          _formatCategoryName(category),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          selectedCount > 0
            ? '${probes.length} probe(s) • $selectedCount selected'
            : '${probes.length} probe(s)'
        ),
        trailing: Checkbox(
          value: checkboxValue,
          tristate: true,
          onChanged: _selectAll
              ? null
              : (value) {
                  setState(() {
                    if (value == true) {
                      // Select all in category
                      for (var probe in probes) {
                        _selectedProbes.add(probe.fullName);
                      }
                    } else {
                      // Deselect all in category (handles both false and null)
                      for (var probe in probes) {
                        _selectedProbes.remove(probe.fullName);
                      }
                    }
                  });
                },
        ),
        children: probes.map((probe) {
          return CheckboxListTile(
            enabled: !_selectAll,
            title: Text(UIHelpers.stripAnsiCodes(probe.name)),
            subtitle: probe.description != null
                ? Text(
                    UIHelpers.stripAnsiCodes(probe.description!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            value: _selectAll || _selectedProbes.contains(probe.fullName),
            onChanged: _selectAll
                ? null
                : (value) {
                    setState(() {
                      if (value == true) {
                        _selectedProbes.add(probe.fullName);
                      } else {
                        _selectedProbes.remove(probe.fullName);
                      }
                    });
                  },
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dan':
        return Icons.security;
      case 'encoding':
        return Icons.code;
      case 'promptinject':
      case 'injection':
        return Icons.warning;
      case 'toxicity':
      case 'lmrc':
        return Icons.dangerous;
      case 'xss':
        return Icons.bug_report;
      default:
        return Icons.science;
    }
  }

  String _formatCategoryName(String category) {
    return category.toUpperCase();
  }

  void _showProbeInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aboutProbes),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vulnerability Probes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n.aboutProbesContent),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }
}
