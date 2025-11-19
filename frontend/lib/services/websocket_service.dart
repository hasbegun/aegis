import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import '../models/scan_status.dart';

/// Service for WebSocket connections to receive real-time scan updates
class WebSocketService {
  final Logger _logger = Logger();
  final String baseUrl;
  final int wsReconnectDelay;

  WebSocketChannel? _channel;
  StreamController<ScanStatusInfo>? _controller;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _currentScanId;

  WebSocketService({
    this.baseUrl = AppConstants.wsBaseUrl,
    this.wsReconnectDelay = AppConstants.wsReconnectDelay,
  });

  /// Connect to scan progress WebSocket
  Stream<ScanStatusInfo> connectToScanProgress(String scanId) {
    _currentScanId = scanId;
    _controller = StreamController<ScanStatusInfo>.broadcast();

    _connect(scanId);

    return _controller!.stream;
  }

  void _connect(String scanId) {
    try {
      final uri = Uri.parse('$baseUrl/scan/$scanId/progress');
      _logger.i('Connecting to WebSocket: $uri');

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _logger.e('WebSocket error: $error');
          _handleError(error);
        },
        onDone: () {
          _logger.i('WebSocket connection closed');
          _isConnected = false;
          _tryReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _logger.e('Error connecting to WebSocket: $e');
      _handleError(e);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String);

      // Check for error messages
      if (data.containsKey('error')) {
        _logger.e('WebSocket error message: ${data['error']}');
        return;
      }

      // Check for completion message
      if (data.containsKey('message') && data['message'] == 'Scan finished') {
        _logger.i('Scan finished: ${data['final_status']}');
        disconnect();
        return;
      }

      // Parse status update
      if (data.containsKey('scan_id')) {
        final statusInfo = ScanStatusInfo.fromJson(data);
        _controller?.add(statusInfo);
      }
    } catch (e) {
      _logger.e('Error parsing WebSocket message: $e');
    }
  }

  void _handleError(dynamic error) {
    _controller?.addError(error);
    _isConnected = false;
  }

  void _tryReconnect() {
    if (_currentScanId == null || _reconnectTimer != null) {
      return;
    }

    _logger.i('Attempting to reconnect in ${wsReconnectDelay}s...');

    _reconnectTimer = Timer(
      Duration(seconds: wsReconnectDelay),
      () {
        _reconnectTimer = null;
        if (_currentScanId != null && !_isConnected) {
          _connect(_currentScanId!);
        }
      },
    );
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _logger.i('Disconnecting WebSocket');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _channel?.sink.close();
    _channel = null;

    _controller?.close();
    _controller = null;

    _isConnected = false;
    _currentScanId = null;
  }

  /// Check if currently connected
  bool get isConnected => _isConnected;

  /// Clean up resources
  void dispose() {
    disconnect();
  }
}
