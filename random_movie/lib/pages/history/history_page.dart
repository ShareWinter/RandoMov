import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// 观影历史页面
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      context.read<MovieProvider>().loadMoreWatchedHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('观影记录')),
      body: Selector<
        MovieProvider,
        ({
          List<Movie> watchedMovies,
          bool hasLoadedHistory,
          bool isHistoryLoading,
          bool isHistoryLoadingMore,
          bool hasMoreHistory,
          String? error,
        })
      >(
        selector: (_, provider) => (
          watchedMovies: provider.watchedMovies,
          hasLoadedHistory: provider.hasLoadedHistory,
          isHistoryLoading: provider.isHistoryLoading,
          isHistoryLoadingMore: provider.isHistoryLoadingMore,
          hasMoreHistory: provider.hasMoreHistory,
          error: provider.error,
        ),
        builder: (context, state, _) {
          final watched = state.watchedMovies;

          if ((!state.hasLoadedHistory || state.isHistoryLoading) &&
              watched.isEmpty) {
            return const LoadingState(message: '加载中...');
          }

          if (state.error != null && watched.isEmpty) {
            return ErrorState(
              message: state.error!,
              onRetry: context.read<MovieProvider>().refreshWatchedHistory,
            );
          }

          if (watched.isEmpty) {
            return const EmptyState(
              title: '还没有观影记录',
              subtitle: '在片库中将电影标记为“已看”后，记录会出现在这里',
              icon: Icons.visibility_outlined,
            );
          }

          final itemCount =
              state.hasMoreHistory || state.isHistoryLoadingMore
              ? watched.length + 1
              : watched.length;

          return ListView.separated(
            key: const PageStorageKey('history-list'),
            controller: _scrollController,
            cacheExtent: MediaQuery.of(context).size.height * 1.25,
            padding: const EdgeInsets.only(
              top: AppTheme.spacingMedium,
              left: AppTheme.spacingMedium,
              right: AppTheme.spacingMedium,
              bottom: AppTheme.spacingXLarge * 3,
            ),
            itemCount: itemCount,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppTheme.spacingMedium),
            itemBuilder: (context, index) {
              if (index >= watched.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppTheme.spacingLarge,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final movie = watched[index];
              return RepaintBoundary(
                child: _WatchHistoryCard(
                  key: ValueKey(movie.id),
                  movie: movie,
                  onTap: () => context.push('/movies/detail/${movie.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WatchHistoryCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const _WatchHistoryCard({super.key, required this.movie, this.onTap});

  @override
  State<_WatchHistoryCard> createState() => _WatchHistoryCardState();
}

class _WatchHistoryCardState extends State<_WatchHistoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movie = widget.movie;
    final watchDate = movie.watchedAt ?? movie.createdAt;

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SoftContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: SizedBox(
                      width: 80,
                      height: 112,
                      child: movie.poster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.poster,
                              httpHeaders: ApiConfig.imageHeaders,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              maxWidthDiskCache: 160,
                              fadeInDuration: Duration.zero,
                              placeholder: (_, __) => ColoredBox(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (_, __, ___) => ColoredBox(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.movie, size: 28),
                              ),
                            )
                          : ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.movie,
                                size: 28,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                movie.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (movie.rating > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(
                                    alpha: isDark ? 0.18 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 13,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      movie.rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.amber
                                            : Colors.amber.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('yyyy年M月d日').format(watchDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            if (movie.year.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text(
                                movie.year,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (movie.userRating != null && movie.userRating! > 0)
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                final starValue = (index + 1).toDouble();
                                return Icon(
                                  movie.userRating! >= starValue
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 18,
                                  color: movie.userRating! >= starValue
                                      ? Colors.amber
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.2,
                                        ),
                                );
                              }),
                              const SizedBox(width: 6),
                              Text(
                                '我的评分',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (movie.userReview != null &&
                            movie.userReview!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              '“${movie.userReview!}”',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
