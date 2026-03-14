import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// 电影卡片组件，带点击缩放动效
class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showWatchedBadge;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
    this.onDelete,
    this.showWatchedBadge = true,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isPressed = false;
  bool _posterReady = false;

  @override
  void initState() {
    super.initState();
    _syncPosterState();
  }

  @override
  void didUpdateWidget(covariant MovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.poster == widget.movie.poster) return;
    _syncPosterState();
  }

  void _syncPosterState() {
    _posterReady = widget.movie.poster.isEmpty;
    if (!_posterReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _posterReady = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final movie = widget.movie;
    final isSeries = movie.subjectType == MovieSubjectType.tvSeries;
    final totalEpisodes = movie.episodes.length;
    final watchedEpisodes = movie.episodes
        .where((episode) => episode.watched)
        .length;
    final hasEpisodeProgress = isSeries && totalEpisodes > 0;
    final progressValue = hasEpisodeProgress
        ? watchedEpisodes / totalEpisodes
        : 0.0;
    final statusLabel = hasEpisodeProgress
        ? '$watchedEpisodes/$totalEpisodes'
        : (movie.watched ? '已看' : '未看');
    final statusBackground = hasEpisodeProgress
        ? (watchedEpisodes == totalEpisodes
              ? colorScheme.primary
              : Colors.black.withValues(alpha: 0.66))
        : (movie.watched
              ? colorScheme.primary
              : Colors.black.withValues(alpha: 0.66));

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: SoftContainer(
            padding: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            showShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (movie.poster.isNotEmpty && _posterReady)
                          CachedNetworkImage(
                            imageUrl: movie.poster,
                            httpHeaders: ApiConfig.imageHeaders,
                            fit: BoxFit.cover,
                            memCacheWidth: 280,
                            maxWidthDiskCache: 280,
                            fadeInDuration: Duration.zero,
                            placeholder: (_, __) => ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.movie, size: 32),
                            ),
                          )
                        else
                          ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.movie,
                              size: 32,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                        if (widget.showWatchedBadge)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: statusBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasEpisodeProgress) ...[
                                      const Icon(
                                        Icons.tv_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      statusLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (movie.rating > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.66),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      movie.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (widget.onDelete != null)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: widget.onDelete,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.66),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (movie.year.isNotEmpty)
                        Text(
                          movie.year,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      if (hasEpisodeProgress) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 6,
                            backgroundColor: colorScheme.onSurface.withValues(
                              alpha: 0.10,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
