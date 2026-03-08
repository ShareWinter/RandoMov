import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

enum RoomConnectionStatus { disconnected, connecting, connected, error }

/// Room state management — handles socket lifecycle and room state
class RoomProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  Room? _currentRoom;
  RoomConnectionStatus _connectionStatus = RoomConnectionStatus.disconnected;
  String? _error;
  bool _isLoading = false;

  // Draw-started data (received from server, used for animation)
  DrawStartData? _drawStartData;

  Room? get currentRoom => _currentRoom;
  RoomConnectionStatus get connectionStatus => _connectionStatus;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isInRoom => _currentRoom != null;
  DrawStartData? get drawStartData => _drawStartData;

  bool isHost(String userId) => _currentRoom?.hostId == userId;

  /// Total candidate movies (room-level, host-controlled)
  int get candidateMovieCount {
    return _currentRoom?.selectedMovieIds.length ?? 0;
  }

  final List<StreamSubscription> _subscriptions = [];

  // ==================== Public API ====================

  /// Create a room and join it
  Future<String?> createAndJoinRoom(String userId, String userName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final room = await _apiService.createRoom(userId, userName);
      _currentRoom = room;
      _isLoading = false;
      notifyListeners();
      _connectAndJoin(room.code, userId, userName);
      return room.code;
    } catch (e) {
      _isLoading = false;
      _error = '创建房间失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// Join an existing room by code
  Future<bool> joinRoom(String code, String userId, String userName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final room = await _apiService.getRoom(code);
      _currentRoom = room;
      _isLoading = false;
      notifyListeners();
      _connectAndJoin(code, userId, userName);
      return true;
    } on RoomNotFoundException {
      _isLoading = false;
      _error = '房间不存在';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = '加入房间失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// Leave the current room
  void leaveRoom(String userId) {
    if (_currentRoom == null) return;
    _socketService.emit('leave-room', {
      'roomCode': _currentRoom!.code,
      'userId': userId,
    });
    _cleanup();
    notifyListeners();
  }

  /// Update room movie selection (waiting phase, host only)
  void updateRoomMovies(String userId, List<String> movieIds, Map<String, dynamic> moviesData) {
    if (_currentRoom == null) return;
    _socketService.emit('update-room-movies', {
      'roomCode': _currentRoom!.code,
      'userId': userId,
      'movieIds': movieIds,
      'moviesData': moviesData,
    });
  }

  /// Submit lucky number (collecting phase)
  void submitLuckyNumber(String userId, int number) {
    if (_currentRoom == null) return;
    _socketService.emit('submit-lucky-number', {
      'roomCode': _currentRoom!.code,
      'userId': userId,
      'luckyNumber': number,
    });
  }

  /// Host: start the draw process
  void startDraw(String userId) {
    if (_currentRoom == null) return;
    _socketService.emit('start-draw', {
      'roomCode': _currentRoom!.code,
      'userId': userId,
    });
  }

  /// Host: reset room to waiting
  void resetRoom(String userId) {
    if (_currentRoom == null) return;
    _socketService.emit('reset-room', {
      'roomCode': _currentRoom!.code,
      'userId': userId,
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== Internal ====================

  void _connectAndJoin(String roomCode, String userId, String userName) {
    // Always clean up any previous socket session before connecting.
    // This prevents stale SocketService singleton state where _socket != null
    // but is connected to a previous room, causing connect() to skip and
    // join-room to never be emitted.
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _socketService.disconnect();

    _connectionStatus = RoomConnectionStatus.connecting;
    notifyListeners();

    _socketService.connect(ApiConfig.socketUrl);

    // Connection status
    _subscriptions.add(
      _socketService.statusStream.listen((status) {
        switch (status) {
          case SocketConnectionStatus.connected:
            _connectionStatus = RoomConnectionStatus.connected;
            _socketService.emit('join-room', {
              'roomCode': roomCode,
              'userId': userId,
              'userName': userName,
            });
            break;
          case SocketConnectionStatus.connecting:
            _connectionStatus = RoomConnectionStatus.connecting;
            break;
          case SocketConnectionStatus.disconnected:
            _connectionStatus = RoomConnectionStatus.disconnected;
            break;
          case SocketConnectionStatus.error:
            _connectionStatus = RoomConnectionStatus.error;
            break;
        }
        notifyListeners();
      }),
    );

    // Room state updates
    _subscriptions.add(
      _socketService.on('room-updated').listen((raw) {
        final data = ApiService.asMap(raw);
        _currentRoom = Room.fromJson(ApiService.asMap(data['room']));
        notifyListeners();
      }),
    );

    // Draw animation start
    _subscriptions.add(
      _socketService.on('draw-started').listen((raw) {
        final data = ApiService.asMap(raw);
        _drawStartData = DrawStartData.fromJson(data);
        notifyListeners();
      }),
    );

    // Draw result
    _subscriptions.add(
      _socketService.on('draw-result').listen((raw) {
        final data = ApiService.asMap(raw);
        _currentRoom = Room.fromJson(ApiService.asMap(data['room']));
        notifyListeners();
      }),
    );

    // Room reset
    _subscriptions.add(
      _socketService.on('room-reset').listen((raw) {
        final data = ApiService.asMap(raw);
        _currentRoom = Room.fromJson(ApiService.asMap(data['room']));
        _drawStartData = null;
        notifyListeners();
      }),
    );

    // Room closed
    _subscriptions.add(
      _socketService.on('room-closed').listen((raw) {
        final data = ApiService.asMap(raw);
        _error = data['reason']?.toString() ?? '房间已关闭';
        _cleanup();
        notifyListeners();
      }),
    );

    // Kicked
    _subscriptions.add(
      _socketService.on('kicked').listen((raw) {
        final data = ApiService.asMap(raw);
        _error = data['reason']?.toString() ?? '你已被移出房间';
        _cleanup();
        notifyListeners();
      }),
    );

    // Error
    _subscriptions.add(
      _socketService.on('error').listen((raw) {
        final data = ApiService.asMap(raw);
        _error = data['message']?.toString() ?? '未知错误';
        notifyListeners();
      }),
    );
  }

  void _cleanup() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _socketService.disconnect();
    _currentRoom = null;
    _drawStartData = null;
    _connectionStatus = RoomConnectionStatus.disconnected;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
