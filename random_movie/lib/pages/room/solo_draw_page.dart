import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/providers/providers.dart';
import 'package:random_movie/services/services.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:random_movie/widgets/movie/draw_shuffle_card.dart';
import 'package:random_movie/widgets/movie/movie_card.dart';

enum SoloDrawPhase { selecting, animating, result }

/// 单人抽片页面：选片 → 动画 → 结果
class SoloDrawPage extends StatefulWidget {
  const SoloDrawPage({super.key});

  @override
  State<SoloDrawPage> createState() => _SoloDrawPageState();
}

class _SoloDrawPageState extends State<SoloDrawPage> {
  SoloDrawPhase _phase = SoloDrawPhase.selecting;

  // Selecting
  late List<Movie> _allMovies;
  final Set<String> _selectedIds = {};
  bool _initialized = false;

  // Animating
  Timer? _shuffleTimer;
  int _displayIndex = 0;
  int _shuffleCount = 0;
  List<Movie> _candidates = [];

  // Result
  DrawResultData? _result;

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    super.dispose();
  }

  // ==================== Build ====================

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
      body: _buildBody(context),
    );
  }

  String get _appBarTitle {
    switch (_phase) {
      case SoloDrawPhase.selecting:
        return '选择候选影片';
      case SoloDrawPhase.animating:
        return '抽奖中...';
      case SoloDrawPhase.result:
        return '抽奖结果';
    }
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case SoloDrawPhase.selecting:
        return _buildSelectingPhase(context);
      case SoloDrawPhase.animating:
        return _buildAnimatingPhase(context);
      case SoloDrawPhase.result:
        return _buildResultPhase(context);
    }
  }

  // ==================== Selecting Phase ====================

  Widget _buildSelectingPhase(BuildContext context) {
    return Consumer<MovieProvider>(
      builder: (context, provider, _) {
        if (!_initialized) {
          _allMovies = List.of(provider.allMovies);
          final unwatched = _allMovies.where((m) => !m.watched).toList();
          _selectedIds.addAll(
            (unwatched.isEmpty ? _allMovies : unwatched).map((m) => m.id),
          );
          _initialized = true;
        }

        if (_allMovies.isEmpty) {
          return EmptyState(
            title: '片库是空的',
            subtitle: '先去添加几部影片吧',
            icon: Icons.movie_outlined,
            onAction: () => context.go('/movies/add'),
            actionLabel: '去添加',
          );
        }

        return Column(
          children: [
            _buildSelectionHeader(context),
            Expanded(child: _buildMovieGrid(context)),
            _buildStartButton(context),
          ],
        );
      },
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
      ),
      child: Row(
        children: [
          Text(
            '已选 ${_selectedIds.length} / 共 ${_allMovies.length} 部',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedIds.clear();
                _selectedIds.addAll(_allMovies.map((m) => m.id));
              });
            },
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedIds.clear();
                final unwatched = _allMovies.where((m) => !m.watched);
                _selectedIds.addAll(unwatched.map((m) => m.id));
              });
            },
            child: const Text('仅未看'),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.60,
        crossAxisSpacing: AppTheme.spacingSmall,
        mainAxisSpacing: AppTheme.spacingSmall,
      ),
      itemCount: _allMovies.length,
      itemBuilder: (context, index) {
        final movie = _allMovies[index];
        final selected = _selectedIds.contains(movie.id);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedIds.remove(movie.id);
              } else {
                _selectedIds.add(movie.id);
              }
            });
          },
          child: AnimatedOpacity(
            opacity: selected ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                Container(
                  decoration: selected
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(color: AppTheme.accent, width: 2),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 1),
                    child: AspectRatio(
                      aspectRatio: 0.65,
                      child: movie.poster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.poster,
                              httpHeaders: ApiConfig.imageHeaders,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.movie, size: 28),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      movie.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                // Checkbox
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppTheme.accent
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                // Title at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(AppTheme.radiusLarge - 1),
                      ),
                    ),
                    child: Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartButton(BuildContext context) {
    final count = _selectedIds.length;
    return SafeArea(
      minimum: const EdgeInsets.all(AppTheme.spacingMedium),
      child: PrimaryButton(
        label: count > 0 ? '开始抽奖（$count 部）' : '请先选择影片',
        icon: Icons.casino,
        onPressed: count > 0 ? _startDraw : null,
      ),
    );
  }

  // ==================== Animating Phase ====================

  void _startDraw() {
    _candidates = _allMovies
        .where((m) => _selectedIds.contains(m.id))
        .toList();

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

    _shuffleTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        _shuffleCount++;
        if (_shuffleCount <= fastCount) {
          setState(() {
            _displayIndex = (_displayIndex + 1) % _candidates.length;
          });
        } else {
          timer.cancel();
          _startSlowPhase(0);
        }
      },
    );
  }

  void _startSlowPhase(int step) {
    const int slowSteps = 4;
    if (step >= slowSteps) {
      // Final: land on result
      setState(() {
        _displayIndex = _candidates.indexOf(_result!.selectedMovie);
        if (_displayIndex == -1) _displayIndex = 0;
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
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user != null && _result != null) {
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

  // ==================== Result Phase ====================

  Widget _buildResultPhase(BuildContext context) {
    final movie = _result!.selectedMovie;
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
          PrimaryButton(
            label: '再来一次',
            icon: Icons.casino,
            onPressed: _retry,
          ),
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
                  onPressed: () =>
                      context.push('/movies/detail/${movie.id}'),
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

  void _markWatched(BuildContext context, Movie movie) {
    final provider = context.read<MovieProvider>();
    provider.updateMovie(movie.copyWith(
      watched: true,
      watchedAt: DateTime.now(),
    ));
    AppToast.success(context, '已将「${movie.title}」标记为已看');
    setState(() {});
  }
}
