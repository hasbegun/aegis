import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for locale state with persistence
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// Notifier for managing locale with persistence
class LocaleNotifier extends StateNotifier<Locale?> {
  static const String _localeKey = 'app_locale';

  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  /// Supported locales with display names
  static const Map<String, String> supportedLocales = {
    'system': 'System Default',
    'en': 'English',
    'ko': '한국어 (Korean)',
    'ja': '日本語 (Japanese)',
    'es': 'Español (Spanish)',
    'zh': '中文 (Chinese)',
  };

  /// Load locale from SharedPreferences
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode != null && localeCode != 'system') {
        state = Locale(localeCode);
      } else {
        state = null; // System default
      }
    } catch (e) {
      // If loading fails, use system default
      state = null;
    }
  }

  /// Set locale and persist to SharedPreferences
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.setString(_localeKey, 'system');
      } else {
        await prefs.setString(_localeKey, locale.languageCode);
      }
    } catch (e) {
      // If saving fails, the locale will still change for this session
    }
  }

  /// Get display name for a locale
  static String getDisplayName(Locale? locale) {
    if (locale == null) {
      return supportedLocales['system']!;
    }
    return supportedLocales[locale.languageCode] ?? locale.languageCode;
  }

  /// Get all available locales (excluding 'system' key)
  static List<Locale> get availableLocales {
    return supportedLocales.keys
        .where((code) => code != 'system')
        .map((code) => Locale(code))
        .toList();
  }
}
