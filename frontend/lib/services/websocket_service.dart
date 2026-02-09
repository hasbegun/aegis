import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import '../config/constants.dart';
import '../models/scan_status.dart';

/// Represents a single scan's WebSocket connection
class _ScanConnection {
  static const int maxReconnectAttempts = 3;

  final String scanId;
  final WebSocketChannel channel;
  final StreamController<ScanStatusInfo> controller;
  Timer? reconnectTimer;
  bool isConnected;
  int reconnectAttempts;

  _ScanConnection({
    required this.scanId,
    required this.channel,
    required this.controller,
    this.isConnected = true,
    this.reconnectAttempts = 0,
  });

  void dispose() {
    reconnectTimer?.cancel();
    channel.sink.close();
    controller.close();
  }
}

/// Service for WebSocket connections to receive real-time scan updates
/// Supports multiple concurrent scan connections
class WebSocketService {
  final Logger _logger = Logger();
  final String baseUrl;
  final int wsReconnectDelay;

  // Map of scan ID to connection
  final Map<String, _ScanConnection> _connections = {};

  WebSocketService({
    this.baseUrl = AppConstants.wsBaseUrl,
    this.wsReconnectDelay = AppConstants.wsReconnectDelay,
  });

  /// Connect to scan progress WebSocket
  Stream<ScanStatusInfo> connectToScanProgress(String scanId) {
    // If already connected to this scan, return existing stream
    if (_connections.containsKey(scanId)) {
      _logger.w('Already connected to scan $scanId, returning existing stream');
      return _connections[scanId]!.controller.stream;
    }

    // Create new controller for this scan
    final controller = StreamController<ScanStatusInfo>.broadcast();

    // Connect to WebSocket
    _connect(scanId, controller);

    return controller.stream;
  }

  void _connect(String scanId, StreamController<ScanStatusInfo> controller) {
    try {
      final uri = Uri.parse('$baseUrl/scan/$scanId/progress');
      _logger.i('Connecting to WebSocket for scan $scanId: $uri');

      final channel = WebSocketChannel.connect(uri);

      // Store connection
      _connections[scanId] = _ScanConnection(
        scanId: scanId,
        channel: channel,
        controller: controller,
        isConnected: true,
      );

      channel.stream.listen(
        (message) {
          // Reset reconnect counter on successful message
          if (_connections[scanId] != null) {
            _connections[scanId]!.reconnectAttempts = 0;
          }
          _handleMessage(scanId, message);
        },
        onError: (error) {
          _logger.e('WebSocket error for scan $scanId: $error');
          _handleError(scanId, error);
        },
        onDone: () {
          _logger.i('WebSocket connection closed for scan $scanId');
          _connections[scanId]?.isConnected = false;
          _tryReconnect(scanId);
        },
        cancelOnError: false,
      );
    } catch (e) {
      _logger.e('Error connecting to WebSocket for scan $scanId: $e');
      _handleError(scanId, e);
    }
  }

  void _handleMessage(String expectedScanId, dynamic message) {
    try {
      _logger.d('Received WebSocket message for scan $expectedScanId');
      final data = json.decode(message as String);

      // Check for error messages
      if (data.containsKey('error')) {
        _logger.e('WebSocket error message for scan $expectedScanId: ${data['error']}');
        return;
      }

      // Parse status update (every message includes scan_id)
      if (data.containsKey('scan_id')) {
        _logger.d('Parsing status update: progress=${data['progress']}, status=${data['status']}');
        final statusInfo = ScanStatusInfo.fromJson(data);

        // IMPORTANT: Verify scan ID matches expected scan
        if (statusInfo.scanId != expectedScanId) {
          _logger.w(
            'Received status for scan ${statusInfo.scanId} but expected $expectedScanId. Ignoring.',
          );
          return;
        }

        _logger.d('Parsed status: progress=${statusInfo.progress}, status=${statusInfo.status}');

        // Send update to the correct scan's controller
        final connection = _connections[expectedScanId];
        if (connection != null && !connection.controller.isClosed) {
          _logger.d('Adding status to controller for scan $expectedScanId');
          connection.controller.add(statusInfo);
        } else {
          _logger.w('Connection not found or controller closed for scan $expectedScanId');
        }

        // Disconnect after forwarding final status
        if (statusInfo.status.isFinished) {
          _logger.i('Scan $expectedScanId finished: ${statusInfo.status}');
          disconnectScan(expectedScanId);
        }
      } else {
        _logger.w('Message does not contain scan_id field');
      }
    } catch (e) {
      _logger.e('Error parsing WebSocket message for scan $expectedScanId: $e');
      _logger.e('Stack trace: ${StackTrace.current}');
    }
  }

  void _handleError(String scanId, dynamic error) {
    final connection = _connections[scanId];
    if (connection != null && !connection.controller.isClosed) {
      connection.controller.addError(error);
    }
    if (_connections.containsKey(scanId)) {
      _connections[scanId]!.isConnected = false;
    }
  }

  void _tryReconnect(String scanId) {
    final connection = _connections[scanId];
    if (connection == null || connection.reconnectTimer != null) {
      return;
    }

    if (connection.reconnectAttempts >= _ScanConnection.maxReconnectAttempts) {
      _logger.w('Max reconnect attempts reached for scan $scanId. Giving up.');
      if (!connection.controller.isClosed) {
        connection.controller.addError(
          'Connection lost: backend is not reachable',
        );
      }
      disconnectScan(scanId);
      return;
    }

    connection.reconnectAttempts++;
    _logger.i(
      'Reconnect attempt ${connection.reconnectAttempts}/${_ScanConnection.maxReconnectAttempts} '
      'for scan $scanId in ${wsReconnectDelay}s...',
    );

    connection.reconnectTimer = Timer(
      Duration(seconds: wsReconnectDelay),
      () {
        final conn = _connections[scanId];
        if (conn != null && !conn.isConnected) {
          conn.reconnectTimer = null;
          // Dispose old channel
          conn.channel.sink.close();

          // Reconnect
          _connect(scanId, conn.controller);
        }
      },
    );
  }

  /// Disconnect from WebSocket for a specific scan
  void disconnectScan(String scanId) {
    _logger.i('Disconnecting WebSocket for scan $scanId');

    final connection = _connections.remove(scanId);
    connection?.dispose();
  }

  /// Disconnect from all WebSockets (legacy compatibility)
  void disconnect() {
    _logger.i('Disconnecting all WebSocket connections');

    for (final connection in _connections.values) {
      connection.dispose();
    }
    _connections.clear();
  }

  /// Check if currently connected to a specific scan
  bool isConnectedToScan(String scanId) {
    return _connections[scanId]?.isConnected ?? false;
  }

  /// Check if any scan is connected
  bool get isConnected => _connections.values.any((c) => c.isConnected);

  /// Get count of active connections
  int get activeConnectionCount => _connections.length;

  /// Clean up resources
  void dispose() {
    disconnect();
  }
}
