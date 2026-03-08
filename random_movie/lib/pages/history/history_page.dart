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
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassAppBarDecorator(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(title: const Text('观影记录')),
        body: Consumer<MovieProvider>(
          builder: (context, provider, _) {
            final watched = provider.watchedMovies;

            if (watched.isEmpty) {
              return const EmptyState(
                title: '还没有观影记录',
                subtitle: '在片库中将影片标记为「已看」后，记录会出现在这里',
                icon: Icons.visibility_outlined,
              );
            }

            return ListView.separated(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.of(context).padding.top + AppTheme.spacingMedium,
                left: AppTheme.spacingMedium,
                right: AppTheme.spacingMedium,
                bottom: AppTheme.spacingXLarge * 3,
              ),
              itemCount: watched.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacingMedium),
              itemBuilder: (context, index) {
                return _WatchHistoryCard(
                  movie: watched[index],
                  onTap: () =>
                      context.push('/movies/detail/${watched[index].id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// 观影记录卡片 — 横向布局：左侧海报 + 右侧信息
class _WatchHistoryCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const _WatchHistoryCard({required this.movie, this.onTap});

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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: GlassContainer(
            padding: const EdgeInsets.all(12),
            blurSigma: 18,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: SizedBox(
                      width: 80,
                      height: 112,
                      child: movie.poster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.poster,
                              httpHeaders: ApiConfig.imageHeaders,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.movie, size: 28),
                              ),
                            )
                          : Container(
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

                  // Right: info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: title + douban rating
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
                                    alpha: isDark ? 0.2 : 0.12,
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

                        // Row 2: watch date
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

                        // Row 3: user star rating
                        if (movie.userRating != null && movie.userRating! > 0)
                          Row(
                            children: [
                              ...List.generate(5, (i) {
                                final starVal = (i + 1).toDouble();
                                return Icon(
                                  movie.userRating! >= starVal
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 18,
                                  color: movie.userRating! >= starVal
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

                        // Row 4: review snippet
                        if (movie.userReview != null &&
                            movie.userReview!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '「${movie.userReview!}」',
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
                        ],
                      ],
                    ),
                  ),

                  // Chevron
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
