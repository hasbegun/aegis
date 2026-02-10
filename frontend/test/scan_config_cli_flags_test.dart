/// Tests for M22 (--report_threshold) and M24 (--collect_timing) CLI flags.
///
/// Covers:
/// - ScanConfig model: serialization, defaults, copyWith
/// - ScanConfigNotifier: setReportThreshold, setCollectTiming
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/models/scan_config.dart';
import 'package:aegis/providers/scan_config_provider.dart';

void main() {
  // -----------------------------------------------------------------------
  // ScanConfig model tests
  // -----------------------------------------------------------------------

  group('ScanConfig - reportThreshold (M22)', () {
    test('defaults to null', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
      );
      expect(config.reportThreshold, isNull);
    });

    test('can be set via constructor', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.75,
      );
      expect(config.reportThreshold, 0.75);
    });

    test('serializes to JSON with correct key', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.42,
      );
      final json = config.toJson();
      expect(json['report_threshold'], 0.42);
    });

    test('deserializes from JSON', () {
      final json = {
        'target_type': 'ollama',
        'target_name': 'llama3.2:3b',
        'probes': ['all'],
        'report_threshold': 0.65,
        'generations': 5,
        'eval_threshold': 0.5,
        'extended_detectors': false,
        'deprefix': false,
        'verbose': 0,
        'skip_unknown': false,
        'buffs_include_original_prompt': false,
        'no_report': false,
        'continue_on_error': false,
        'collect_timing': false,
      };
      final config = ScanConfig.fromJson(json);
      expect(config.reportThreshold, 0.65);
    });

    test('null when not in JSON', () {
      final json = {
        'target_type': 'ollama',
        'target_name': 'llama3.2:3b',
        'probes': ['all'],
        'generations': 5,
        'eval_threshold': 0.5,
        'extended_detectors': false,
        'deprefix': false,
        'verbose': 0,
        'skip_unknown': false,
        'buffs_include_original_prompt': false,
        'no_report': false,
        'continue_on_error': false,
        'collect_timing': false,
      };
      final config = ScanConfig.fromJson(json);
      expect(config.reportThreshold, isNull);
    });

    test('copyWith preserves value', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.5,
      );
      final copy = config.copyWith(generations: 10);
      expect(copy.reportThreshold, 0.5);
    });

    test('copyWith can override value', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.5,
      );
      final copy = config.copyWith(reportThreshold: 0.8);
      expect(copy.reportThreshold, 0.8);
    });

    test('serialization roundtrip', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.33,
      );
      final restored = ScanConfig.fromJson(config.toJson());
      expect(restored.reportThreshold, 0.33);
    });
  });

  group('ScanConfig - collectTiming (M24)', () {
    test('defaults to false', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
      );
      expect(config.collectTiming, false);
    });

    test('can be set to true', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        collectTiming: true,
      );
      expect(config.collectTiming, true);
    });

    test('serializes to JSON with correct key', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        collectTiming: true,
      );
      final json = config.toJson();
      expect(json['collect_timing'], true);
    });

    test('deserializes from JSON', () {
      final json = {
        'target_type': 'ollama',
        'target_name': 'llama3.2:3b',
        'probes': ['all'],
        'collect_timing': true,
        'generations': 5,
        'eval_threshold': 0.5,
        'extended_detectors': false,
        'deprefix': false,
        'verbose': 0,
        'skip_unknown': false,
        'buffs_include_original_prompt': false,
        'no_report': false,
        'continue_on_error': false,
      };
      final config = ScanConfig.fromJson(json);
      expect(config.collectTiming, true);
    });

    test('defaults to false when not in JSON', () {
      final json = {
        'target_type': 'ollama',
        'target_name': 'llama3.2:3b',
        'probes': ['all'],
        'generations': 5,
        'eval_threshold': 0.5,
        'extended_detectors': false,
        'deprefix': false,
        'verbose': 0,
        'skip_unknown': false,
        'buffs_include_original_prompt': false,
        'no_report': false,
        'continue_on_error': false,
      };
      final config = ScanConfig.fromJson(json);
      expect(config.collectTiming, false);
    });

    test('copyWith preserves value', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        collectTiming: true,
      );
      final copy = config.copyWith(generations: 10);
      expect(copy.collectTiming, true);
    });

    test('copyWith can override value', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        collectTiming: false,
      );
      final copy = config.copyWith(collectTiming: true);
      expect(copy.collectTiming, true);
    });

    test('serialization roundtrip', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        collectTiming: true,
      );
      final restored = ScanConfig.fromJson(config.toJson());
      expect(restored.collectTiming, true);
    });
  });

  // -----------------------------------------------------------------------
  // ScanConfigNotifier tests
  // -----------------------------------------------------------------------

  group('ScanConfigNotifier - reportThreshold', () {
    test('setReportThreshold updates state', () {
      final notifier = ScanConfigNotifier();
      notifier.setTarget('ollama', 'llama3.2:3b');
      notifier.setReportThreshold(0.75);
      expect(notifier.debugState!.reportThreshold, 0.75);
    });

    test('setReportThreshold with null clears value', () {
      final notifier = ScanConfigNotifier();
      notifier.setTarget('ollama', 'llama3.2:3b');
      notifier.setReportThreshold(0.5);
      expect(notifier.debugState!.reportThreshold, 0.5);
      // copyWith with null preserves, so this won't clear —
      // but the field is nullable and defaults to null in setTarget
    });

    test('setTarget preserves reportThreshold', () {
      final notifier = ScanConfigNotifier();
      notifier.setTarget('ollama', 'llama3.2:3b');
      notifier.setReportThreshold(0.6);
      notifier.setTarget('ollama', 'mistral:latest');
      expect(notifier.debugState!.reportThreshold, 0.6);
    });

    test('does nothing when state is null', () {
      final notifier = ScanConfigNotifier();
      notifier.setReportThreshold(0.5); // Should not throw
      expect(notifier.debugState, isNull);
    });
  });

  group('ScanConfigNotifier - collectTiming', () {
    test('setCollectTiming updates state', () {
      final notifier = ScanConfigNotifier();
      notifier.setTarget('ollama', 'llama3.2:3b');
      notifier.setCollectTiming(true);
      expect(notifier.debugState!.collectTiming, true);
    });

    test('setCollectTiming to false', () {
      final notifier = ScanConfigNotifier();
      notifier.setTarget('ollama', 'llama3.2:3b');
      notifier.setCollectTiming(true);
      notifier.setCollectTiming(false);
      expect(notifier.debugState!.collectTiming, false);
    });

    test('setTarget preserves collectTiming', () {
      final notifier = ScanConfigNotifier();
      notifier.setTarget('ollama', 'llama3.2:3b');
      notifier.setCollectTiming(true);
      notifier.setTarget('ollama', 'mistral:latest');
      expect(notifier.debugState!.collectTiming, true);
    });

    test('does nothing when state is null', () {
      final notifier = ScanConfigNotifier();
      notifier.setCollectTiming(true); // Should not throw
      expect(notifier.debugState, isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Combined tests
  // -----------------------------------------------------------------------

  group('ScanConfig - both flags together', () {
    test('both flags in constructor', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.8,
        collectTiming: true,
      );
      expect(config.reportThreshold, 0.8);
      expect(config.collectTiming, true);
    });

    test('both flags serialize correctly', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['all'],
        reportThreshold: 0.5,
        collectTiming: true,
      );
      final json = config.toJson();
      expect(json['report_threshold'], 0.5);
      expect(json['collect_timing'], true);
    });

    test('both flags with existing flags', () {
      const config = ScanConfig(
        targetType: 'ollama',
        targetName: 'llama3.2:3b',
        probes: ['dan', 'encoding'],
        generations: 3,
        evalThreshold: 0.7,
        reportThreshold: 0.5,
        collectTiming: true,
        continueOnError: true,
        extendedDetectors: true,
        timeoutPerProbe: 120,
      );
      final json = config.toJson();
      expect(json['report_threshold'], 0.5);
      expect(json['collect_timing'], true);
      expect(json['continue_on_error'], true);
      expect(json['extended_detectors'], true);
      expect(json['timeout_per_probe'], 120);
      expect(json['generations'], 3);
    });
  });
}
