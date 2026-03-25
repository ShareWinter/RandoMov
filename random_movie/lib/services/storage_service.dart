import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:random_movie/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// 本地存储服务
class StorageService {
  static const String _userIdKey = 'movie_app_user_id';
  static const String _userNameKey = 'movie_app_user_name';
  static const String _legacyMoviesKey = 'movie_app_local_movies';
  static const String _legacyDrawHistoryKey = 'movie_app_draw_history';
  static const String _migrationFlagKey = 'movie_app_storage_migrated_v2';
  static const String _databaseName = 'random_movie.db';
  static const int _databaseVersion = 2;
  static const int _maxDrawHistory = 100;
  static const String _moviesTable = 'movies';
  static const String _drawRecordsTable = 'draw_records';

  late SharedPreferences _prefs;
  late Database _db;
  bool _initialized = false;

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      path.join(dbPath, _databaseName),
      version: _databaseVersion,
      onCreate: (db, _) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeDatabase(db, oldVersion, newVersion);
      },
    );
    _initialized = true;
    await _migrateLegacyData();
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_moviesTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        year TEXT NOT NULL DEFAULT '',
        subject_type TEXT NOT NULL DEFAULT 'movie',
        director TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        cast_text TEXT NOT NULL DEFAULT '',
        rating REAL NOT NULL DEFAULT 0,
        genre_json TEXT NOT NULL DEFAULT '[]',
        region TEXT NOT NULL DEFAULT '',
        summary TEXT NOT NULL DEFAULT '',
        published_at TEXT NOT NULL DEFAULT '',
        duration_text TEXT NOT NULL DEFAULT '',
        episodes_json TEXT NOT NULL DEFAULT '[]',
        poster TEXT NOT NULL DEFAULT '',
        douban_url TEXT NOT NULL DEFAULT '',
        watched INTEGER NOT NULL DEFAULT 0,
        watched_at TEXT,
        user_rating REAL,
        user_review TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_movies_created_at ON $_moviesTable(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_movies_watched_history ON $_moviesTable(watched, watched_at DESC, created_at DESC)',
    );

    await db.execute('''
      CREATE TABLE $_drawRecordsTable (
        id TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        room_code TEXT,
        movie_id TEXT NOT NULL,
        movie_title TEXT NOT NULL,
        movie_poster TEXT NOT NULL DEFAULT '',
        seed INTEGER NOT NULL DEFAULT 0,
        participants_json TEXT NOT NULL DEFAULT '[]',
        candidate_count INTEGER NOT NULL DEFAULT 0,
        drawn_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_draw_records_drawn_at ON $_drawRecordsTable(drawn_at DESC)',
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion >= newVersion) return;

    if (oldVersion < 2) {
      await _addMovieColumnIfMissing(
        db,
        columnName: 'subject_type',
        columnDefinition: "TEXT NOT NULL DEFAULT 'movie'",
      );
      await _addMovieColumnIfMissing(
        db,
        columnName: 'author',
        columnDefinition: "TEXT NOT NULL DEFAULT ''",
      );
      await _addMovieColumnIfMissing(
        db,
        columnName: 'summary',
        columnDefinition: "TEXT NOT NULL DEFAULT ''",
      );
      await _addMovieColumnIfMissing(
        db,
        columnName: 'published_at',
        columnDefinition: "TEXT NOT NULL DEFAULT ''",
      );
      await _addMovieColumnIfMissing(
        db,
        columnName: 'duration_text',
        columnDefinition: "TEXT NOT NULL DEFAULT ''",
      );
      await _addMovieColumnIfMissing(
        db,
        columnName: 'episodes_json',
        columnDefinition: "TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  Future<void> _addMovieColumnIfMissing(
    Database db, {
    required String columnName,
    required String columnDefinition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($_moviesTable)');
    final exists = columns.any((row) => row['name']?.toString() == columnName);
    if (exists) return;

    await db.execute(
      'ALTER TABLE $_moviesTable ADD COLUMN $columnName $columnDefinition',
    );
  }

  Future<void> _migrateLegacyData() async {
    final migrated = _prefs.getBool(_migrationFlagKey) ?? false;
    if (migrated) return;

    final movieCount = await countMovies();
    final drawRecordCount = await countDrawRecords();
    var shouldClearLegacyMovies = false;
    var shouldClearLegacyDrawHistory = false;

    final legacyMovies = _prefs.getString(_legacyMoviesKey);
    if (movieCount == 0 && legacyMovies != null && legacyMovies.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyMovies) as List<dynamic>;
        final movies = decoded
            .whereType<Map>()
            .map((json) => Movie.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        final batch = _db.batch();
        for (final movie in movies) {
          batch.insert(
            _moviesTable,
            _movieToDbMap(movie),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        shouldClearLegacyMovies = true;
      } catch (_) {}
    } else if (movieCount > 0 || legacyMovies == null || legacyMovies.isEmpty) {
      shouldClearLegacyMovies = legacyMovies != null;
    }

    final legacyDrawHistory = _prefs.getString(_legacyDrawHistoryKey);
    if (drawRecordCount == 0 &&
        legacyDrawHistory != null &&
        legacyDrawHistory.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyDrawHistory) as List<dynamic>;
        final records = decoded
            .whereType<Map>()
            .map((json) => DrawRecord.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        final batch = _db.batch();
        for (final record in records.take(_maxDrawHistory)) {
          batch.insert(
            _drawRecordsTable,
            _drawRecordToDbMap(record),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        shouldClearLegacyDrawHistory = true;
      } catch (_) {}
    } else if (drawRecordCount > 0 ||
        legacyDrawHistory == null ||
        legacyDrawHistory.isEmpty) {
      shouldClearLegacyDrawHistory = legacyDrawHistory != null;
    }

    if (shouldClearLegacyMovies) {
      await _prefs.remove(_legacyMoviesKey);
    }
    if (shouldClearLegacyDrawHistory) {
      await _prefs.remove(_legacyDrawHistoryKey);
    }
    final moviesReady =
        shouldClearLegacyMovies ||
        movieCount > 0 ||
        legacyMovies == null ||
        legacyMovies.isEmpty;
    final drawHistoryReady =
        shouldClearLegacyDrawHistory ||
        drawRecordCount > 0 ||
        legacyDrawHistory == null ||
        legacyDrawHistory.isEmpty;
    if (moviesReady && drawHistoryReady) {
      await _prefs.setBool(_migrationFlagKey, true);
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('StorageService.init() 尚未完成');
    }
  }

  // ========== 用户管理 ==========

  Future<LocalUser> getOrCreateUser() async {
    _ensureInitialized();

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
    _ensureInitialized();
    await _prefs.setString(_userNameKey, newName);
  }

  String? get userId => _prefs.getString(_userIdKey);
  String? get userName => _prefs.getString(_userNameKey);

  // ========== 电影 ==========

  Future<int> countMovies({
    String searchQuery = '',
    bool watchedOnly = false,
    bool unwatchedOnly = false,
  }) async {
    _ensureInitialized();

    final clause = _buildMovieWhereClause(
      searchQuery: searchQuery,
      watchedOnly: watchedOnly,
      unwatchedOnly: unwatchedOnly,
    );
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_moviesTable${clause.where == null ? '' : ' WHERE ${clause.where}'}',
      clause.whereArgs,
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Movie>> queryMovies({
    required int limit,
    required int offset,
    String searchQuery = '',
    bool watchedOnly = false,
    bool unwatchedOnly = false,
  }) async {
    _ensureInitialized();

    final clause = _buildMovieWhereClause(
      searchQuery: searchQuery,
      watchedOnly: watchedOnly,
      unwatchedOnly: unwatchedOnly,
    );
    final rows = await _db.query(
      _moviesTable,
      where: clause.where,
      whereArgs: clause.whereArgs,
      orderBy: watchedOnly
          ? 'COALESCE(watched_at, created_at) DESC, created_at DESC'
          : 'watched ASC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_movieFromDbMap).toList();
  }

  Future<List<String>> queryMovieIds({
    String searchQuery = '',
    bool watchedOnly = false,
    bool unwatchedOnly = false,
  }) async {
    _ensureInitialized();

    final clause = _buildMovieWhereClause(
      searchQuery: searchQuery,
      watchedOnly: watchedOnly,
      unwatchedOnly: unwatchedOnly,
    );
    final rows = await _db.query(
      _moviesTable,
      columns: const ['id'],
      where: clause.where,
      whereArgs: clause.whereArgs,
      orderBy: watchedOnly
          ? 'COALESCE(watched_at, created_at) DESC, created_at DESC'
          : 'watched ASC, created_at DESC',
    );
    return rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<Movie?> getMovieById(String id) async {
    _ensureInitialized();

    final rows = await _db.query(
      _moviesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _movieFromDbMap(rows.first);
  }

  Future<List<Movie>> getMoviesByIds(Iterable<String> ids) async {
    _ensureInitialized();

    final orderedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (orderedIds.isEmpty) return const [];

    final movieById = <String, Movie>{};
    for (final chunk in _chunkList(orderedIds, 800)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db.rawQuery(
        'SELECT * FROM $_moviesTable WHERE id IN ($placeholders)',
        chunk,
      );
      for (final row in rows) {
        final movie = _movieFromDbMap(row);
        movieById[movie.id] = movie;
      }
    }

    return orderedIds.map((id) => movieById[id]).whereType<Movie>().toList();
  }

  Future<Movie> addMovie(Movie movie) async {
    _ensureInitialized();

    if (movie.id.isNotEmpty) {
      final existing = await getMovieById(movie.id);
      if (existing != null) {
        throw DuplicateMovieException(existing);
      }
    }

    final newMovie = movie.id.isNotEmpty
        ? movie
        : movie.copyWith(
            id: 'movie_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(4)}',
          );

    await _db.insert(
      _moviesTable,
      _movieToDbMap(newMovie),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return newMovie;
  }

  Future<void> updateMovie(Movie updatedMovie) async {
    _ensureInitialized();
    await _db.update(
      _moviesTable,
      _movieToDbMap(updatedMovie),
      where: 'id = ?',
      whereArgs: [updatedMovie.id],
    );
  }

  Future<void> deleteMovie(String movieId) async {
    _ensureInitialized();
    await _db.delete(_moviesTable, where: 'id = ?', whereArgs: [movieId]);
  }

  // ========== 抽奖历史 ==========

  Future<int> countDrawRecords() async {
    _ensureInitialized();

    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_drawRecordsTable',
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<DrawRecord>> queryDrawRecords({
    required int limit,
    required int offset,
  }) async {
    _ensureInitialized();

    final rows = await _db.query(
      _drawRecordsTable,
      orderBy: 'drawn_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_drawRecordFromDbMap).toList();
  }

  Future<void> addDrawRecord(DrawRecord record) async {
    _ensureInitialized();

    await _db.insert(
      _drawRecordsTable,
      _drawRecordToDbMap(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.rawDelete(
      '''
        DELETE FROM $_drawRecordsTable
        WHERE id IN (
          SELECT id FROM $_drawRecordsTable
          ORDER BY drawn_at DESC
          LIMIT -1 OFFSET ?
        )
      ''',
      [_maxDrawHistory],
    );
  }

  Future<void> clearDrawHistory() async {
    _ensureInitialized();
    await _db.delete(_drawRecordsTable);
  }

  // ========== 映射 ==========

  _SqlClause _buildMovieWhereClause({
    required String searchQuery,
    required bool watchedOnly,
    required bool unwatchedOnly,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];

    if (watchedOnly) {
      conditions.add('watched = 1');
    } else if (unwatchedOnly) {
      conditions.add('watched = 0');
    }

    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      const fields = ['LOWER(title)', 'LOWER(director)', 'LOWER(cast_text)'];
      final like = '%$normalizedQuery%';
      conditions.add(
        '(${fields.map((field) => '$field LIKE ?').join(' OR ')})',
      );
      args.addAll(List<Object?>.filled(fields.length, like));
    }

    if (conditions.isEmpty) {
      return const _SqlClause();
    }

    return _SqlClause(where: conditions.join(' AND '), whereArgs: args);
  }

  Map<String, Object?> _movieToDbMap(Movie movie) {
    return {
      'id': movie.id,
      'title': movie.title,
      'year': movie.year,
      'subject_type': movie.subjectType.value,
      'director': movie.director,
      'author': movie.author,
      'cast_text': movie.cast,
      'rating': movie.rating,
      'genre_json': jsonEncode(movie.genre),
      'region': movie.region,
      'summary': movie.summary,
      'published_at': movie.publishedAt,
      'duration_text': movie.durationText,
      'episodes_json': jsonEncode(
        movie.episodes.map((episode) => episode.toJson()).toList(),
      ),
      'poster': movie.poster,
      'douban_url': movie.doubanUrl,
      'watched': movie.watched ? 1 : 0,
      'watched_at': movie.watchedAt?.toIso8601String(),
      'user_rating': movie.userRating,
      'user_review': movie.userReview,
      'created_at': movie.createdAt.toIso8601String(),
    };
  }

  Movie _movieFromDbMap(Map<String, Object?> row) {
    return Movie(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      year: row['year']?.toString() ?? '',
      subjectType: MovieSubjectType.fromValue(row['subject_type']?.toString()),
      director: row['director']?.toString() ?? '',
      author: row['author']?.toString() ?? '',
      cast: row['cast_text']?.toString() ?? '',
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      genre: _decodeStringList(row['genre_json']?.toString()),
      region: row['region']?.toString() ?? '',
      summary: row['summary']?.toString() ?? '',
      publishedAt: row['published_at']?.toString() ?? '',
      durationText: row['duration_text']?.toString() ?? '',
      episodes: _decodeEpisodes(row['episodes_json']?.toString()),
      poster: row['poster']?.toString() ?? '',
      doubanUrl: row['douban_url']?.toString() ?? '',
      watched: (row['watched'] as int? ?? 0) == 1,
      watchedAt: row['watched_at'] != null
          ? DateTime.tryParse(row['watched_at']!.toString())
          : null,
      userRating: (row['user_rating'] as num?)?.toDouble(),
      userReview: row['user_review']?.toString(),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> _drawRecordToDbMap(DrawRecord record) {
    return {
      'id': record.id,
      'mode': record.mode,
      'room_code': record.roomCode,
      'movie_id': record.movieId,
      'movie_title': record.movieTitle,
      'movie_poster': record.moviePoster,
      'seed': record.seed,
      'participants_json': jsonEncode(
        record.participants.map((participant) => participant.toJson()).toList(),
      ),
      'candidate_count': record.candidateCount,
      'drawn_at': record.drawnAt.toIso8601String(),
    };
  }

  DrawRecord _drawRecordFromDbMap(Map<String, Object?> row) {
    final participantsJson = row['participants_json']?.toString() ?? '[]';
    final decodedParticipants = jsonDecode(participantsJson) as List<dynamic>;
    return DrawRecord(
      id: row['id']?.toString() ?? '',
      mode: row['mode']?.toString() ?? 'solo',
      roomCode: row['room_code']?.toString(),
      movieId: row['movie_id']?.toString() ?? '',
      movieTitle: row['movie_title']?.toString() ?? '',
      moviePoster: row['movie_poster']?.toString() ?? '',
      seed: row['seed'] as int? ?? 0,
      participants: decodedParticipants
          .whereType<Map>()
          .map(
            (participant) => DrawParticipant.fromJson(
              Map<String, dynamic>.from(participant),
            ),
          )
          .toList(),
      candidateCount: row['candidate_count'] as int? ?? 0,
      drawnAt:
          DateTime.tryParse(row['drawn_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => item.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  List<MovieEpisode> _decodeEpisodes(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((json) => MovieEpisode.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<List<T>> _chunkList<T>(List<T> values, int chunkSize) {
    final chunks = <List<T>>[];
    for (int start = 0; start < values.length; start += chunkSize) {
      final end = min(start + chunkSize, values.length);
      chunks.add(values.sublist(start, end));
    }
    return chunks;
  }

  // ========== 工具方法 ==========

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    final random = Random();
    for (int index = 0; index < length; index++) {
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
  String toString() => '电影《${existingMovie.title}》已在片库中';
}

class _SqlClause {
  final String? where;
  final List<Object?>? whereArgs;

  const _SqlClause({this.where, this.whereArgs});
}
