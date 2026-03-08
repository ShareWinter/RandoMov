import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// 影片详情页
class MovieDetailPage extends StatefulWidget {
  final String movieId;
  const MovieDetailPage({super.key, required this.movieId});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late double? _userRating;
  late bool _watched;
  late DateTime? _watchedAt;
  late TextEditingController _reviewController;
  bool _initialized = false;
  bool _hasChanges = false;

  void _initFromMovie(Movie movie) {
    if (_initialized) return;
    _userRating = movie.userRating;
    _watched = movie.watched;
    _watchedAt = movie.watchedAt;
    _reviewController = TextEditingController(text: movie.userReview ?? '');
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MovieProvider>(
      builder: (context, provider, _) {
        final movie = provider.getMovieById(widget.movieId);
        if (movie == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('影片不存在')),
          );
        }

        _initFromMovie(movie);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, movie),
              SliverToBoxAdapter(
                child: _buildBody(context, movie, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Collapsible poster header
  Widget _buildSliverAppBar(BuildContext context, Movie movie) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (movie.poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: movie.poster,
                httpHeaders: ApiConfig.imageHeaders,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.movie, size: 80, color: Colors.white24),
              ),
            // Bottom gradient for readability
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
            // Title overlay at bottom
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
                      if (movie.year.isNotEmpty)
                        _chipLabel(movie.year),
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
        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Body content below poster
  Widget _buildBody(BuildContext context, Movie movie, MovieProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genre chips
          if (movie.genre.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: movie.genre.map((g) => Chip(
                label: Text(g, style: const TextStyle(fontSize: 13)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),

          if (movie.genre.isNotEmpty)
            const SizedBox(height: AppTheme.spacingMedium),

          // Info rows
          if (movie.director.isNotEmpty)
            _infoRow(context, Icons.person, '导演', movie.director),
          if (movie.cast.isNotEmpty)
            _infoRow(context, Icons.groups, '演员', movie.cast),

          // Douban link
          if (movie.doubanUrl.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            TextButton.icon(
              onPressed: () => _launchUrl(movie.doubanUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('在豆瓣查看'),
            ),
          ],

          const SizedBox(height: AppTheme.spacingSmall),
          Divider(color: colorScheme.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: AppTheme.spacingSmall),

          // === My Record Section ===
          Text('我的记录', style: textTheme.titleMedium),
          const SizedBox(height: AppTheme.spacingMedium),

          // Watched toggle + date
          _buildWatchedRow(context, colorScheme),

          const SizedBox(height: AppTheme.spacingLarge),

          // Star rating
          Text('我的评分', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSmall),
          _buildStarRating(colorScheme),

          const SizedBox(height: AppTheme.spacingLarge),

          // Review
          Text('我的短评', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSmall),
          TextField(
            controller: _reviewController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '记录你对这部影片的想法...',
            ),
            onChanged: (_) => _markChanged(),
          ),

          const SizedBox(height: AppTheme.spacingLarge),

          // Save button
          if (_hasChanges)
            PrimaryButton(
              label: '保存',
              icon: Icons.check,
              onPressed: () => _save(provider, movie),
            ),

          const SizedBox(height: AppTheme.spacingXLarge),
        ],
      ),
    );
  }

  /// Watched row with toggle and optional date
  Widget _buildWatchedRow(BuildContext context, ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _watched ? Icons.visibility : Icons.visibility_off_outlined,
                color: _watched ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: Text(
                  _watched ? '已看' : '未看',
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
                onChanged: (val) {
                  setState(() {
                    _watched = val;
                    if (val && _watchedAt == null) {
                      _watchedAt = DateTime.now();
                    }
                    _hasChanges = true;
                  });
                },
              ),
            ],
          ),
          if (_watched) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            InkWell(
              onTap: () => _pickDate(context),
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
      ),
    );
  }

  /// Interactive 5-star rating
  Widget _buildStarRating(ColorScheme colorScheme) {
    final currentRating = _userRating ?? 0;
    return Row(
      children: List.generate(5, (index) {
        final starValue = (index + 1).toDouble();
        final isFilled = currentRating >= starValue;
        final isHalf = currentRating >= starValue - 0.5 && currentRating < starValue;

        return GestureDetector(
          onTap: () {
            setState(() {
              // Tap same star again to clear
              if (_userRating == starValue) {
                _userRating = null;
              } else {
                _userRating = starValue;
              }
              _hasChanges = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              isFilled ? Icons.star : (isHalf ? Icons.star_half : Icons.star_border),
              size: 36,
              color: (isFilled || isHalf) ? Colors.amber : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        );
      }),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.55)),
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
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchedAt ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _watchedAt = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _save(MovieProvider provider, Movie movie) async {
    final updated = movie.copyWith(
      watched: _watched,
      watchedAt: _watchedAt,
      clearWatchedAt: !_watched,
      userRating: _userRating,
      clearUserRating: _userRating == null,
      userReview: _reviewController.text.trim().isNotEmpty
          ? _reviewController.text.trim()
          : null,
      clearUserReview: _reviewController.text.trim().isEmpty,
    );
    await provider.updateMovie(updated);
    if (mounted) {
      setState(() => _hasChanges = false);
      AppToast.success(context, '已保存');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
