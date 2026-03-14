import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

class MovieProvider extends ChangeNotifier {
  static const int initialLibraryPageSize = 12;
  static const int warmedLibraryTargetSize = 24;
  static const int libraryPageSize = 48;
  static const int historyPageSize = 20;

  final StorageService _storageService = StorageService();
  final MovieScraperService _scraperService = MovieScraperService();

  final Map<String, Movie> _movieCache = {};
  List<Movie> _libraryMovies = [];
  List<Movie> _historyMovies = [];
  bool _isBusy = false;
  bool _isLibraryLoading = false;
  bool _isLibraryLoadingMore = false;
  bool _isLibraryWarming = false;
  bool _hasMoreLibrary = true;
  int _libraryRefreshRevision = 0;
  bool _isHistoryLoading = false;
  bool _isHistoryLoadingMore = false;
  bool _hasMoreHistory = true;
  int _historyPage = 0;
  bool _hasLoadedLibrary = false;
  bool _hasLoadedHistory = false;
  String? _error;
  String _searchQuery = '';
  Timer? _searchDebounce;

  List<Movie> get movies => _libraryMovies;
  List<Movie> get allMovies => _libraryMovies;
  List<Movie> get watchedMovies => _historyMovies;
  bool get isLoading => _isBusy;
  bool get isLibraryLoading => _isLibraryLoading;
  bool get isLibraryLoadingMore => _isLibraryLoadingMore;
  bool get hasMoreLibrary => _hasMoreLibrary;
  bool get isHistoryLoading => _isHistoryLoading;
  bool get isHistoryLoadingMore => _isHistoryLoadingMore;
  bool get hasMoreHistory => _hasMoreHistory;
  bool get hasLoadedLibrary => _hasLoadedLibrary;
  bool get hasLoadedHistory => _hasLoadedHistory;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  MovieProvider();

  void _cacheMovies(Iterable<Movie> movies) {
    for (final movie in movies) {
      _movieCache[movie.id] = movie;
    }
  }

  Movie? peekMovieById(String id) => _movieCache[id];

  Future<Movie?> getMovieById(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _movieCache[id];
      if (cached != null) return cached;
    }

    final movie = await _storageService.getMovieById(id);
    if (movie != null) {
      _cacheMovies([movie]);
    }
    return movie;
  }

  Future<List<Movie>> getMoviesByIds(Iterable<String> ids) async {
    final movies = await _storageService.getMoviesByIds(ids);
    _cacheMovies(movies);
    return movies;
  }

  Future<List<String>> getAllMovieIds({bool unwatchedOnly = false}) {
    return _storageService.queryMovieIds(unwatchedOnly: unwatchedOnly);
  }

  Future<int> getMovieCount({bool unwatchedOnly = false}) {
    return _storageService.countMovies(unwatchedOnly: unwatchedOnly);
  }

  Future<void> loadMovies() => refreshLibrary();

  Future<void> ensureLibraryLoaded() async {
    if (_hasLoadedLibrary || _isLibraryLoading) return;
    await refreshLibrary();
  }

  Future<void> ensureHistoryLoaded() async {
    if (_hasLoadedHistory || _isHistoryLoading) return;
    await refreshWatchedHistory();
  }

  Future<void> refreshLibrary() async {
    final shouldNotifyLoading =
        _hasLoadedLibrary || _libraryMovies.isNotEmpty || _error != null;
    final refreshRevision = ++_libraryRefreshRevision;
    final useReducedInitialBatch =
        !_hasLoadedLibrary && _searchQuery.trim().isEmpty;
    final limit = useReducedInitialBatch
        ? initialLibraryPageSize
        : libraryPageSize;
    _searchDebounce?.cancel();
    _isLibraryLoading = true;
    _isLibraryWarming = false;
    _error = null;
    if (shouldNotifyLoading) {
      notifyListeners();
    }

    try {
      final movies = await _storageService.queryMovies(
        limit: limit,
        offset: 0,
        searchQuery: _searchQuery,
      );
      _libraryMovies = movies;
      _hasMoreLibrary = movies.length == limit;
      _cacheMovies(movies);
      if (useReducedInitialBatch && movies.isNotEmpty && _hasMoreLibrary) {
        _scheduleLibraryWarmUp(refreshRevision);
      }
    } catch (error) {
      _error = '加载片库失败: $error';
    } finally {
      _hasLoadedLibrary = true;
      _isLibraryLoading = false;
      notifyListeners();
    }
  }

  void _scheduleLibraryWarmUp(int refreshRevision) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (refreshRevision != _libraryRefreshRevision) return;
      unawaited(warmUpLibraryAfterFirstFrame(refreshRevision: refreshRevision));
    });
  }

  Future<void> warmUpLibraryAfterFirstFrame({int? refreshRevision}) async {
    final activeRevision = refreshRevision ?? _libraryRefreshRevision;
    if (activeRevision != _libraryRefreshRevision) {
      return;
    }
    if (_searchQuery.trim().isNotEmpty ||
        _isLibraryLoading ||
        _isLibraryLoadingMore ||
        _isLibraryWarming ||
        !_hasMoreLibrary) {
      return;
    }

    final currentCount = _libraryMovies.length;
    final extraLimit = warmedLibraryTargetSize - currentCount;
    if (extraLimit <= 0) return;

    _isLibraryWarming = true;
    try {
      final movies = await _storageService.queryMovies(
        limit: extraLimit,
        offset: currentCount,
        searchQuery: _searchQuery,
      );
      if (activeRevision != _libraryRefreshRevision) {
        return;
      }
      if (movies.isEmpty) {
        _hasMoreLibrary = false;
        notifyListeners();
      } else {
        _libraryMovies = [..._libraryMovies, ...movies];
        _hasMoreLibrary = movies.length == extraLimit;
        _cacheMovies(movies);
        notifyListeners();
      }
    } catch (_) {
    } finally {
      if (activeRevision == _libraryRefreshRevision) {
        _isLibraryWarming = false;
      }
    }
  }

  Future<void> loadMoreLibrary() async {
    if (_isLibraryLoading ||
        _isLibraryLoadingMore ||
        _isLibraryWarming ||
        !_hasMoreLibrary) {
      return;
    }

    _isLibraryLoadingMore = true;
    notifyListeners();

    try {
      final movies = await _storageService.queryMovies(
        limit: libraryPageSize,
        offset: _libraryMovies.length,
        searchQuery: _searchQuery,
      );
      if (movies.isEmpty) {
        _hasMoreLibrary = false;
      } else {
        _libraryMovies = [..._libraryMovies, ...movies];
        _hasMoreLibrary = movies.length == libraryPageSize;
        _cacheMovies(movies);
      }
    } catch (error) {
      _error = '加载更多电影失败: $error';
    } finally {
      _isLibraryLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshWatchedHistory() async {
    final shouldNotifyLoading =
        _hasLoadedHistory || _historyMovies.isNotEmpty || _error != null;
    _isHistoryLoading = true;
    _error = null;
    if (shouldNotifyLoading) {
      notifyListeners();
    }

    try {
      final movies = await _storageService.queryMovies(
        limit: historyPageSize,
        offset: 0,
        watchedOnly: true,
      );
      _historyMovies = movies;
      _historyPage = 0;
      _hasMoreHistory = movies.length == historyPageSize;
      _cacheMovies(movies);
    } catch (error) {
      _error = '加载观影记录失败: $error';
    } finally {
      _hasLoadedHistory = true;
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreWatchedHistory() async {
    if (_isHistoryLoading || _isHistoryLoadingMore || !_hasMoreHistory) return;

    _isHistoryLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _historyPage + 1;
      final movies = await _storageService.queryMovies(
        limit: historyPageSize,
        offset: nextPage * historyPageSize,
        watchedOnly: true,
      );
      if (movies.isEmpty) {
        _hasMoreHistory = false;
      } else {
        _historyMovies = [..._historyMovies, ...movies];
        _historyPage = nextPage;
        _hasMoreHistory = movies.length == historyPageSize;
        _cacheMovies(movies);
      }
    } catch (error) {
      _error = '加载更多观影记录失败: $error';
    } finally {
      _isHistoryLoadingMore = false;
      notifyListeners();
    }
  }

  void setSearchQueryDebounced(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), refreshLibrary);
    notifyListeners();
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    _searchDebounce?.cancel();
    await refreshLibrary();
  }

  Future<void> _reloadVisibleCollections() async {
    final libraryLimit = math.max(
      _libraryMovies.length,
      initialLibraryPageSize,
    );
    final historyLimit = math.max(
      (_historyPage + 1) * historyPageSize,
      historyPageSize,
    );

    final results = await Future.wait<Object>([
      _storageService.queryMovies(
        limit: libraryLimit,
        offset: 0,
        searchQuery: _searchQuery,
      ),
      _storageService.countMovies(searchQuery: _searchQuery),
      _storageService.queryMovies(
        limit: historyLimit,
        offset: 0,
        watchedOnly: true,
      ),
      _storageService.countMovies(watchedOnly: true),
    ]);

    final libraryMovies = results[0] as List<Movie>;
    final libraryCount = results[1] as int;
    final historyMovies = results[2] as List<Movie>;
    final historyCount = results[3] as int;

    _libraryMovies = libraryMovies;
    _historyMovies = historyMovies;
    _historyPage = historyMovies.isEmpty
        ? 0
        : ((historyMovies.length - 1) / historyPageSize).floor();
    _hasMoreLibrary = libraryMovies.length < libraryCount;
    _hasMoreHistory = historyMovies.length < historyCount;
    _hasLoadedLibrary = true;
    _hasLoadedHistory = true;
    _cacheMovies([...libraryMovies, ...historyMovies]);
    notifyListeners();
  }

  Future<void> addManualMovie({
    required String title,
    String? year,
    String? director,
    String? cast,
  }) async {
    if (title.trim().isEmpty) {
      _error = '电影名称不能为空';
      notifyListeners();
      return;
    }

    _isBusy = true;
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
      final savedMovie = await _storageService.addMovie(movie);
      _cacheMovies([savedMovie]);
      await _reloadVisibleCollections();
    } catch (error) {
      _error = '添加失败: $error';
      notifyListeners();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<Movie?> fetchMoviePreview(String doubanUrl) async {
    if (doubanUrl.trim().isEmpty) {
      _error = '请输入豆瓣链接';
      notifyListeners();
      return null;
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      return await _scraperService.scrapeMovie(doubanUrl.trim());
    } on ScraperException catch (error) {
      _error = error.message;
      return null;
    } catch (error) {
      _error = '爬取失败: $error';
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<List<Movie>> fetchDoulistPreview(
    String doulistUrl, {
    void Function(DoulistScrapeProgress progress)? onProgress,
  }) async {
    if (doulistUrl.trim().isEmpty) {
      _error = '请输入片单链接';
      notifyListeners();
      return [];
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      return await _scraperService.scrapeDoulist(
        doulistUrl.trim(),
        onProgress: onProgress,
      );
    } on ScraperException catch (error) {
      _error = error.message;
      return [];
    } catch (error) {
      _error = '爬取失败: $error';
      return [];
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<Movie?> addScrapedMovie(Movie movie) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final savedMovie = await _storageService.addMovie(movie);
      _cacheMovies([savedMovie]);
      await _reloadVisibleCollections();
      return savedMovie;
    } on DuplicateMovieException {
      _error = '《${movie.title}》已在片库中';
      return null;
    } catch (error) {
      _error = '保存失败: $error';
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<({int added, int skipped})> addScrapedMovies(
    List<Movie> movies,
  ) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    var added = 0;
    var skipped = 0;

    try {
      for (final movie in movies) {
        try {
          final savedMovie = await _storageService.addMovie(movie);
          _cacheMovies([savedMovie]);
          added++;
        } on DuplicateMovieException {
          skipped++;
        } catch (_) {}
      }

      await _reloadVisibleCollections();
      return (added: added, skipped: skipped);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateMovie(Movie movie) async {
    _error = null;

    try {
      await _storageService.updateMovie(movie);
      _cacheMovies([movie]);
      await _reloadVisibleCollections();
    } catch (error) {
      _error = '更新失败: $error';
      notifyListeners();
    }
  }

  Future<void> deleteMovie(String movieId) async {
    _error = null;
    try {
      await _storageService.deleteMovie(movieId);
      _movieCache.remove(movieId);
      await _reloadVisibleCollections();
    } catch (error) {
      _error = '删除失败: $error';
      notifyListeners();
    }
  }

  Future<void> toggleWatched(String movieId) async {
    final movie = await getMovieById(movieId);
    if (movie == null) return;

    await updateMovie(
      movie.copyWith(
        watched: !movie.watched,
        watchedAt: movie.watched ? null : DateTime.now(),
        clearWatchedAt: movie.watched,
      ),
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
