import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Type of empty state illustration to display
enum EmptyStateType {
  noHistory,
  noResults,
  noProbes,
  noActiveTasks,
  noCompletedTasks,
  noFailedTasks,
  searchNoResults,
}

/// A visually appealing empty state widget with illustrations
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });

  final EmptyStateType type;
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIllustration(colorScheme),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(ColorScheme colorScheme) {
    switch (type) {
      case EmptyStateType.noHistory:
        return _HistoryIllustration(colorScheme: colorScheme);
      case EmptyStateType.noResults:
        return _ResultsIllustration(colorScheme: colorScheme);
      case EmptyStateType.noProbes:
        return _ProbesIllustration(colorScheme: colorScheme);
      case EmptyStateType.noActiveTasks:
        return _ActiveTasksIllustration(colorScheme: colorScheme);
      case EmptyStateType.noCompletedTasks:
        return _CompletedTasksIllustration(colorScheme: colorScheme);
      case EmptyStateType.noFailedTasks:
        return _NoFailedTasksIllustration(colorScheme: colorScheme);
      case EmptyStateType.searchNoResults:
        return _SearchIllustration(colorScheme: colorScheme);
    }
  }
}

/// Illustration for no scan history
class _HistoryIllustration extends StatelessWidget {
  const _HistoryIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          // Stacked document cards
          Positioned(
            top: 20,
            left: 15,
            child: Transform.rotate(
              angle: -0.15,
              child: _buildDocCard(colorScheme, 0.4),
            ),
          ),
          Positioned(
            top: 15,
            left: 25,
            child: Transform.rotate(
              angle: 0.1,
              child: _buildDocCard(colorScheme, 0.6),
            ),
          ),
          // Main clock icon
          Positioned(
            bottom: 10,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.schedule,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(ColorScheme colorScheme, double opacity) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: opacity * 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 35,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: opacity * 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 25,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: opacity * 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Illustration for no results
class _ResultsIllustration extends StatelessWidget {
  const _ResultsIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
            ),
          ),
          // Chart bars
          Positioned(
            bottom: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(colorScheme, 20, colorScheme.outline.withValues(alpha: 0.3)),
                const SizedBox(width: 6),
                _buildBar(colorScheme, 35, colorScheme.outline.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                _buildBar(colorScheme, 25, colorScheme.outline.withValues(alpha: 0.3)),
                const SizedBox(width: 6),
                _buildBar(colorScheme, 40, colorScheme.outline.withValues(alpha: 0.5)),
              ],
            ),
          ),
          // Clipboard icon
          Positioned(
            top: 10,
            child: Icon(
              Icons.assignment_outlined,
              size: 40,
              color: colorScheme.secondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(ColorScheme colorScheme, double height, Color color) {
    return Container(
      width: 12,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Illustration for no custom probes
class _ProbesIllustration extends StatelessWidget {
  const _ProbesIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            ),
          ),
          // Code brackets
          Positioned(
            left: 15,
            child: Text(
              '{',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: colorScheme.tertiary.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            right: 15,
            child: Text(
              '}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: colorScheme.tertiary.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Center code icon
          Icon(
            Icons.code,
            size: 40,
            color: colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

/// Illustration for no active tasks
class _ActiveTasksIllustration extends StatelessWidget {
  const _ActiveTasksIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
          // Checkmark with shield
          Icon(
            Icons.verified_outlined,
            size: 56,
            color: Colors.green.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// Illustration for no completed tasks
class _CompletedTasksIllustration extends StatelessWidget {
  const _CompletedTasksIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          // Empty inbox style
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: colorScheme.primary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Illustration for no failed tasks (positive state)
class _NoFailedTasksIllustration extends StatelessWidget {
  const _NoFailedTasksIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
          // Thumbs up or celebration icon
          Icon(
            Icons.celebration_outlined,
            size: 56,
            color: Colors.green.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// Illustration for search with no results
class _SearchIllustration extends StatelessWidget {
  const _SearchIllustration({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
          // Search icon with question
          Icon(
            Icons.search_off,
            size: 56,
            color: colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
