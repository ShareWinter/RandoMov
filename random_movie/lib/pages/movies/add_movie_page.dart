import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:random_movie/widgets/movie/movie_card.dart';

/// 添加影片页面
class AddMoviePage extends StatefulWidget {
  const AddMoviePage({super.key});

  @override
  State<AddMoviePage> createState() => _AddMoviePageState();
}

class _AddMoviePageState extends State<AddMoviePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _directorController = TextEditingController();
  
  Movie? _previewMovie;
  List<Movie>? _previewMovies;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _yearController.dispose();
    _directorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加影片'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.55),
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: '豆瓣链接', icon: Icon(Icons.link)),
            Tab(text: '手动添加', icon: Icon(Icons.edit)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDoubanTab(),
          _buildManualTab(),
        ],
      ),
    );
  }

  /// 豆瓣链接 Tab
  Widget _buildDoubanTab() {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: '粘贴豆瓣影片或片单链接',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            '支持：\n• 影片链接：https://movie.douban.com/subject/xxxx/\n• 片单链接：https://www.douban.com/doulist/xxxx/',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          PrimaryButton(
            label: _isLoading ? '获取中...' : '获取影片信息',
            icon: Icons.search,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _scrapeFromUrl,
          ),
          if (_previewMovie != null) ...[
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              '预览',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            MovieCard(
              movie: _previewMovie!,
              onTap: null,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            PrimaryButton(
              label: '添加到片库',
              icon: Icons.add,
              onPressed: () => _addMovie(_previewMovie!),
            ),
          ],
          if (_previewMovies != null && _previewMovies!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '找到 ${_previewMovies!.length} 部影片',
                  style: textTheme.titleMedium,
                ),
                PrimaryButton(
                  label: '全部添加',
                  icon: Icons.add,
                  isFullWidth: false,
                  onPressed: () => _addAllMovies(_previewMovies!),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.60,
                crossAxisSpacing: AppTheme.spacingMedium,
                mainAxisSpacing: AppTheme.spacingMedium,
              ),
              itemCount: _previewMovies!.length,
              itemBuilder: (context, index) {
                final movie = _previewMovies![index];
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    MovieCard(
                      movie: movie,
                      onTap: () => _addMovie(movie),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _addMovie(movie),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 手动添加 Tab
  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '影片名称 *',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          TextField(
            controller: _yearController,
            decoration: const InputDecoration(
              hintText: '年份（可选）',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          TextField(
            controller: _directorController,
            decoration: const InputDecoration(
              hintText: '导演（可选）',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          PrimaryButton(
            label: '添加影片',
            icon: Icons.add,
            onPressed: _addManualMovie,
          ),
        ],
      ),
    );
  }

  /// 从链接爬取
  Future<void> _scrapeFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('请输入链接');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _previewMovie = null;
      _previewMovies = null;
    });

    try {
      final provider = context.read<MovieProvider>();

      if (url.contains('/subject/')) {
        // 单个影片：仅预览，不保存
        final movie = await provider.fetchMoviePreview(url);
        if (movie != null) {
          setState(() {
            _previewMovie = movie;
          });
        } else if (provider.error != null) {
          _showError(provider.error!);
        }
      } else if (url.contains('/doulist/')) {
        // 片单：仅预览，不保存
        final movies = await provider.fetchDoulistPreview(url);
        if (movies.isNotEmpty) {
          setState(() {
            _previewMovies = movies;
          });
        } else if (provider.error != null) {
          _showError(provider.error!);
        }
      } else {
        _showError('无效的链接格式');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 手动添加
  Future<void> _addManualMovie() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('请输入影片名称');
      return;
    }

    final provider = context.read<MovieProvider>();
    await provider.addManualMovie(
      title: title,
      year: _yearController.text.trim(),
      director: _directorController.text.trim(),
    );

    if (provider.error == null) {
      if (mounted) {
        context.pop();
        _showSuccess('已添加: $title');
      }
    } else {
      _showError(provider.error!);
    }
  }

  /// 添加单个影片（保存完整对象，含海报/评分等字段）
  Future<void> _addMovie(Movie movie) async {
    final provider = context.read<MovieProvider>();
    final saved = await provider.addScrapedMovie(movie);

    if (saved != null) {
      _showSuccess('已添加: ${movie.title}');
      setState(() {
        _previewMovie = null;
      });
    } else if (provider.error != null) {
      _showError(provider.error!);
    }
  }

  /// 批量添加（跳过重复项）
  Future<void> _addAllMovies(List<Movie> movies) async {
    final provider = context.read<MovieProvider>();
    final result = await provider.addScrapedMovies(movies);

    if (result.added > 0 && result.skipped > 0) {
      _showSuccess('已添加 ${result.added} 部，${result.skipped} 部已在片库中');
    } else if (result.added > 0) {
      _showSuccess('成功添加 ${result.added} 部影片');
    } else {
      _showError('所有影片均已在片库中');
    }

    if (mounted && result.skipped == 0) {
      context.pop();
    }
  }

  void _showError(String message) {
    AppToast.error(context, message);
  }

  void _showSuccess(String message) {
    AppToast.success(context, message);
  }
}
