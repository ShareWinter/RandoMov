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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      body: Column(
        children: [
          // --- Stats bar: total import count ---
          Selector<MovieProvider, ({int total, int watched})>(
            selector: (_, p) => (total: p.totalCount, watched: p.watchedCount),
            builder: (context, state, _) {
              if (state.total == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.movie_filter_outlined,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '共导入 ${state.total} 部',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '已看 ${state.watched}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.accent.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '未看 ${state.total - state.watched}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AppTheme.spacingSmall),

          // --- Filter bar: all / watched / unwatched ---
          Selector<MovieProvider, LibraryFilter>(
            selector: (_, p) => p.libraryFilter,
            builder: (context, currentFilter, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                ),
                child: _LibraryFilterBar(
                  currentFilter: currentFilter,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onFilterChanged: (filter) {
                    context.read<MovieProvider>().setLibraryFilter(filter);
                  },
                ),
              );
            },
          ),

          const SizedBox(height: AppTheme.spacingSmall),

          // --- Movie grid ---
          Expanded(
            child: Selector<
              MovieProvider,
              ({
                List<Movie> movies,
                bool hasLoadedLibrary,
                bool isLibraryLoading,
                bool isLibraryLoadingMore,
                bool hasMoreLibrary,
                String? error,
                String searchQuery,
                LibraryFilter filter,
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
                filter: provider.libraryFilter,
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
                  final emptyLabel = switch (state.filter) {
                    LibraryFilter.watched => '还没有已看的电影',
                    LibraryFilter.unwatched => '所有电影都看过啦',
                    LibraryFilter.all => state.searchQuery.isEmpty
                        ? '片库还是空的'
                        : '没有找到匹配的电影',
                  };
                  final emptySubtitle = switch (state.filter) {
                    LibraryFilter.watched => '看完电影后标记一下吧',
                    LibraryFilter.unwatched => '添加新电影继续探索',
                    LibraryFilter.all => state.searchQuery.isEmpty
                        ? '添加你的第一部电影吧'
                        : '试试其他搜索词',
                  };

                  return EmptyState(
                    title: emptyLabel,
                    subtitle: emptySubtitle,
                    icon: Icons.movie_outlined,
                    onAction:
                        state.filter == LibraryFilter.all &&
                            state.searchQuery.isEmpty
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
                    top: AppTheme.spacingSmall,
                    left: AppTheme.spacingMedium,
                    right: AppTheme.spacingMedium,
                    bottom: 100,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
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
          ),
        ],
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

/// Filter bar using compact chips for all / watched / unwatched.
class _LibraryFilterBar extends StatelessWidget {
  const _LibraryFilterBar({
    required this.currentFilter,
    required this.isDark,
    required this.colorScheme,
    required this.textTheme,
    required this.onFilterChanged,
  });

  final LibraryFilter currentFilter;
  final bool isDark;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<LibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip(LibraryFilter.all, '全部'),
        const SizedBox(width: AppTheme.spacingSmall),
        _buildChip(LibraryFilter.unwatched, '未看'),
        const SizedBox(width: AppTheme.spacingSmall),
        _buildChip(LibraryFilter.watched, '已看'),
      ],
    );
  }

  Widget _buildChip(LibraryFilter filter, String label) {
    final isSelected = currentFilter == filter;
    final bgColor = isSelected
        ? AppTheme.accent
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06));
    final fgColor = isSelected
        ? Colors.white
        : colorScheme.onSurface.withValues(alpha: 0.65);

    return GestureDetector(
      onTap: () => onFilterChanged(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: fgColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
