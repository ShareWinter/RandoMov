import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// 电影详情页
class MovieDetailPage extends StatefulWidget {
  final String movieId;

  const MovieDetailPage({super.key, required this.movieId});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  static const double _detailCacheExtent = 160;
  static const double _expandedPosterHeight = 320;

  Future<Movie?>? _movieFuture;
  Movie? _seedMovie;
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeAnimationStatusListener;
  late double? _userRating;
  late bool _watched;
  late DateTime? _watchedAt;
  late TextEditingController _reviewController;
  late List<MovieEpisode> _episodes;
  bool _summaryExpanded = false;
  bool _initialized = false;
  bool _hasChanges = false;
  bool _isSyncingWatchState = false;
  bool _posterReady = false;
  bool _secondarySectionsReady = false;
  bool _episodeControlsReady = false;
  bool _deferredSectionsScheduled = false;

  @override
  void initState() {
    super.initState();
    _seedMovie = context.read<MovieProvider>().peekMovieById(widget.movieId);
    _movieFuture = _loadMovie();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindRouteTransition();
  }

  void _bindRouteTransition() {
    final nextAnimation = ModalRoute.of(context)?.animation;
    if (identical(nextAnimation, _routeAnimation)) return;

    _removeRouteTransitionListener();
    _routeAnimation = nextAnimation;

    if (_deferredSectionsScheduled) return;
    if (nextAnimation == null ||
        nextAnimation.status == AnimationStatus.completed) {
      _beginDeferredReveal();
      return;
    }

    _routeAnimationStatusListener = (status) {
      if (status != AnimationStatus.completed) return;
      _removeRouteTransitionListener();
      _beginDeferredReveal();
    };
    nextAnimation.addStatusListener(_routeAnimationStatusListener!);
  }

  void _beginDeferredReveal() {
    if (_deferredSectionsScheduled) return;
    _deferredSectionsScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _secondarySectionsReady = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _posterReady) return;
        setState(() {
          _posterReady = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _episodeControlsReady) return;
          setState(() {
            _episodeControlsReady = true;
          });
        });
      });
    });
  }

  void _removeRouteTransitionListener() {
    final animation = _routeAnimation;
    final listener = _routeAnimationStatusListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _routeAnimationStatusListener = null;
  }

  void _initFromMovie(Movie movie) {
    if (_initialized) return;
    _episodes = List<MovieEpisode>.from(movie.episodes);
    _userRating = movie.userRating;

    final isSeries = movie.subjectType == MovieSubjectType.tvSeries;
    final hasEpisodes = isSeries && _episodes.isNotEmpty;
    _watched = hasEpisodes
        ? _episodes.every((episode) => episode.watched)
        : movie.watched;
    _watchedAt = _watched ? movie.watchedAt : null;
    _reviewController = TextEditingController(text: movie.userReview ?? '');
    _initialized = true;
  }

  Future<Movie?> _loadMovie({bool forceRefresh = false}) {
    return context.read<MovieProvider>().getMovieById(
      widget.movieId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  void dispose() {
    _removeRouteTransitionListener();
    if (_initialized) {
      _reviewController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Movie?>(
      initialData: _seedMovie,
      future: _movieFuture,
      builder: (context, snapshot) {
        final movie = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting &&
            movie == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (movie == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('电影不存在')),
          );
        }

        _initFromMovie(movie);
        final provider = context.read<MovieProvider>();

        return Scaffold(
          body: CustomScrollView(
            cacheExtent: _detailCacheExtent,
            slivers: [
              _buildSliverAppBar(context, movie),
              ..._buildBodySlivers(context, movie, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Movie movie) {
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SliverAppBar(
      expandedHeight: _expandedPosterHeight,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (movie.poster.isNotEmpty && _posterReady)
                CachedNetworkImage(
                  imageUrl: movie.poster,
                  httpHeaders: ApiConfig.imageHeaders,
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  maxWidthDiskCache: 480,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, __) => ColoredBox(
                    color: surfaceColor,
                    child: const Center(
                      child: Icon(Icons.movie, size: 64, color: Colors.white24),
                    ),
                  ),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: surfaceColor,
                    child: const Center(
                      child: Icon(Icons.movie, size: 64, color: Colors.white24),
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: surfaceColor,
                  child: const Center(
                    child: Icon(Icons.movie, size: 80, color: Colors.white24),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: AppTheme.spacingMedium,
                right: AppTheme.spacingMedium,
                bottom: AppTheme.spacingMedium,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chipLabel(
                          movie.subjectType == MovieSubjectType.tvSeries
                              ? '剧集'
                              : '电影',
                        ),
                        if (movie.year.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _chipLabel(movie.year),
                        ],
                        if (movie.region.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _chipLabel(movie.region),
                        ],
                        if (movie.rating > 0) ...[
                          const Spacer(),
                          const Icon(Icons.star, size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            movie.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Widget> _buildBodySlivers(
    BuildContext context,
    Movie movie,
    MovieProvider provider,
  ) {
    final sectionBuilders = <WidgetBuilder>[
      (context) => _buildInfoSection(context, movie),
      (context) => _buildWatchSection(context, movie),
      if (_secondarySectionsReady && movie.summary.isNotEmpty)
        (context) => _buildSummarySection(context, movie),
      if (_secondarySectionsReady) (context) => _buildPersonalSection(context),
      if (_secondarySectionsReady && _hasChanges)
        (_) => PrimaryButton(
              label: '保存',
              icon: Icons.check,
              onPressed: () => _save(provider, movie),
            ),
      (_) => const SizedBox(height: AppTheme.spacingXLarge),
    ];

    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final child = sectionBuilders[index](context);
            final isLast = index == sectionBuilders.length - 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppTheme.spacingMedium,
              ),
              child: child,
            );
          }, childCount: sectionBuilders.length),
        ),
      ),
    ];
  }

  Widget _buildInfoSection(BuildContext context, Movie movie) {
    final isSeries = movie.subjectType == MovieSubjectType.tvSeries;
    final castTop = _splitPeople(movie.cast).take(5).toList();
    final genreText = movie.genre.join(' / ');
    final durationLabel = _formatDurationText(movie.durationText);
    final subjectTypeLabel = isSeries ? '剧集' : '电影';

    return RepaintBoundary(
      child: SoftCard(
        showShadow: false,
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '豆瓣信息', icon: Icons.info_outline),
            const SizedBox(height: AppTheme.spacingMedium),
            if (movie.rating > 0)
              _infoRow(
                context,
                Icons.star,
                '评分',
                movie.rating.toStringAsFixed(1),
              ),
            _infoRow(context, Icons.movie_outlined, '类型', subjectTypeLabel),
            if (movie.year.isNotEmpty)
              _infoRow(context, Icons.calendar_today, '年份', movie.year),
            if (movie.publishedAt.isNotEmpty)
              _infoRow(
                context,
                Icons.event,
                isSeries ? '首播' : '上映',
                movie.publishedAt,
              ),
            if (durationLabel.isNotEmpty)
              _infoRow(context, Icons.schedule, '时长', durationLabel),
            if (movie.region.isNotEmpty)
              _infoRow(context, Icons.public, '地区', movie.region),
            if (genreText.isNotEmpty)
              _infoRow(context, Icons.category_outlined, '题材', genreText),
            if (movie.director.isNotEmpty)
              _infoRow(context, Icons.person, '导演', movie.director),
            if (movie.author.isNotEmpty)
              _infoRow(context, Icons.edit_outlined, '编剧', movie.author),
            if (castTop.isNotEmpty)
              _infoRow(
                context,
                Icons.groups,
                '主演(前5)',
                castTop.join(' / '),
              ),
            if (movie.doubanUrl.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingSmall),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _launchUrl(movie.doubanUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('在豆瓣查看'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, Movie movie) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: SoftCard(
        showShadow: false,
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '简介', icon: Icons.notes_rounded),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              movie.summary,
              maxLines: _summaryExpanded ? null : 4,
              overflow: _summaryExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            if (movie.summary.length > 80) ...[
              const SizedBox(height: AppTheme.spacingSmall),
              TextButton(
                onPressed: () {
                  setState(() => _summaryExpanded = !_summaryExpanded);
                },
                child: Text(_summaryExpanded ? '收起' : '展开'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWatchSection(BuildContext context, Movie movie) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSeries = movie.subjectType == MovieSubjectType.tvSeries;
    final episodeTotal = _episodes.length;
    final watchedEpisodes = _episodes
        .where((episode) => episode.watched)
        .length;

    return RepaintBoundary(
      child: SoftCard(
        showShadow: false,
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '我的记录', icon: Icons.bookmark_border),
            const SizedBox(height: AppTheme.spacingMedium),
            _buildWatchedControls(
              context,
              movie,
              colorScheme,
              watchedEpisodes: watchedEpisodes,
              episodeTotal: episodeTotal,
            ),
            if (isSeries) ...[
              const SizedBox(height: AppTheme.spacingMedium),
              _buildEpisodeControls(context, movie, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: SoftCard(
        showShadow: false,
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的评分',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildStarRating(colorScheme),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              '我的短评',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '记录你对这部作品的想法...'),
              onChanged: (_) => _markChanged(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, {IconData? icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.75),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
        ],
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildWatchedControls(
    BuildContext context,
    Movie movie,
    ColorScheme colorScheme, {
    required int watchedEpisodes,
    required int episodeTotal,
  }) {
    final isSeries = movie.subjectType == MovieSubjectType.tvSeries;
    final hasEpisodeList = isSeries && episodeTotal > 0;
    final statusLabel = hasEpisodeList
        ? (_watched ? '已看完' : '未看完')
        : (_watched ? '已看' : '未看');

    return Column(
      children: [
        Row(
          children: [
            Icon(
              _watched ? Icons.visibility : Icons.visibility_off_outlined,
              color: _watched
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Switch.adaptive(
              value: _watched,
              activeColor: colorScheme.primary,
              onChanged: _isSyncingWatchState
                  ? null
                  : (value) => _setWatched(
                      context.read<MovieProvider>(),
                      movie,
                      value,
                    ),
            ),
          ],
        ),
        if (hasEpisodeList) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          Row(
            children: [
              Text(
                '进度 $watchedEpisodes/$episodeTotal',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              if (_watched)
                Text(
                  '已全部看完',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: episodeTotal == 0 ? 0 : watchedEpisodes / episodeTotal,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
        if (_watched) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          InkWell(
            onTap: _isSyncingWatchState
                ? null
                : () =>
                      _pickDate(context, context.read<MovieProvider>(), movie),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: AppTheme.spacingMedium),
                  Text(
                    _watchedAt != null
                        ? '观看日期：${DateFormat('yyyy-MM-dd').format(_watchedAt!)}'
                        : '选择观看日期',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodeControls(
    BuildContext context,
    Movie movie,
    ColorScheme colorScheme,
  ) {
    final total = _episodes.length;
    final watchedCount = _episodes.where((episode) => episode.watched).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(width: AppTheme.spacingSmall),
            Text(
              '分集',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const Spacer(),
            Text(
              total > 0 ? '已看 $watchedCount/$total' : '未获取到分集列表',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        if (total > 0 && !_episodeControlsReady)
          Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text(
              '分集内容正在准备...',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          )
        else if (total > 0)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(total, (index) {
              final episode = _episodes[index];
              final selected = episode.watched;

              return SizedBox(
                width: 72,
                child: FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.14),
                  ),
                  labelPadding: EdgeInsets.zero,
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(
                      episode.label.isNotEmpty
                          ? episode.label
                          : '${episode.number}',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : colorScheme.onSurface,
                  ),
                  onSelected: _isSyncingWatchState
                      ? null
                      : (_) => _toggleEpisode(
                          context.read<MovieProvider>(),
                          movie,
                          index,
                        ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Future<void> _toggleEpisode(
    MovieProvider provider,
    Movie movie,
    int index,
  ) async {
    if (index < 0 || index >= _episodes.length) return;

    await _updateWatchState(provider, movie, () {
      final next = List<MovieEpisode>.from(_episodes);
      final willWatch = !next[index].watched;

      if (willWatch) {
        // Mark this episode and all before it as watched
        for (var i = 0; i <= index; i++) {
          next[i] = next[i].copyWith(watched: true);
        }
      } else {
        // Unmark this episode and all after it as unwatched
        for (var i = index; i < next.length; i++) {
          next[i] = next[i].copyWith(watched: false);
        }
      }
      _episodes = next;

      final allWatched =
          _episodes.isNotEmpty && _episodes.every((episode) => episode.watched);
      _watched = allWatched;
      _watchedAt = allWatched ? (_watchedAt ?? DateTime.now()) : null;
    });
  }

  Future<void> _setWatched(
    MovieProvider provider,
    Movie movie,
    bool value,
  ) async {
    await _updateWatchState(provider, movie, () {
      final isSeries = movie.subjectType == MovieSubjectType.tvSeries;
      final hasEpisodeList = isSeries && _episodes.isNotEmpty;

      _watched = value;
      if (hasEpisodeList) {
        _episodes = _episodes
            .map((episode) => episode.copyWith(watched: value))
            .toList();
      }

      _watchedAt = value ? (_watchedAt ?? DateTime.now()) : null;
    });
  }

  Future<void> _updateWatchState(
    MovieProvider provider,
    Movie movie,
    VoidCallback applyChange,
  ) async {
    if (_isSyncingWatchState) return;

    final previousEpisodes = List<MovieEpisode>.from(_episodes);
    final previousWatched = _watched;
    final previousWatchedAt = _watchedAt;

    setState(() {
      _isSyncingWatchState = true;
      applyChange();
    });

    final updated = movie.copyWith(
      episodes: _episodes,
      watched: _watched,
      watchedAt: _watched ? (_watchedAt ?? DateTime.now()) : null,
      clearWatchedAt: !_watched,
    );

    await provider.updateMovie(updated);
    if (!mounted) return;

    if (provider.error != null) {
      setState(() {
        _episodes = previousEpisodes;
        _watched = previousWatched;
        _watchedAt = previousWatchedAt;
        _isSyncingWatchState = false;
      });
      AppToast.error(context, provider.error!);
      return;
    }

    setState(() {
      _isSyncingWatchState = false;
    });
  }

  Widget _buildStarRating(ColorScheme colorScheme) {
    final currentRating = _userRating ?? 0;

    return Row(
      children: List.generate(5, (index) {
        final starValue = (index + 1).toDouble();
        final isFilled = currentRating >= starValue;
        final isHalf =
            currentRating >= starValue - 0.5 && currentRating < starValue;

        return GestureDetector(
          onTap: () {
            setState(() {
              _userRating = _userRating == starValue ? null : starValue;
              _hasChanges = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              isFilled
                  ? Icons.star
                  : (isHalf ? Icons.star_half : Icons.star_border),
              size: 36,
              color: (isFilled || isHalf)
                  ? Colors.amber
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        );
      }),
    );
  }

  List<String> _splitPeople(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'\s*/\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatDurationText(String durationText) {
    final text = durationText.trim();
    if (text.isEmpty) return '';

    final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(text);
    if (match == null) return text;

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;

    if (hours > 0 && minutes > 0) return '${hours}小时${minutes}分钟';
    if (hours > 0) return '${hours}小时';
    if (minutes > 0) return '${minutes}分钟';
    return text;
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Text(
            '$label：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    MovieProvider provider,
    Movie movie,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchedAt ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      await _updateWatchState(provider, movie, () {
        _watchedAt = picked;
      });
    }
  }

  Future<void> _save(MovieProvider provider, Movie movie) async {
    final updated = movie.copyWith(
      userRating: _userRating,
      clearUserRating: _userRating == null,
      userReview: _reviewController.text.trim().isNotEmpty
          ? _reviewController.text.trim()
          : null,
      clearUserReview: _reviewController.text.trim().isEmpty,
    );

    await provider.updateMovie(updated);
    if (!mounted) return;

    setState(() {
      _hasChanges = false;
      _seedMovie = updated;
      _movieFuture = _loadMovie(forceRefresh: true);
    });
    AppToast.success(context, '已保存');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
