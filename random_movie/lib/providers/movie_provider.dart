import 'package:flutter/foundation.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

/// 影片状态管理
class MovieProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final MovieScraperService _scraperService = MovieScraperService();

  List<Movie> _movies = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Movie> get movies => _filterMovies();
  List<Movie> get allMovies => _movies;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  /// 已观看影片列表，按观看时间倒序
  List<Movie> get watchedMovies {
    return _movies
        .where((m) => m.watched)
        .toList()
      ..sort((a, b) {
        final dateA = a.watchedAt ?? a.createdAt;
        final dateB = b.watchedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
  }

  /// 按 ID 查找影片
  Movie? getMovieById(String id) {
    for (final m in _movies) {
      if (m.id == id) return m;
    }
    return null;
  }

  MovieProvider() {
    loadMovies();
  }

  /// 加载本地影片
  void loadMovies() {
    _movies = _storageService.getMovies();
    notifyListeners();
  }

  /// 搜索过滤
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Movie> _filterMovies() {
    if (_searchQuery.isEmpty) return _movies;
    final lowerQuery = _searchQuery.toLowerCase();
    return _movies.where((m) {
      return m.title.toLowerCase().contains(lowerQuery) ||
          m.director.toLowerCase().contains(lowerQuery) ||
          m.cast.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 手动添加影片
  Future<void> addManualMovie({
    required String title,
    String? year,
    String? director,
    String? cast,
  }) async {
    if (title.trim().isEmpty) {
      _error = '影片名称不能为空';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final movie = Movie(
        id: '',
        title: title.trim(),
        year: year ?? '',
        director: director ?? '',
        cast: cast ?? '',
      );
      await _storageService.addMovie(movie);
      loadMovies();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = '添加失败: $e';
      notifyListeners();
    }
  }

  /// 仅爬取单个影片预览，不保存到本地
  ///
  /// [useProxy] 为 true 时走服务端代理（绕墙），false 时直连 WMDB API。
  Future<Movie?> fetchMoviePreview(String doubanUrl, {bool useProxy = true}) async {
    if (doubanUrl.trim().isEmpty) {
      _error = '请输入豆瓣链接';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final movie = await _scraperService.scrapeMovie(doubanUrl.trim(), useProxy: useProxy);
      _isLoading = false;
      notifyListeners();
      return movie;
    } on ScraperException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _error = '爬取失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 仅爬取片单预览，不保存到本地
  Future<List<Movie>> fetchDoulistPreview(String doulistUrl) async {
    if (doulistUrl.trim().isEmpty) {
      _error = '请输入片单链接';
      notifyListeners();
      return [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final movies = await _scraperService.scrapeDoulist(doulistUrl.trim());
      _isLoading = false;
      notifyListeners();
      return movies;
    } on ScraperException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      return [];
    } catch (e) {
      _isLoading = false;
      _error = '爬取失败: $e';
      notifyListeners();
      return [];
    }
  }

  /// 保存完整影片对象（含海报、评分等所有字段）
  Future<Movie?> addScrapedMovie(Movie movie) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedMovie = await _storageService.addMovie(movie);
      loadMovies();
      _isLoading = false;
      notifyListeners();
      return savedMovie;
    } on DuplicateMovieException {
      _isLoading = false;
      _error = '「${movie.title}」已在片库中';
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _error = '保存失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 批量保存影片，自动跳过重复项，返回统计结果
  Future<({int added, int skipped})> addScrapedMovies(List<Movie> movies) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    int added = 0;
    int skipped = 0;

    for (final movie in movies) {
      try {
        await _storageService.addMovie(movie);
        added++;
      } on DuplicateMovieException {
        skipped++;
      } catch (_) {
        // 单条失败不影响整体批量流程
      }
    }

    loadMovies();
    _isLoading = false;
    notifyListeners();
    return (added: added, skipped: skipped);
  }

  /// 更新影片
  Future<void> updateMovie(Movie movie) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.updateMovie(movie);
      loadMovies();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = '更新失败: $e';
      notifyListeners();
    }
  }

  /// 删除影片
  Future<void> deleteMovie(String movieId) async {
    try {
      await _storageService.deleteMovie(movieId);
      loadMovies();
    } catch (e) {
      _error = '删除失败: $e';
      notifyListeners();
    }
  }

  /// 标记已看/未看
  Future<void> toggleWatched(String movieId) async {
    final movie = _movies.firstWhere((m) => m.id == movieId);
    await updateMovie(movie.copyWith(watched: !movie.watched));
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
