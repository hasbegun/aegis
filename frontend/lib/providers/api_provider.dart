import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/constants.dart';

/// Get the appropriate base URL for the current platform
String _getPlatformAwareUrl(String defaultUrl) {
  // On Android emulator, localhost needs to be 10.0.2.2
  if (Platform.isAndroid && defaultUrl.contains('localhost')) {
    return defaultUrl.replaceAll('localhost', '10.0.2.2');
  }
  return defaultUrl;
}

/// Network settings data class
class NetworkSettings {
  final String apiUrl;
  final String wsUrl;
  final int connectionTimeout;
  final int receiveTimeout;
  final int wsReconnectDelay;

  NetworkSettings({
    required this.apiUrl,
    required this.wsUrl,
    required this.connectionTimeout,
    required this.receiveTimeout,
    required this.wsReconnectDelay,
  });
}

/// Provider for network settings loaded from SharedPreferences
final networkSettingsProvider = FutureProvider<NetworkSettings>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  final apiUrl = prefs.getString(AppConstants.keyApiUrl) ?? AppConstants.apiBaseUrl;
  final connectionTimeout = prefs.getInt(AppConstants.keyConnectionTimeout) ?? AppConstants.connectionTimeout;
  final receiveTimeout = prefs.getInt(AppConstants.keyReceiveTimeout) ?? AppConstants.receiveTimeout;
  final wsReconnectDelay = prefs.getInt(AppConstants.keyWsReconnectDelay) ?? AppConstants.wsReconnectDelay;

  // Derive WebSocket URL from API URL
  final wsUrl = apiUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');

  return NetworkSettings(
    apiUrl: _getPlatformAwareUrl(apiUrl),
    wsUrl: _getPlatformAwareUrl(wsUrl),
    connectionTimeout: connectionTimeout,
    receiveTimeout: receiveTimeout,
    wsReconnectDelay: wsReconnectDelay,
  );
});

/// Provider for the API service that reads from settings
final apiServiceProvider = Provider<ApiService>((ref) {
  // This will use the default URL initially, but can be overridden
  // by the settings. The app will need to restart to pick up changes.
  final baseUrl = _getPlatformAwareUrl(AppConstants.apiBaseUrl);
  return ApiService(baseUrl: baseUrl);
});

/// Provider for configured API URL from settings
final configuredApiUrlProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('api_url');
  return _getPlatformAwareUrl(savedUrl ?? AppConstants.apiBaseUrl);
});

/// Provider for the WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final baseUrl = _getPlatformAwareUrl(AppConstants.wsBaseUrl);
  return WebSocketService(baseUrl: baseUrl);
});

/// Provider for API service with network settings applied
final configuredApiServiceProvider = FutureProvider<ApiService>((ref) async {
  final settings = await ref.watch(networkSettingsProvider.future);
  return ApiService(
    baseUrl: settings.apiUrl,
    connectionTimeout: settings.connectionTimeout,
    receiveTimeout: settings.receiveTimeout,
  );
});

/// Provider for WebSocket service with network settings applied
final configuredWebSocketServiceProvider = FutureProvider<WebSocketService>((ref) async {
  final settings = await ref.watch(networkSettingsProvider.future);
  return WebSocketService(
    baseUrl: settings.wsUrl,
    wsReconnectDelay: settings.wsReconnectDelay,
  );
});
