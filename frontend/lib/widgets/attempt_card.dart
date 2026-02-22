import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sanitize model output text for clean display.
///
/// Handles three kinds of ANSI escape data found in model outputs:
///   A. Actual binary escape sequences (ESC byte 0x1b + sequence content)
///   B. Text representations the model wrote (literal `\033[4m`, `\x1b[0m`)
///   C. Orphaned fragments left when only the prefix was stripped (`]8;url`)
///
/// Phase order matters — binary sequences must be removed as whole units
/// before individual control chars are converted to hex text.
String _sanitizeForDisplay(String text) {
  var s = text;

  // ── Phase 1: Strip actual binary ANSI escape sequences ──
  // Real ESC (0x1b) byte followed by sequence content.

  // CSI: ESC [ <params> <letter>  (e.g. ESC[32m, ESC[0;1m)
  s = s.replaceAll(RegExp('\x1b\\[[\\d;]*[A-Za-z]?'), '');

  // OSC: ESC ] <content> BEL  or  ESC ] <content> ST
  // (e.g. ESC]8;params;uri BEL for hyperlinks)
  s = s.replaceAll(RegExp('\x1b\\][^\x07\x1b\n]*(?:\x07|\x1b\\\\)?'), '');

  // Two-character: ESC <letter>  (e.g. ESC c for reset)
  s = s.replaceAll(RegExp('\x1b[A-Za-z]'), '');

  // Any remaining standalone ESC or BEL bytes
  s = s.replaceAll(RegExp('[\x1b\x07]'), '');

  // ── Phase 2: Strip text representations of escape codes ──
  // Literal backslash-prefixed strings the model wrote as text.

  // CSI text: \033[..m  \x1b[..m  \e[..m
  s = s.replaceAll(RegExp(r'\\(?:033|x1b|e)\[[\d;]*[A-Za-z]?'), '');

  // OSC text: \033]...\x07  \x1b]...\x07  (with text terminator)
  s = s.replaceAll(RegExp(r'\\(?:033|x1b)\][^\s]*?\\x07'), '');

  // Standalone escape notations: \x07  \x1b  \033  \a
  s = s.replaceAll(RegExp(r'\\x[0-9a-fA-F]{2}'), '');
  s = s.replaceAll(RegExp(r'\\033'), '');
  s = s.replaceAll(RegExp(r'\\a\b'), '');

  // ── Phase 3: Strip orphaned escape remnants ──
  // Fragments like ]8;url left after ESC/\x1b prefix was stripped.
  s = s.replaceAll(RegExp(r'\]8;[^\s\]]*'), '');

  // ── Phase 4: Cleanup ──
  // Fenced code-block markers: ```lang or ```
  s = s.replaceAll(RegExp(r'```\w*'), '');

  // Empty backtick pairs left behind: `` or ` `
  s = s.replaceAll(RegExp(r'`\s*`'), '');

  // Collapse runs of 3+ newlines into 2
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // ── Phase 5: Replace remaining binary control characters ──
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code < 0x20 && code != 0x0A && code != 0x0D && code != 0x09) {
      buf.write('\\x${code.toRadixString(16).padLeft(2, '0')}');
    } else {
      buf.writeCharCode(code);
    }
  }
  return buf.toString();
}

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
                          ? (() {
                              final clean = _sanitizeForDisplay(promptText);
                              return clean.length > 80
                                  ? '${clean.substring(0, 80)}...'
                                  : clean;
                            })()
                          : '(no prompt)',
                      style: theme.textTheme.bodyMedium,
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
                        style: theme.textTheme.titleSmall?.copyWith(
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
                        style: theme.textTheme.titleSmall?.copyWith(
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
                                    style: const TextStyle(fontSize: 13),
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
                        style: theme.textTheme.titleSmall?.copyWith(
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                          fontSize: 13,
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
              style: theme.textTheme.titleSmall?.copyWith(
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
    final display = text.isNotEmpty ? _sanitizeForDisplay(text) : '(empty)';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: SelectableText(
        display,
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          color: text.isEmpty
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
