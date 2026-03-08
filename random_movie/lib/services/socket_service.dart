import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum SocketConnectionStatus { disconnected, connecting, connected, error }

/// Socket.IO connection lifecycle manager — singleton
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  SocketConnectionStatus _status = SocketConnectionStatus.disconnected;

  final _statusController = StreamController<SocketConnectionStatus>.broadcast();
  Stream<SocketConnectionStatus> get statusStream => _statusController.stream;
  SocketConnectionStatus get status => _status;
  bool get isConnected => _status == SocketConnectionStatus.connected;

  final Map<String, StreamController<dynamic>> _eventControllers = {};

  /// Connect to server
  void connect(String socketUrl) {
    if (_socket != null) return;

    _updateStatus(SocketConnectionStatus.connecting);

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Connected');
      _updateStatus(SocketConnectionStatus.connected);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected');
      _updateStatus(SocketConnectionStatus.disconnected);
    });

    _socket!.onConnectError((err) {
      debugPrint('[SocketService] Connect error: $err');
      _updateStatus(SocketConnectionStatus.error);
    });

    _socket!.onReconnecting((_) {
      _updateStatus(SocketConnectionStatus.connecting);
    });

    _socket!.connect();
  }

  /// Disconnect and clean up
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateStatus(SocketConnectionStatus.disconnected);
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }

  /// Emit an event
  void emit(String event, [dynamic data]) {
    if (_socket == null || !isConnected) {
      debugPrint('[SocketService] Cannot emit "$event": not connected');
      return;
    }
    _socket!.emit(event, data);
  }

  /// Listen to an event, returns a broadcast Stream
  Stream<dynamic> on(String event) {
    if (!_eventControllers.containsKey(event)) {
      final controller = StreamController<dynamic>.broadcast();
      _eventControllers[event] = controller;
      _socket?.on(event, (data) {
        if (!controller.isClosed) controller.add(data);
      });
    }
    return _eventControllers[event]!.stream;
  }

  /// Remove listener for a specific event
  void off(String event) {
    _socket?.off(event);
    _eventControllers[event]?.close();
    _eventControllers.remove(event);
  }

  void _updateStatus(SocketConnectionStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) _statusController.add(newStatus);
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}
