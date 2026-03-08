import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:random_movie/models/models.dart';

/// 本地存储服务
class StorageService {
  static const String _userIdKey = 'movie_app_user_id';
  static const String _userNameKey = 'movie_app_user_name';
  static const String _moviesKey = 'movie_app_local_movies';
  static const String _drawHistoryKey = 'movie_app_draw_history';
  static const int _maxDrawHistory = 100;

  late SharedPreferences _prefs;

  // 单例模式
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== 用户管理 ==========

  Future<LocalUser> getOrCreateUser() async {
    String? userId = _prefs.getString(_userIdKey);
    String? userName = _prefs.getString(_userNameKey);

    if (userId == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _generateRandomString(6);
      userId = 'user_${timestamp}_$random';
      await _prefs.setString(_userIdKey, userId);
    }

    if (userName == null) {
      userName = '用户${_generateRandomNumber(4)}';
      await _prefs.setString(_userNameKey, userName);
    }

    return LocalUser(id: userId, name: userName);
  }

  Future<void> updateUserName(String newName) async {
    await _prefs.setString(_userNameKey, newName);
  }

  String? get userId => _prefs.getString(_userIdKey);
  String? get userName => _prefs.getString(_userNameKey);

  // ========== 影片管理 ==========

  List<Movie> getMovies() {
    final String? data = _prefs.getString(_moviesKey);
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Movie.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveMovies(List<Movie> movies) async {
    final jsonList = movies.map((m) => m.toJson()).toList();
    await _prefs.setString(_moviesKey, jsonEncode(jsonList));
  }

  Future<Movie> addMovie(Movie movie) async {
    final movies = getMovies();

    // 有预设 ID（豆瓣影片）时检查是否已存在
    if (movie.id.isNotEmpty) {
      for (final existing in movies) {
        if (existing.id == movie.id) {
          throw DuplicateMovieException(existing);
        }
      }
    }

    // 豆瓣影片保留其 ID；手动添加则生成本地 ID
    final newMovie = movie.id.isNotEmpty
        ? movie
        : movie.copyWith(
            id: 'movie_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(4)}',
          );

    movies.insert(0, newMovie);
    await saveMovies(movies);
    return newMovie;
  }

  Future<void> updateMovie(Movie updatedMovie) async {
    final movies = getMovies();
    final index = movies.indexWhere((m) => m.id == updatedMovie.id);
    if (index != -1) {
      movies[index] = updatedMovie;
      await saveMovies(movies);
    }
  }

  Future<void> deleteMovie(String movieId) async {
    final movies = getMovies();
    movies.removeWhere((m) => m.id == movieId);
    await saveMovies(movies);
  }

  // ========== 抽奖历史 ==========

  List<DrawRecord> getDrawHistory() {
    final String? data = _prefs.getString(_drawHistoryKey);
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((json) => DrawRecord.fromJson(json))
          .toList()
        ..sort((a, b) => b.drawnAt.compareTo(a.drawnAt));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveDrawHistory(List<DrawRecord> records) async {
    final jsonList = records.map((r) => r.toJson()).toList();
    await _prefs.setString(_drawHistoryKey, jsonEncode(jsonList));
  }

  Future<void> addDrawRecord(DrawRecord record) async {
    final records = getDrawHistory();
    records.insert(0, record);
    if (records.length > _maxDrawHistory) {
      records.removeRange(_maxDrawHistory, records.length);
    }
    await saveDrawHistory(records);
  }

  Future<void> clearDrawHistory() async {
    await _prefs.remove(_drawHistoryKey);
  }

  // ========== 工具方法 ==========

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    final random = Random();
    for (int i = 0; i < length; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String _generateRandomNumber(int length) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mod = pow(10, length) as int;
    return (timestamp % mod).toString().padLeft(length, '0');
  }
}

class DuplicateMovieException implements Exception {
  final Movie existingMovie;
  DuplicateMovieException(this.existingMovie);

  @override
  String toString() => '影片「${existingMovie.title}」已在片库中';
}
