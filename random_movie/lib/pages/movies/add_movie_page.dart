import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/movie.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:random_movie/widgets/movie/movie_card.dart';

/// 添加电影页面
class AddMoviePage extends StatefulWidget {
  const AddMoviePage({super.key});

  @override
  State<AddMoviePage> createState() => _AddMoviePageState();
}

class _AddMoviePageState extends State<AddMoviePage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _placeholderController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _directorController = TextEditingController();

  Movie? _previewMovie;
  List<Movie>? _previewMovies;
  bool _isLoading = false;
  bool _isDoulistLoading = false;
  int _doulistCompleted = 0;
  int _doulistTotal = 0;
  String? _doulistCurrentTitle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _placeholderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _placeholderController.dispose();
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
        title: const Text('添加电影'),
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
        children: [_buildDoubanTab(), _buildManualTab()],
      ),
    );
  }

  Widget _buildDoubanTab() {
    final textTheme = Theme.of(context).textTheme;
    final hasPreviewMovie = _previewMovie != null;
    final hasPreviewMovies =
        _previewMovies != null && _previewMovies!.isNotEmpty;
    final showDoulistSection = hasPreviewMovies || _isDoulistLoading;

    return CustomScrollView(
      key: const PageStorageKey('add-movie-douban-tab'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          sliver: SliverList.list(
            children: [
              SoftCard(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '豆瓣导入',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXSmall),
                    Text(
                      '支持电影链接、豆瓣 App 跳转链接和片单链接，如果失败请多尝试两次。',
                      style: textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: '粘贴豆瓣电影或片单链接',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon:
                            _urlController.text.isNotEmpty && !_isLoading
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _urlController.clear();
                                  setState(() {
                                    _isDoulistLoading = false;
                                    _doulistCompleted = 0;
                                    _doulistTotal = 0;
                                    _doulistCurrentTitle = null;
                                    _previewMovie = null;
                                    _previewMovies = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),
                    PrimaryButton(
                      label: _buildFetchButtonLabel(),
                      icon: Icons.search,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _scrapeFromUrl(),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: AppTheme.spacingMedium),
                      _buildScrapeProgressCard(),
                    ],
                  ],
                ),
              ),
              if (_isLoading && !_isDoulistLoading && !hasPreviewMovie) ...[
                const SizedBox(height: AppTheme.spacingLarge),
                _buildSectionHeader(title: '预览生成中', subtitle: '正在解析单片详情，请稍候。'),
                const SizedBox(height: AppTheme.spacingMedium),
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 320,
                    child: _buildMoviePlaceholderCard(),
                  ),
                ),
              ],
              if (hasPreviewMovie) ...[
                const SizedBox(height: AppTheme.spacingLarge),
                _buildSectionHeader(title: '单片预览', subtitle: '确认信息后可直接加入片库。'),
                const SizedBox(height: AppTheme.spacingMedium),
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 320,
                    child: MovieCard(movie: _previewMovie!, onTap: null),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                PrimaryButton(
                  label: '添加到片库',
                  icon: Icons.add,
                  onPressed: () => _addMovie(_previewMovie!),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
              ],
              if (showDoulistSection) ...[
                const SizedBox(height: AppTheme.spacingLarge),
                _buildDoulistSectionHeader(),
                const SizedBox(height: AppTheme.spacingMedium),
              ],
            ],
          ),
        ),
        if (showDoulistSection)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMedium,
              0,
              AppTheme.spacingMedium,
              AppTheme.spacingLarge,
            ),
            sliver: SliverGrid.builder(
              itemCount: _gridItemCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.60,
                crossAxisSpacing: AppTheme.spacingMedium,
                mainAxisSpacing: AppTheme.spacingMedium,
              ),
              itemBuilder: (context, index) {
                if (index >= (_previewMovies?.length ?? 0)) {
                  return _buildMoviePlaceholderCard();
                }

                final movie = _previewMovies![index];
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    MovieCard(movie: movie, onTap: () => _addMovie(movie)),
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
          ),
      ],
    );
  }

  int get _gridItemCount {
    final previewCount = _previewMovies?.length ?? 0;
    return previewCount + _loadingPlaceholderCount;
  }

  int get _loadingPlaceholderCount {
    if (!_isDoulistLoading) return 0;

    if (_doulistTotal <= 0) {
      return 4;
    }

    final remaining = _doulistTotal - _doulistCompleted;
    if (remaining <= 0) return 0;
    return remaining > 4 ? 4 : remaining;
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXSmall),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.spacingMedium),
          trailing,
        ],
      ],
    );
  }

  Widget _buildDoulistSectionHeader() {
    final title = _isDoulistLoading && _doulistTotal > 0
        ? '已获取 ${_previewMovies?.length ?? 0}/$_doulistTotal 部影片'
        : '找到 ${_previewMovies?.length ?? 0} 部电影';
    final subtitle = _isDoulistLoading
        ? '真实卡片会先显示，未完成的条目用占位卡补齐。'
        : '支持逐部添加，也可以一次性加入片库。';

    return _buildSectionHeader(
      title: title,
      subtitle: subtitle,
      trailing: PrimaryButton(
        label: '全部添加',
        icon: Icons.add,
        isFullWidth: false,
        onPressed: _isLoading || (_previewMovies?.isEmpty ?? true)
            ? null
            : () => _addAllMovies(_previewMovies!),
      ),
    );
  }

  Widget _buildMoviePlaceholderCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _placeholderController,
      builder: (context, child) {
        final surface = Color.lerp(
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurface.withValues(alpha: 0.08),
          _placeholderController.value,
        )!;
        final highlight = Color.lerp(
          colorScheme.onSurface.withValues(alpha: 0.06),
          colorScheme.onSurface.withValues(alpha: 0.14),
          _placeholderController.value,
        )!;

        return SoftContainer(
          padding: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [surface, highlight, surface],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.movie_creation_outlined,
                        size: 28,
                        color: colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildPlaceholderBar(
                widthFactor: 0.82,
                height: 15,
                color: highlight,
              ),
              const SizedBox(height: 8),
              _buildPlaceholderBar(
                widthFactor: 0.52,
                height: 11,
                color: surface,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: null,
                  minHeight: 6,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(highlight),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderBar({
    required double widthFactor,
    required double height,
    required Color color,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('add-movie-manual-tab'),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '电影名称 *',
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
            label: '添加电影',
            icon: Icons.add,
            onPressed: () => _addManualMovie(),
          ),
        ],
      ),
    );
  }

  Future<void> _scrapeFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('请输入链接');
      return;
    }

    FocusScope.of(context).unfocus();
    final isDoulistUrl = url.contains('/doulist/');
    setState(() {
      _isLoading = true;
      _isDoulistLoading = isDoulistUrl;
      _doulistCompleted = 0;
      _doulistTotal = 0;
      _doulistCurrentTitle = null;
      _previewMovie = null;
      _previewMovies = null;
    });

    try {
      final provider = context.read<MovieProvider>();
      if (url.contains('/subject/') || url.contains('/dispatch/movie/')) {
        final movie = await provider.fetchMoviePreview(url);
        if (!mounted) return;
        if (movie != null) {
          setState(() => _previewMovie = movie);
        } else if (provider.error != null) {
          _showError(provider.error!);
        }
      } else if (url.contains('/doulist/')) {
        final movies = await provider.fetchDoulistPreview(
          url,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _doulistCompleted = progress.completed;
              _doulistTotal = progress.total;
              _doulistCurrentTitle = progress.currentTitle;
              _previewMovies = progress.movies;
            });
          },
        );
        if (!mounted) return;
        if (movies.isNotEmpty) {
          setState(() => _previewMovies = movies);
        } else if (provider.error != null) {
          _showError(provider.error!);
        }
      } else {
        _showError('无效的链接格式');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDoulistLoading = false;
        });
      }
    }
  }

  String _buildFetchButtonLabel() {
    if (!_isLoading) {
      return '获取电影信息';
    }

    if (_isDoulistLoading && _doulistTotal > 0) {
      return '获取中 $_doulistCompleted/$_doulistTotal';
    }

    return '获取中...';
  }

  Widget _buildScrapeProgressCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progressValue = _doulistTotal > 0
        ? _doulistCompleted / _doulistTotal
        : null;

    return SoftCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isDoulistLoading ? '正在抓取片单详情' : '正在解析单片详情',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            _isDoulistLoading
                ? (_doulistTotal > 0
                      ? '已完成 $_doulistCompleted / $_doulistTotal，结果会陆续显示在下方'
                      : '正在解析片单入口并准备抓取详情...')
                : '正在解析豆瓣页面结构化数据...',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          if ((_doulistCurrentTitle ?? '').isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              '最近完成：$_doulistCurrentTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addManualMovie() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('请输入电影名称');
      return;
    }

    final provider = context.read<MovieProvider>();
    await provider.addManualMovie(
      title: title,
      year: _yearController.text.trim(),
      director: _directorController.text.trim(),
    );

    if (!mounted) return;
    if (provider.error == null) {
      context.pop();
      _showSuccess('已添加 $title');
    } else {
      _showError(provider.error!);
    }
  }

  Future<void> _addMovie(Movie movie) async {
    final provider = context.read<MovieProvider>();
    final saved = await provider.addScrapedMovie(movie);
    if (!mounted) return;

    if (saved != null) {
      _showSuccess('已添加 ${movie.title}');
      setState(() => _previewMovie = null);
    } else if (provider.error != null) {
      _showError(provider.error!);
    }
  }

  Future<void> _addAllMovies(List<Movie> movies) async {
    final provider = context.read<MovieProvider>();
    final result = await provider.addScrapedMovies(movies);
    if (!mounted) return;

    if (result.added > 0 && result.skipped > 0) {
      _showSuccess('已添加 ${result.added} 部，${result.skipped} 部已存在');
    } else if (result.added > 0) {
      _showSuccess('成功添加 ${result.added} 部电影');
    } else {
      _showError('所有电影均已在片库中');
    }

    if (result.added > 0 && result.skipped == 0) {
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
