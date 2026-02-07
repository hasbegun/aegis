import 'package:flutter/material.dart';

/// A single breadcrumb item representing a navigation step
class BreadcrumbItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const BreadcrumbItem({
    required this.label,
    this.icon,
    this.onTap,
  });
}

/// A breadcrumb navigation widget showing the current location in the app hierarchy
class BreadcrumbNav extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Color? activeColor;
  final Color? inactiveColor;
  final double? fontSize;

  const BreadcrumbNav({
    super.key,
    required this.items,
    this.activeColor,
    this.inactiveColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveActiveColor = activeColor ?? theme.colorScheme.onSurface;
    final effectiveInactiveColor = inactiveColor ?? theme.colorScheme.primary;
    final effectiveFontSize = fontSize ?? 13.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildBreadcrumbItem(
              context,
              items[i],
              isLast: i == items.length - 1,
              activeColor: effectiveActiveColor,
              inactiveColor: effectiveInactiveColor,
              fontSize: effectiveFontSize,
            ),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreadcrumbItem(
    BuildContext context,
    BreadcrumbItem item, {
    required bool isLast,
    required Color activeColor,
    required Color inactiveColor,
    required double fontSize,
  }) {
    final color = isLast ? activeColor : inactiveColor;
    final fontWeight = isLast ? FontWeight.w600 : FontWeight.normal;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Icon(
            item.icon,
            size: fontSize + 3,
            color: color,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          item.label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ],
    );

    if (isLast || item.onTap == null) {
      return content;
    }

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
    );
  }
}

/// A container widget that wraps content with breadcrumb navigation at the top
class BreadcrumbScaffold extends StatelessWidget {
  final List<BreadcrumbItem> breadcrumbs;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const BreadcrumbScaffold({
    super.key,
    required this.breadcrumbs,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: BreadcrumbNav(items: breadcrumbs),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Helper class to build common breadcrumb paths
class BreadcrumbPaths {
  BreadcrumbPaths._();

  /// Home breadcrumb item
  static BreadcrumbItem home(BuildContext context) {
    return BreadcrumbItem(
      label: 'Home',
      icon: Icons.home,
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }

  /// History breadcrumb item
  static BreadcrumbItem history(BuildContext context, {VoidCallback? onTap}) {
    return BreadcrumbItem(
      label: 'History',
      icon: Icons.history,
      onTap: onTap ?? () => Navigator.of(context).pop(),
    );
  }

  /// Results breadcrumb item (current - no tap)
  static BreadcrumbItem results({String? scanId}) {
    return BreadcrumbItem(
      label: scanId != null ? 'Results (${scanId.substring(0, 8)})' : 'Results',
      icon: Icons.assessment,
    );
  }

  /// Detailed Report breadcrumb item (current - no tap)
  static BreadcrumbItem detailedReport() {
    return const BreadcrumbItem(
      label: 'Detailed Report',
      icon: Icons.article,
    );
  }

  /// Compare breadcrumb item (current - no tap)
  static BreadcrumbItem compare() {
    return const BreadcrumbItem(
      label: 'Compare',
      icon: Icons.compare_arrows,
    );
  }

  /// Configuration breadcrumb item
  static BreadcrumbItem configuration(BuildContext context, {VoidCallback? onTap}) {
    return BreadcrumbItem(
      label: 'Configuration',
      icon: Icons.settings,
      onTap: onTap ?? () => Navigator.of(context).pop(),
    );
  }

  /// Probe Selection breadcrumb item (current - no tap)
  static BreadcrumbItem probeSelection() {
    return const BreadcrumbItem(
      label: 'Select Probes',
      icon: Icons.science,
    );
  }

  /// Browse breadcrumb item
  static BreadcrumbItem browse(BuildContext context, {VoidCallback? onTap}) {
    return BreadcrumbItem(
      label: 'Browse',
      icon: Icons.explore,
      onTap: onTap ?? () => Navigator.of(context).pop(),
    );
  }

  /// Probe Details breadcrumb item (current - no tap)
  static BreadcrumbItem probeDetails(String probeName) {
    return BreadcrumbItem(
      label: probeName,
      icon: Icons.bug_report,
    );
  }

  /// Scan Execution breadcrumb item
  static BreadcrumbItem scanExecution(BuildContext context, {VoidCallback? onTap}) {
    return BreadcrumbItem(
      label: 'Scanning',
      icon: Icons.play_circle,
      onTap: onTap,
    );
  }

  /// Settings breadcrumb item (current - no tap)
  static BreadcrumbItem settings() {
    return const BreadcrumbItem(
      label: 'Settings',
      icon: Icons.tune,
    );
  }

  /// Background Tasks breadcrumb item (current - no tap)
  static BreadcrumbItem backgroundTasks() {
    return const BreadcrumbItem(
      label: 'Background Tasks',
      icon: Icons.downloading,
    );
  }

  /// Custom Probes breadcrumb item (current - no tap)
  static BreadcrumbItem customProbes() {
    return const BreadcrumbItem(
      label: 'Custom Probes',
      icon: Icons.extension,
    );
  }

  /// Write Probe breadcrumb item (current - no tap)
  static BreadcrumbItem writeProbe({bool isEditing = false}) {
    return BreadcrumbItem(
      label: isEditing ? 'Edit Probe' : 'New Probe',
      icon: Icons.edit,
    );
  }
}
