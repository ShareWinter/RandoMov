import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/providers/providers.dart';
import 'package:random_movie/services/services.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:random_movie/widgets/movie/draw_shuffle_card.dart';
import 'package:random_movie/widgets/movie/movie_card.dart';
import 'package:random_movie/widgets/movie/selectable_movie_grid.dart';

enum SoloDrawPhase { selecting, animating, result }

/// 单人抽片页面：选片 -> 动画 -> 结果
class SoloDrawPage extends StatefulWidget {
  const SoloDrawPage({super.key});

  @override
  State<SoloDrawPage> createState() => _SoloDrawPageState();
}

class _SoloDrawPageState extends State<SoloDrawPage> {
  static const int _pageSize = 48;

  final StorageService _storageService = StorageService();
  final ScrollController _scrollController = ScrollController();

  SoloDrawPhase _phase = SoloDrawPhase.selecting;
  final Set<String> _selectedIds = {};
  final Map<String, Movie> _movieCache = {};
  List<Movie> _loadedMovies = [];
  List<Movie> _candidates = [];
  DrawResultData? _result;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _totalCount = 0;

  Timer? _shuffleTimer;
  int _displayIndex = 0;
  int _shuffleCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_phase != SoloDrawPhase.selecting || !_scrollController.hasClients)
      return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMoreMovies();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);

    try {
      final results = await Future.wait<Object>([
        _storageService.countMovies(),
        _storageService.queryMovies(limit: _pageSize, offset: 0),
        _storageService.queryMovieIds(unwatchedOnly: true),
      ]);

      final totalCount = results[0] as int;
      final firstPage = results[1] as List<Movie>;
      final unwatchedIds = results[2] as List<String>;
      final fallbackIds = unwatchedIds.isEmpty && totalCount > 0
          ? await _storageService.queryMovieIds()
          : const <String>[];

      _loadedMovies = firstPage;
      _totalCount = totalCount;
      _page = 0;
      _hasMore = firstPage.length < totalCount;
      _selectedIds
        ..clear()
        ..addAll(unwatchedIds.isNotEmpty ? unwatchedIds : fallbackIds);
      _cacheMovies(firstPage);
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _loadMoreMovies() async {
    if (_isInitialLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final movies = await _storageService.queryMovies(
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );
      if (movies.isNotEmpty) {
        _loadedMovies = [..._loadedMovies, ...movies];
        _page = nextPage;
        _hasMore = _loadedMovies.length < _totalCount;
        _cacheMovies(movies);
      } else {
        _hasMore = false;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _cacheMovies(Iterable<Movie> movies) {
    for (final movie in movies) {
      _movieCache[movie.id] = movie;
    }
  }

  Future<void> _selectAllMovies() async {
    final ids = await _storageService.queryMovieIds();
    if (!mounted) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  Future<void> _selectUnwatchedMovies() async {
    final ids = await _storageService.queryMovieIds(unwatchedOnly: true);
    if (!mounted) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        leading: _phase == SoloDrawPhase.animating
            ? const SizedBox.shrink()
            : null,
        automaticallyImplyLeading: _phase != SoloDrawPhase.animating,
      ),
      body: switch (_phase) {
        SoloDrawPhase.selecting => _buildSelectingPhase(context),
        SoloDrawPhase.animating => _buildAnimatingPhase(context),
        SoloDrawPhase.result => _buildResultPhase(context),
      },
    );
  }

  String get _appBarTitle {
    switch (_phase) {
      case SoloDrawPhase.selecting:
        return '选择候选电影';
      case SoloDrawPhase.animating:
        return '抽奖中...';
      case SoloDrawPhase.result:
        return '抽奖结果';
    }
  }

  Widget _buildSelectingPhase(BuildContext context) {
    if (_isInitialLoading) {
      return const LoadingState(message: '加载片库中...');
    }

    if (_totalCount == 0) {
      return EmptyState(
        title: '片库是空的',
        subtitle: '先去添加几部电影吧',
        icon: Icons.movie_outlined,
        onAction: () => context.go('/movies/add'),
        actionLabel: '去添加',
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMedium,
            AppTheme.spacingSmall,
            AppTheme.spacingMedium,
            AppTheme.spacingSmall,
          ),
          child: Row(
            children: [
              Text(
                '已选 ${_selectedIds.length} / 共 $_totalCount 部',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _selectAllMovies(),
                child: const Text('全选'),
              ),
              TextButton(
                onPressed: () => _selectUnwatchedMovies(),
                child: const Text('仅未看'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SelectableMovieGrid(
            storageKey: const PageStorageKey('solo-draw-selection-grid'),
            controller: _scrollController,
            movies: _loadedMovies,
            selectedIds: _selectedIds,
            hasMore: _hasMore,
            isLoadingMore: _isLoadingMore,
            onToggle: (movie) {
              setState(() {
                if (_selectedIds.contains(movie.id)) {
                  _selectedIds.remove(movie.id);
                } else {
                  _selectedIds.add(movie.id);
                }
              });
            },
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(AppTheme.spacingMedium),
          child: PrimaryButton(
            label: _selectedIds.isNotEmpty
                ? '开始抽奖（${_selectedIds.length} 部）'
                : '请先选择电影',
            icon: Icons.casino,
            onPressed: _selectedIds.isNotEmpty ? () => _startDraw() : null,
          ),
        ),
      ],
    );
  }

  Future<void> _startDraw() async {
    _candidates = await _storageService.getMoviesByIds(_selectedIds);
    if (_candidates.isEmpty) {
      if (!mounted) return;
      AppToast.error(context, '没有可用的候选电影');
      return;
    }

    _cacheMovies(_candidates);
    _result = DrawService.soloRandom(_candidates);

    setState(() {
      _phase = SoloDrawPhase.animating;
      _shuffleCount = 0;
      _displayIndex = 0;
    });

    _startShuffleAnimation();
  }

  void _startShuffleAnimation() {
    const int fastCount = 20;

    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _shuffleCount++;
      if (_shuffleCount <= fastCount) {
        if (!mounted) return;
        setState(() {
          _displayIndex = (_displayIndex + 1) % _candidates.length;
        });
      } else {
        timer.cancel();
        _startSlowPhase(0);
      }
    });
  }

  void _startSlowPhase(int step) {
    const int slowSteps = 4;
    if (step >= slowSteps) {
      setState(() {
        _displayIndex = _candidates.indexOf(_result!.selectedMovie);
        if (_displayIndex == -1) {
          _displayIndex = 0;
        }
      });
      Future.delayed(const Duration(milliseconds: 500), _onAnimationComplete);
      return;
    }

    final delay = Duration(milliseconds: 200 + step * 100);
    Future.delayed(delay, () {
      if (!mounted) return;
      setState(() {
        _displayIndex = (_displayIndex + 1) % _candidates.length;
      });
      _startSlowPhase(step + 1);
    });
  }

  void _onAnimationComplete() {
    if (!mounted || _result == null) return;

    final user = context.read<UserProvider>().user;
    if (user != null) {
      final record = DrawService.buildSoloRecord(
        result: _result!,
        candidateCount: _selectedIds.length,
        userId: user.id,
        userName: user.name,
      );
      context.read<DrawHistoryProvider>().addRecord(record);
    }

    setState(() {
      _phase = SoloDrawPhase.result;
    });
  }

  Widget _buildAnimatingPhase(BuildContext context) {
    final currentMovie = _candidates[_displayIndex % _candidates.length];
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: DrawShuffleCard(
              movie: currentMovie,
              shuffleCount: _shuffleCount,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          Text(
            '抽取中...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPhase(BuildContext context) {
    final result = _result!;
    final movie = result.selectedMovie;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.spacingLarge,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingLarge),
          Icon(Icons.celebration, size: 48, color: AppTheme.accent),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            '恭喜抽中！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          SizedBox(
            width: 200,
            height: 330,
            child: MovieCard(
              movie: movie,
              showWatchedBadge: false,
              onTap: () => context.push('/movies/detail/${movie.id}'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXLarge),
          PrimaryButton(label: '再来一次', icon: Icons.casino, onPressed: _retry),
          const SizedBox(height: AppTheme.spacingMedium),
          PrimaryButton(
            label: '就看这个',
            icon: Icons.check_circle_outline,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: movie.watched ? '已看过' : '标记已看',
                  icon: movie.watched
                      ? Icons.visibility
                      : Icons.visibility_outlined,
                  onPressed: movie.watched
                      ? null
                      : () => _markWatched(context, movie),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: SecondaryButton(
                  label: '查看详情',
                  icon: Icons.info_outline,
                  onPressed: () => context.push('/movies/detail/${movie.id}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXLarge),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _phase = SoloDrawPhase.selecting;
      _result = null;
      _shuffleCount = 0;
      _displayIndex = 0;
    });
  }

  Future<void> _markWatched(BuildContext context, Movie movie) async {
    final updatedMovie = movie.copyWith(
      watched: true,
      watchedAt: DateTime.now(),
    );
    await context.read<MovieProvider>().updateMovie(updatedMovie);
    if (!mounted || _result == null) return;

    setState(() {
      _movieCache[updatedMovie.id] = updatedMovie;
      _result = DrawResultData(
        selectedMovie: updatedMovie,
        seed: _result!.seed,
        index: _result!.index,
      );
    });
    AppToast.success(context, '已将《${movie.title}》标记为已看');
  }
}
