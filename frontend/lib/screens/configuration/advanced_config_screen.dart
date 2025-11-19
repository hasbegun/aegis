import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innox_security/l10n/app_localizations.dart';
import '../../config/constants.dart';
import '../../providers/plugins_provider.dart';
import '../../providers/scan_config_provider.dart';
import '../../utils/ui_helpers.dart';
import '../scan/scan_execution_screen.dart';

/// Advanced configuration screen for buffs, detectors, and parameters
class AdvancedConfigScreen extends ConsumerStatefulWidget {
  const AdvancedConfigScreen({super.key});

  @override
  ConsumerState<AdvancedConfigScreen> createState() => _AdvancedConfigScreenState();
}

class _AdvancedConfigScreenState extends ConsumerState<AdvancedConfigScreen> {
  final Set<String> _selectedBuffs = {};
  final Set<String> _selectedDetectors = {};

  // Advanced parameters
  int? _parallelRequests;
  int? _parallelAttempts;
  int? _seed;
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _parallelRequestsController = TextEditingController();
  final TextEditingController _parallelAttemptsController = TextEditingController();

  @override
  void dispose() {
    _seedController.dispose();
    _parallelRequestsController.dispose();
    _parallelAttemptsController.dispose();
    super.dispose();
  }

  void _startScan() {
    // Update scan config with advanced options
    final config = ref.read(scanConfigProvider);

    if (config == null) {
      context.showError('Configuration error');
      return;
    }

    // Apply buffs
    if (_selectedBuffs.isNotEmpty) {
      ref.read(scanConfigProvider.notifier).setBuffs(_selectedBuffs.toList());
    }

    // Apply detectors
    if (_selectedDetectors.isNotEmpty) {
      ref.read(scanConfigProvider.notifier).setDetectors(_selectedDetectors.toList());
    }

    // Apply advanced parameters
    if (_parallelRequests != null) {
      ref.read(scanConfigProvider.notifier).setParallelRequests(_parallelRequests!);
    }
    if (_parallelAttempts != null) {
      ref.read(scanConfigProvider.notifier).setParallelAttempts(_parallelAttempts!);
    }
    if (_seed != null) {
      ref.read(scanConfigProvider.notifier).setSeed(_seed!);
    }

    // Navigate to scan execution
    Navigator.push(
      context,
      UIHelpers.slideRoute(const ScanExecutionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedConfiguration),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Advanced Options',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional: Configure buffs, detectors, and advanced parameters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.largePadding),

            // Buffs Section
            _buildBuffsSection(theme),
            const SizedBox(height: AppConstants.defaultPadding),

            // Detectors Section
            _buildDetectorsSection(theme),
            const SizedBox(height: AppConstants.defaultPadding),

            // Advanced Parameters Section
            _buildAdvancedParametersSection(theme, l10n),
            const SizedBox(height: AppConstants.largePadding),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Start Scan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuffsSection(ThemeData theme) {
    final buffsAsync = ref.watch(buffsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Buffs (Input Transformations)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                buffsAsync.when(
                  data: (buffs) => buffs.isEmpty
                      ? const SizedBox.shrink()
                      : TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_selectedBuffs.length == buffs.length) {
                                _selectedBuffs.clear();
                              } else {
                                _selectedBuffs.clear();
                                _selectedBuffs.addAll(buffs.map((b) => b.fullName));
                              }
                            });
                          },
                          icon: Icon(_selectedBuffs.length == buffs.length ? Icons.deselect : Icons.select_all),
                          label: Text(_selectedBuffs.length == buffs.length ? 'Clear All' : 'Select All'),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Buffs modify prompts before testing (e.g., paraphrasing, translation)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            buffsAsync.when(
              data: (buffs) => buffs.isEmpty
                  ? const Text('No buffs available')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: buffs.map((buff) {
                        final isSelected = _selectedBuffs.contains(buff.fullName);
                        final cleanName = UIHelpers.stripAnsiCodes(buff.name);
                        return Tooltip(
                          message: buff.description != null
                              ? UIHelpers.stripAnsiCodes(buff.description!)
                              : cleanName,
                          child: FilterChip(
                            label: Text(cleanName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedBuffs.add(buff.fullName);
                                } else {
                                  _selectedBuffs.remove(buff.fullName);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading buffs: $error'),
            ),
            if (_selectedBuffs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedBuffs.length} buff(s) selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetectorsSection(ThemeData theme) {
    final detectorsAsync = ref.watch(detectorsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Detectors',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                detectorsAsync.when(
                  data: (detectors) => detectors.isEmpty
                      ? const SizedBox.shrink()
                      : TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_selectedDetectors.length == detectors.length) {
                                _selectedDetectors.clear();
                              } else {
                                _selectedDetectors.clear();
                                _selectedDetectors.addAll(detectors.map((d) => d.fullName));
                              }
                            });
                          },
                          icon: Icon(_selectedDetectors.length == detectors.length ? Icons.deselect : Icons.select_all),
                          label: Text(_selectedDetectors.length == detectors.length ? 'Clear All' : 'Select All'),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Detectors analyze model outputs to identify vulnerabilities',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            detectorsAsync.when(
              data: (detectors) => detectors.isEmpty
                  ? const Text('No detectors available')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: detectors.map((detector) {
                        final isSelected = _selectedDetectors.contains(detector.fullName);
                        final cleanName = UIHelpers.stripAnsiCodes(detector.name);
                        return Tooltip(
                          message: detector.description != null
                              ? UIHelpers.stripAnsiCodes(detector.description!)
                              : cleanName,
                          child: FilterChip(
                            label: Text(cleanName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDetectors.add(detector.fullName);
                                } else {
                                  _selectedDetectors.remove(detector.fullName);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading detectors: $error'),
            ),
            if (_selectedDetectors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedDetectors.length} detector(s) selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedParametersSection(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Advanced Parameters',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Parallel Requests
            TextField(
              controller: _parallelRequestsController,
              decoration: InputDecoration(
                labelText: l10n.parallelRequests,
                hintText: 'e.g., 5',
                helperText: 'Number of concurrent API requests (1-20, default: 5)',
                errorText: _parallelRequests != null && (_parallelRequests! < 1 || _parallelRequests! > 20)
                    ? 'Must be between 1 and 20'
                    : null,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.sync),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _parallelRequests = int.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Parallel Attempts
            TextField(
              controller: _parallelAttemptsController,
              decoration: InputDecoration(
                labelText: l10n.parallelAttempts,
                hintText: 'e.g., 3',
                helperText: 'Number of parallel generation attempts per prompt (1-10, default: 1)',
                errorText: _parallelAttempts != null && (_parallelAttempts! < 1 || _parallelAttempts! > 10)
                    ? 'Must be between 1 and 10'
                    : null,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.repeat),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _parallelAttempts = int.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Seed
            TextField(
              controller: _seedController,
              decoration: InputDecoration(
                labelText: l10n.randomSeed,
                hintText: 'e.g., 42',
                helperText: 'Set for reproducible results (any positive integer, optional)',
                errorText: _seed != null && _seed! < 0
                    ? 'Must be a positive number'
                    : null,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.tag),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _seed = int.tryParse(value);
                });
              },
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Leave fields empty to use default values',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
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
}
