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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      context.read<MovieProvider>().loadMoreLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索电影...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                onChanged: (value) {
                  context.read<MovieProvider>().setSearchQueryDebounced(value);
                },
              )
            : const Text('我的片库'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () async {
              if (_isSearching) {
                _searchController.clear();
                await context.read<MovieProvider>().setSearchQuery('');
              }
              if (!mounted) return;
              setState(() {
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: Selector<
        MovieProvider,
        ({
          List<Movie> movies,
          bool hasLoadedLibrary,
          bool isLibraryLoading,
          bool isLibraryLoadingMore,
          bool hasMoreLibrary,
          String? error,
          String searchQuery,
        })
      >(
        selector: (_, provider) => (
          movies: provider.movies,
          hasLoadedLibrary: provider.hasLoadedLibrary,
          isLibraryLoading: provider.isLibraryLoading,
          isLibraryLoadingMore: provider.isLibraryLoadingMore,
          hasMoreLibrary: provider.hasMoreLibrary,
          error: provider.error,
          searchQuery: provider.searchQuery,
        ),
        builder: (context, state, _) {
          final movies = state.movies;

          if ((!state.hasLoadedLibrary || state.isLibraryLoading) &&
              movies.isEmpty) {
            return const LoadingState(message: '加载中...');
          }

          if (state.error != null && movies.isEmpty) {
            return ErrorState(
              message: state.error!,
              onRetry: context.read<MovieProvider>().refreshLibrary,
            );
          }

          if (movies.isEmpty) {
            return EmptyState(
              title: state.searchQuery.isEmpty ? '片库还是空的' : '没有找到匹配的电影',
              subtitle: state.searchQuery.isEmpty ? '添加你的第一部电影吧' : '试试其他搜索词',
              icon: Icons.movie_outlined,
              onAction: state.searchQuery.isEmpty
                  ? () => _navigateToAddMovie(context)
                  : null,
              actionLabel: '添加电影',
            );
          }

          final itemCount =
              state.hasMoreLibrary || state.isLibraryLoadingMore
              ? movies.length + 1
              : movies.length;

          return GridView.builder(
            key: const PageStorageKey('movies-grid'),
            controller: _scrollController,
            cacheExtent: MediaQuery.of(context).size.height * 0.9,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            padding: const EdgeInsets.only(
              top: AppTheme.spacingMedium,
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
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index >= movies.length) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              final movie = movies[index];
              return MovieCard(
                key: ValueKey(movie.id),
                movie: movie,
                onTap: () => context.push('/movies/detail/${movie.id}'),
                onDelete: () => _confirmDelete(
                  context,
                  context.read<MovieProvider>(),
                  movie,
                ),
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
    );
  }

  void _navigateToAddMovie(BuildContext context) {
    context.push('/movies/add');
  }

  void _confirmDelete(
    BuildContext context,
    MovieProvider provider,
    Movie movie,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF222240) : Colors.white,
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: BorderSide(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
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
          '确定要从片库中删除《${movie.title}》吗？',
          style: TextStyle(
            color: isDark
                ? AppTheme.textSecondary
                : AppTheme.textSecondaryDarkOnLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark
                    ? AppTheme.textSecondary
                    : AppTheme.textSecondaryDarkOnLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              provider.deleteMovie(movie.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            child: const Text(
              '删除',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
