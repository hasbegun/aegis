import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

/// Service for showing scan notifications
class ScanNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  bool _initialized = false;

  // Notification channels
  static const String _channelId = 'background_scans';
  static const String _channelName = 'Background Scans';
  static const String _channelDescription = 'Notifications for background scan progress and completion';

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // macOS initialization
      const macSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for iOS/macOS
      if (Platform.isIOS || Platform.isMacOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );

        await _notifications
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      _initialized = true;
      _logger.i('Scan notification service initialized');
    } catch (e) {
      _logger.e('Failed to initialize notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    _logger.d('Notification tapped: ${response.payload}');
    // TODO: Navigate to scan details
    // This will be handled by the app's navigation logic
  }

  /// Show scan completion notification
  Future<void> showCompletionNotification({
    required String scanId,
    required String scanName,
    bool success = true,
  }) async {
    if (!_initialized) {
      _logger.w('Notifications not initialized');
      return;
    }

    try {
      final notificationId = scanId.hashCode;

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        success ? 'Scan Completed ✓' : 'Scan Failed ✗',
        scanName,
        notificationDetails,
        payload: scanId,
      );

      _logger.i('Showed completion notification for scan $scanId');
    } catch (e) {
      _logger.e('Failed to show completion notification: $e');
    }
  }

  /// Show scan error notification
  Future<void> showErrorNotification({
    required String scanId,
    required String scanName,
    String? errorMessage,
  }) async {
    if (!_initialized) return;

    try {
      final notificationId = scanId.hashCode;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFB00020), // Error color
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        'Scan Failed',
        errorMessage ?? scanName,
        notificationDetails,
        payload: scanId,
      );

      _logger.i('Showed error notification for scan $scanId');
    } catch (e) {
      _logger.e('Failed to show error notification: $e');
    }
  }

  /// Show progress notification (Android only - ongoing)
  Future<void> showProgressNotification({
    required String scanId,
    required String scanName,
    required int progress,
    required int maxProgress,
  }) async {
    if (!_initialized || !Platform.isAndroid) return;

    try {
      final notificationId = scanId.hashCode;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        notificationId,
        'Scan Running',
        '$scanName - ${(progress / maxProgress * 100).toStringAsFixed(0)}%',
        notificationDetails,
        payload: scanId,
      );
    } catch (e) {
      _logger.e('Failed to show progress notification: $e');
    }
  }

  /// Cancel notification for specific scan
  Future<void> cancelNotification(String scanId) async {
    try {
      final notificationId = scanId.hashCode;
      await _notifications.cancel(notificationId);
      _logger.d('Cancelled notification for scan $scanId');
    } catch (e) {
      _logger.e('Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.i('Cancelled all notifications');
    } catch (e) {
      _logger.e('Failed to cancel all notifications: $e');
    }
  }

  /// Check if notifications are supported
  bool get isSupported {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Dispose
  void dispose() {
    _logger.d('Scan notification service disposed');
  }
}
