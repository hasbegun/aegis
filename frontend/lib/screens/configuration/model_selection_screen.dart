import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:innox_security/l10n/app_localizations.dart';
import '../../config/constants.dart';
import '../../providers/scan_config_provider.dart';
import '../../utils/ui_helpers.dart';
import '../configuration/probe_selection_screen.dart';

class ModelSelectionScreen extends ConsumerStatefulWidget {
  final String? initialPreset;

  const ModelSelectionScreen({
    super.key,
    this.initialPreset,
  });

  @override
  ConsumerState<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends ConsumerState<ModelSelectionScreen> {
  String? _selectedGeneratorType;
  String? _selectedPreset;
  String _ollamaEndpoint = AppConstants.defaultOllamaEndpoint;
  final TextEditingController _modelNameController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOllamaEndpoint();
    // Set initial preset if provided
    if (widget.initialPreset != null) {
      _selectedPreset = widget.initialPreset;
      // Auto-apply preset on initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedPreset != null) {
          _applyPreset(_selectedPreset!);
        }
      });
    }
  }

  Future<void> _loadOllamaEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ollamaEndpoint = prefs.getString(AppConstants.keyOllamaEndpoint) ?? AppConstants.defaultOllamaEndpoint;
    });
  }

  @override
  void dispose() {
    _modelNameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _applyPreset(String presetKey) {
    // Preset will be applied when continuing to probe selection
    // This just marks it as selected for now
    context.showInfo('${ConfigPresets.getPreset(presetKey)['name']} preset selected');
  }

  void _continueToProbeSelection() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedGeneratorType == null || _modelNameController.text.isEmpty) {
      context.showError(l10n.selectGeneratorAndModel);
      return;
    }

    // Update scan config
    ref.read(scanConfigProvider.notifier).setTarget(
          _selectedGeneratorType!,
          _modelNameController.text,
        );

    // Apply preset if selected
    if (_selectedPreset != null) {
      ref.read(scanConfigProvider.notifier).loadPreset(
        ConfigPresets.getPreset(_selectedPreset!),
      );
    }

    // Set API key if provided
    if (_apiKeyController.text.isNotEmpty) {
      ref.read(scanConfigProvider.notifier).setGeneratorOptions({
        'api_key': _apiKeyController.text,
      });
    }

    // Navigate to probe selection
    Navigator.push(
      context,
      UIHelpers.slideRoute(const ProbeSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectModel),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                l10n.configureTargetModel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.selectLlmGenerator,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.largePadding),

              // Preset Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.stars, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            l10n.quickPresets,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start with a preset configuration (optional)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ConfigPresets.all.map((presetKey) {
                          final preset = ConfigPresets.getPreset(presetKey);
                          final isSelected = _selectedPreset == presetKey;
                          return ChoiceChip(
                            label: Text(preset['name'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedPreset = selected ? presetKey : null;
                                if (selected) {
                                  _applyPreset(presetKey);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (_selectedPreset != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ConfigPresets.getPreset(_selectedPreset!)['description'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),

              // Generator Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.generatorType,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: GeneratorTypes.all.map((type) {
                          final isSelected = _selectedGeneratorType == type;
                          return FilterChip(
                            label: Text(GeneratorTypes.getDisplayName(type)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedGeneratorType = selected ? type : null;
                                // Set example model names
                                if (selected) {
                                  _modelNameController.text = _getExampleModelName(type);
                                }
                              });
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),

              // Model Name Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.modelName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.smallPadding),
                      Text(
                        l10n.modelNameDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      TextField(
                        controller: _modelNameController,
                        decoration: InputDecoration(
                          hintText: _getModelHint(context, _selectedGeneratorType),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.model_training),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),

              // Ollama Setup Info
              if (_selectedGeneratorType == GeneratorTypes.ollama)
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.ollamaSetup,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure Ollama is running locally:\n\n'
                          '1. Install Ollama: ollama.ai\n'
                          '2. Pull a model: ollama pull llama2\n'
                          '3. Start server: ollama serve\n'
                          '4. Endpoint: $_ollamaEndpoint',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Popular models: llama2, llama3, gemma, mistral, codellama',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_selectedGeneratorType == GeneratorTypes.ollama)
                const SizedBox(height: AppConstants.defaultPadding),

              // API Key Input (if needed)
              if (_needsApiKey(_selectedGeneratorType))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.apiKey,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: const Text('Optional'),
                              labelStyle: theme.textTheme.labelSmall,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.smallPadding),
                        Text(
                          'API key for ${GeneratorTypes.getDisplayName(_selectedGeneratorType!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'sk-...',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.key),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                _showApiKeyInfo(context);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppConstants.largePadding),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _continueToProbeSelection,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.continueToProbeSelection),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getExampleModelName(String type) {
    switch (type) {
      case GeneratorTypes.ollama:
        return 'llama2';
      case GeneratorTypes.openai:
        return 'gpt-3.5-turbo';
      case GeneratorTypes.huggingface:
        return 'gpt2';
      case GeneratorTypes.anthropic:
        return 'claude-3-opus-20240229';
      case GeneratorTypes.cohere:
        return 'command';
      case GeneratorTypes.replicate:
        return 'meta/llama-2-70b-chat';
      case GeneratorTypes.litellm:
        return 'ollama/llama2';
      case GeneratorTypes.nim:
        return 'meta/llama-3.1-8b-instruct';
      default:
        return '';
    }
  }

  String _getModelHint(BuildContext context, String? type) {
    final l10n = AppLocalizations.of(context)!;
    if (type == null) return 'Select a generator type first';

    switch (type) {
      case GeneratorTypes.openai:
        return l10n.modelHintOpenai;
      case GeneratorTypes.huggingface:
        return l10n.modelHintHuggingface;
      case GeneratorTypes.replicate:
        return l10n.modelHintReplicate;
      case GeneratorTypes.cohere:
        return l10n.modelHintCohere;
      case GeneratorTypes.anthropic:
        return l10n.modelHintAnthropic;
      case GeneratorTypes.litellm:
        return l10n.modelHintLitellm;
      case GeneratorTypes.nim:
        return l10n.modelHintNim;
      case GeneratorTypes.ollama:
        return l10n.modelHintOllama;
      default:
        return 'e.g., ${_getExampleModelName(type)}';
    }
  }

  bool _needsApiKey(String? type) {
    if (type == null) return false;
    // Ollama and HuggingFace can run locally without API keys
    return [
      GeneratorTypes.openai,
      GeneratorTypes.anthropic,
      GeneratorTypes.cohere,
      GeneratorTypes.replicate,
    ].contains(type);
  }

  void _showApiKeyInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.apiKeyInformation),
        content: Text(l10n.apiKeyInfoContent),
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
