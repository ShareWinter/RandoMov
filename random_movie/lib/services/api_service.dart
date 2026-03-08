import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/models/models.dart';

/// API 服务
class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: ApiConfig.defaultHeaders,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          debugPrint('REQUEST[${options.method}] => PATH: ${options.path}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Auto-decode: if Dio returned a raw String, parse it as JSON
        if (response.data is String) {
          try {
            response.data = jsonDecode(response.data as String);
          } catch (_) {
            // Not valid JSON, keep as-is
          }
        }
        if (kDebugMode) {
          debugPrint('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}'
              ' (type: ${response.data.runtimeType})');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        // Also auto-decode error responses
        if (e.response?.data is String) {
          try {
            e.response!.data = jsonDecode(e.response!.data as String);
          } catch (_) {}
        }
        if (kDebugMode) {
          debugPrint('ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}');
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;

  /// Safely parse data — handles String, Map, and null
  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  // ========== 房间相关 API ==========

  Future<Room> createRoom(String hostId, String hostName) async {
    try {
      final response = await _dio.post('/api/rooms', data: {
        'hostId': hostId,
        'hostName': hostName,
      });
      final body = asMap(response.data);
      return Room.fromJson(asMap(body['room']));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Room> getRoom(String code) async {
    try {
      final response = await _dio.get('/api/rooms', queryParameters: {'code': code});
      final body = asMap(response.data);
      return Room.fromJson(asMap(body['room']));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw RoomNotFoundException();
      }
      throw _handleError(e);
    }
  }

  // ========== 历史相关 API ==========

  Future<List<DrawHistory>> getHistory(String roomCode, {int limit = 20, int skip = 0}) async {
    try {
      final response = await _dio.get('/api/history', queryParameters: {
        'roomCode': roomCode,
        'limit': limit,
        'skip': skip,
      });
      final body = asMap(response.data);
      final List<dynamic> history = body['history'] ?? [];
      return history.map((json) => DrawHistory.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ========== 错误处理 ==========

  Exception _handleError(DioException e) {
    final data = asMap(e.response?.data);
    if (data['error'] != null) {
      return ApiException(data['error'].toString());
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout) {
      return ApiException('连接超时，请检查网络');
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return ApiException('响应超时，请稍后重试');
    }
    return ApiException('网络错误: ${e.message}');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class RoomNotFoundException implements Exception {
  @override
  String toString() => '房间不存在';
}
