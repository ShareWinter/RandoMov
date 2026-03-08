import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:random_movie/widgets/movie/movie_card.dart';

/// 片库页面
class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassAppBarDecorator(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '搜索影片...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    context.read<MovieProvider>().setSearchQuery(value);
                  },
                )
              : const Text('我的片库'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    context.read<MovieProvider>().setSearchQuery('');
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ],
        ),
        body: Consumer<MovieProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.allMovies.isEmpty) {
              return const LoadingState(message: '加载中...');
            }

            if (provider.error != null && provider.allMovies.isEmpty) {
              return ErrorState(
                message: provider.error!,
                onRetry: () => provider.loadMovies(),
              );
            }

            final movies = provider.movies;

            if (movies.isEmpty) {
              return EmptyState(
                title: provider.searchQuery.isEmpty
                    ? '片库还是空的'
                    : '没有找到匹配的影片',
                subtitle: provider.searchQuery.isEmpty
                    ? '添加你的第一部影片吧'
                    : '试试其他搜索词',
                icon: Icons.movie_outlined,
                onAction: provider.searchQuery.isEmpty
                    ? () => _navigateToAddMovie(context)
                    : null,
                actionLabel: '添加影片',
              );
            }

            return GridView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + AppTheme.spacingMedium,
                left: AppTheme.spacingMedium,
                right: AppTheme.spacingMedium,
                bottom: 100,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.60,
                crossAxisSpacing: AppTheme.spacingMedium,
                mainAxisSpacing: AppTheme.spacingMedium,
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                return MovieCard(
                  movie: movie,
                  onTap: () => context.push('/movies/detail/${movie.id}'),
                  onDelete: () => _confirmDelete(context, provider, movie),
                );
              },
            );
          },
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FloatingActionButton.extended(
            onPressed: () => _navigateToAddMovie(context),
            icon: const Icon(Icons.add),
            label: const Text('添加'),
          ),
        ),
      ),
    );
  }

  void _navigateToAddMovie(BuildContext context) {
    context.push('/movies/add');
  }

  void _confirmDelete(BuildContext context, MovieProvider provider, Movie movie) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: isDark
              ? const Color(0xCC1A1A2E)
              : const Color(0xCCFFFFFF),
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            side: BorderSide(
              color: isDark
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x14000000),
              width: 1,
            ),
          ),
          title: Text(
            '确认删除',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
            ),
          ),
          content: Text(
            '确定要从片库中删除「${movie.title}」吗？',
            style: TextStyle(
              color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryDarkOnLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '取消',
                style: TextStyle(
                  color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryDarkOnLight,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                provider.deleteMovie(movie.id);
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
              child: const Text('删除', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
