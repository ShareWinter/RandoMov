import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/providers/providers.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// 抽奖历史页面
class DrawHistoryPage extends StatefulWidget {
  const DrawHistoryPage({super.key});

  @override
  State<DrawHistoryPage> createState() => _DrawHistoryPageState();
}

class _DrawHistoryPageState extends State<DrawHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  bool _requestedInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) return;
    _requestedInitialLoad = true;
    context.read<DrawHistoryProvider>().ensureLoaded();
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
      context.read<DrawHistoryProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('抽奖历史'),
        actions: [
          Consumer<DrawHistoryProvider>(
            builder: (context, provider, _) {
              if (provider.records.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _confirmClear(context, provider),
              );
            },
          ),
        ],
      ),
      body: Consumer<DrawHistoryProvider>(
        builder: (context, provider, _) {
          final records = provider.records;

          if (provider.isLoading && records.isEmpty) {
            return const LoadingState(message: '加载中...');
          }

          if (provider.error != null && records.isEmpty) {
            return ErrorState(
              message: provider.error!,
              onRetry: provider.refresh,
            );
          }

          if (records.isEmpty) {
            return const EmptyState(
              title: '还没有抽奖记录',
              subtitle: '去抽一次片吧',
              icon: Icons.casino_outlined,
            );
          }

          final itemCount = provider.hasMore || provider.isLoadingMore
              ? records.length + 1
              : records.length;

          return ListView.separated(
            key: const PageStorageKey('draw-history-list'),
            controller: _scrollController,
            cacheExtent: MediaQuery.of(context).size.height * 1.5,
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
              if (index >= records.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppTheme.spacingLarge,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final record = records[index];
              return _DrawHistoryCard(
                record: record,
                onTap: () => context.push('/movies/detail/${record.movieId}'),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context, DrawHistoryProvider provider) {
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
          '清空历史',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
          ),
        ),
        content: Text(
          '确定要清空所有抽奖记录吗？此操作不可恢复。',
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
              provider.clearAll();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            child: const Text(
              '清空',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawHistoryCard extends StatefulWidget {
  final DrawRecord record;
  final VoidCallback? onTap;

  const _DrawHistoryCard({required this.record, this.onTap});

  @override
  State<_DrawHistoryCard> createState() => _DrawHistoryCardState();
}

class _DrawHistoryCardState extends State<_DrawHistoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final record = widget.record;

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
        scale: _pressed ? 0.98 : 1.0,
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
          child: SoftContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: SizedBox(
                      width: 72,
                      height: 100,
                      child: record.moviePoster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: record.moviePoster,
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
                                child: const Icon(Icons.movie, size: 24),
                              ),
                            )
                          : ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.movie,
                                size: 24,
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
                                record.movieTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: record.mode == 'solo'
                                    ? AppTheme.accent.withValues(alpha: 0.15)
                                    : const Color(
                                        0xFF5C7CFA,
                                      ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                record.mode == 'solo' ? '单人' : '房间',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: record.mode == 'solo'
                                      ? AppTheme.accent
                                      : const Color(0xFF5C7CFA),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat(
                                'yyyy年M月d日 HH:mm',
                              ).format(record.drawnAt),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${record.participants.length} 人参与',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.movie_outlined,
                              size: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '共 ${record.candidateCount} 部参与',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
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
