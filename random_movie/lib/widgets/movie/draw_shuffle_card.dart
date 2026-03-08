import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// Shared shuffle card used in both solo and room draw animations.
///
/// Displays a movie poster + title inside a glass container with
/// instant image rendering (no fade-in delay) for smooth rapid switching.
class DrawShuffleCard extends StatelessWidget {
  final Movie movie;
  final int shuffleCount;

  const DrawShuffleCard({
    super.key,
    required this.movie,
    required this.shuffleCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      key: ValueKey(movie.id + shuffleCount.toString()),
      width: 200,
      height: 320,
      child: GlassContainer(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: movie.poster.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: movie.poster,
                        httpHeaders: ApiConfig.imageHeaders,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        // Disable fade-in so images render instantly from cache
                        // during rapid 100ms shuffles
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholderFadeInDuration: Duration.zero,
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.movie, size: 48),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
