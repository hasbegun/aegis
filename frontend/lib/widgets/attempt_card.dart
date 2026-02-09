import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Expandable card showing a single test attempt (prompt, output, status)
class AttemptCard extends StatefulWidget {
  final Map<String, dynamic> attempt;
  final int index;

  const AttemptCard({
    super.key,
    required this.attempt,
    required this.index,
  });

  @override
  State<AttemptCard> createState() => _AttemptCardState();
}

class _AttemptCardState extends State<AttemptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.attempt['status'] as String? ?? 'unknown';
    final promptText = widget.attempt['prompt_text'] as String? ?? '';
    final outputText = widget.attempt['output_text'] as String? ?? '';
    final allOutputs = (widget.attempt['all_outputs'] as List?)?.cast<String>() ?? [];
    final triggers = (widget.attempt['triggers'] as List?)?.cast<String>();
    final detectorResults = widget.attempt['detector_results'] as Map<String, dynamic>? ?? {};

    final isFailed = status == 'failed';
    final statusColor = isFailed ? Colors.red : Colors.green;
    final statusIcon = isFailed ? Icons.dangerous : Icons.check_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsed header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '#${widget.index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      promptText.isNotEmpty
                          ? (promptText.length > 80
                              ? '${promptText.substring(0, 80)}...'
                              : promptText)
                          : '(no prompt)',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // Expanded details
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prompt
                    _buildSection(
                      theme,
                      'Prompt',
                      promptText,
                      Icons.chat_bubble_outline,
                    ),
                    const SizedBox(height: 12),

                    // Output
                    _buildSection(
                      theme,
                      'Model Output',
                      outputText,
                      Icons.smart_toy,
                    ),

                    // Additional outputs
                    if (allOutputs.length > 1) ...[
                      const SizedBox(height: 12),
                      Text(
                        'All Outputs (${allOutputs.length})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (var i = 1; i < allOutputs.length; i++) ...[
                        _buildCodeBlock(theme, allOutputs[i]),
                        const SizedBox(height: 4),
                      ],
                    ],

                    // Triggers
                    if (triggers != null && triggers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Triggers',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: triggers
                            .map((t) => Chip(
                                  label: Text(
                                    t.length > 60 ? '${t.substring(0, 60)}...' : t,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],

                    // Detector results
                    if (detectorResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Detector Results',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...detectorResults.entries.map((e) {
                        final value = e.value;
                        final scores = value is List ? value : [value];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  e.key.split('.').last,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Wrap(
                                  spacing: 4,
                                  children: scores.map<Widget>((s) {
                                    final score = s is num ? s.toDouble() : 0.0;
                                    final color = score > 0.5 ? Colors.red : Colors.green;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: color.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        score.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (content.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title copied'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
        const SizedBox(height: 4),
        _buildCodeBlock(theme, content),
      ],
    );
  }

  Widget _buildCodeBlock(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: SelectableText(
        text.isNotEmpty ? text : '(empty)',
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: text.isEmpty
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
