import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for keyboard shortcuts
class KeyboardShortcuts {
  KeyboardShortcuts._();

  /// Get the modifier key name based on platform (Cmd on macOS, Ctrl elsewhere)
  static String get modifierKey {
    if (Platform.isMacOS) {
      return '⌘';
    }
    return 'Ctrl';
  }

  /// Format a shortcut hint for display in tooltips
  static String formatHint(String action, String key, {bool useShift = false}) {
    final modifier = modifierKey;
    if (useShift) {
      return '$action ($modifier+Shift+$key)';
    }
    return '$action ($modifier+$key)';
  }

  /// Common shortcut: New/Create (Ctrl+N / Cmd+N)
  static SingleActivator get newShortcut => SingleActivator(
        LogicalKeyboardKey.keyN,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: Save (Ctrl+S / Cmd+S)
  static SingleActivator get saveShortcut => SingleActivator(
        LogicalKeyboardKey.keyS,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: Export (Ctrl+E / Cmd+E)
  static SingleActivator get exportShortcut => SingleActivator(
        LogicalKeyboardKey.keyE,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: Settings (Ctrl+, / Cmd+,)
  static SingleActivator get settingsShortcut => SingleActivator(
        LogicalKeyboardKey.comma,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: History (Ctrl+H / Cmd+H)
  static SingleActivator get historyShortcut => SingleActivator(
        LogicalKeyboardKey.keyH,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: Run/Execute (Ctrl+Enter / Cmd+Enter)
  static SingleActivator get runShortcut => SingleActivator(
        LogicalKeyboardKey.enter,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: Search (Ctrl+F / Cmd+F)
  static SingleActivator get searchShortcut => SingleActivator(
        LogicalKeyboardKey.keyF,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      );

  /// Common shortcut: Back (Escape)
  static SingleActivator get backShortcut => const SingleActivator(
        LogicalKeyboardKey.escape,
      );
}

/// Intent for triggering actions via keyboard shortcuts
class ShortcutIntent extends Intent {
  const ShortcutIntent(this.action);
  final String action;
}

/// Action that calls a callback when triggered
class ShortcutCallbackAction extends Action<ShortcutIntent> {
  ShortcutCallbackAction(this.callbacks);

  final Map<String, VoidCallback> callbacks;

  @override
  void invoke(ShortcutIntent intent) {
    callbacks[intent.action]?.call();
  }
}

/// Widget that wraps a child with keyboard shortcut handling
class KeyboardShortcutWrapper extends StatelessWidget {
  const KeyboardShortcutWrapper({
    super.key,
    required this.shortcuts,
    required this.child,
  });

  /// Map of shortcut activators to action names
  final Map<SingleActivator, String> shortcuts;

  /// Child widget
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        for (final entry in shortcuts.entries)
          entry.key: ShortcutIntent(entry.value),
      },
      child: child,
    );
  }
}
