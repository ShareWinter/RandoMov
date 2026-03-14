import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';

/// 可选择电影网格
class SelectableMovieGrid extends StatelessWidget {
  final List<Movie> movies;
  final Set<String> selectedIds;
  final ValueChanged<Movie> onToggle;
  final ScrollController? controller;
  final bool hasMore;
  final bool isLoadingMore;
  final EdgeInsetsGeometry padding;
  final Key? storageKey;

  const SelectableMovieGrid({
    super.key,
    required this.movies,
    required this.selectedIds,
    required this.onToggle,
    this.controller,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.spacingMedium,
    ),
    this.storageKey,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemCount = hasMore || isLoadingMore
        ? movies.length + 1
        : movies.length;

    return GridView.builder(
      key: storageKey,
      controller: controller,
      padding: padding,
      cacheExtent: MediaQuery.of(context).size.height * 1.1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.60,
        crossAxisSpacing: AppTheme.spacingSmall,
        mainAxisSpacing: AppTheme.spacingSmall,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= movies.length) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final movie = movies[index];
        final selected = selectedIds.contains(movie.id);

        return RepaintBoundary(
          child: _SelectableMovieTile(
            key: ValueKey('${movie.id}-$selected'),
            movie: movie,
            selected: selected,
            colorScheme: colorScheme,
            onTap: () => onToggle(movie),
          ),
        );
      },
    );
  }
}

class _SelectableMovieTile extends StatelessWidget {
  final Movie movie;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _SelectableMovieTile({
    super.key,
    required this.movie,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: selected ? 1.0 : 0.52,
        duration: const Duration(milliseconds: 120),
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
                          memCacheWidth: 240,
                          maxWidthDiskCache: 240,
                          fadeInDuration: Duration.zero,
                          placeholder: (_, __) => ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.movie, size: 28),
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.movie, size: 28),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
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
            Positioned(
              top: 4,
              right: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppTheme.accent
                      : Colors.black.withValues(alpha: 0.45),
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
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
  }
}
