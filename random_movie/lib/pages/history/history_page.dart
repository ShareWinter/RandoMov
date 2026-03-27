import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// \u89c2\u5f71\u8bb0\u5f55\u9875\u9762
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
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
      context.read<MovieProvider>().loadMoreWatchedHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u89c2\u5f71\u8bb0\u5f55'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
            child: IconButton(
              onPressed: () {
                context.push('/history/calendar');
              },
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ),
        ],
      ),
      body: Selector<
        MovieProvider,
        ({
          List<Movie> watchedMovies,
          bool hasLoadedHistory,
          bool isHistoryLoading,
          bool isHistoryLoadingMore,
          bool hasMoreHistory,
          String? error,
        })
      >(
        selector: (_, provider) => (
          watchedMovies: provider.watchedMovies,
          hasLoadedHistory: provider.hasLoadedHistory,
          isHistoryLoading: provider.isHistoryLoading,
          isHistoryLoadingMore: provider.isHistoryLoadingMore,
          hasMoreHistory: provider.hasMoreHistory,
          error: provider.error,
        ),
        builder: (context, state, _) {
          return _HistoryListView(
            scrollController: _scrollController,
            watchedMovies: state.watchedMovies,
            hasLoadedHistory: state.hasLoadedHistory,
            isHistoryLoading: state.isHistoryLoading,
            isHistoryLoadingMore: state.isHistoryLoadingMore,
            hasMoreHistory: state.hasMoreHistory,
            error: state.error,
          );
        },
      ),
    );
  }
}

class HistoryCalendarPage extends StatefulWidget {
  const HistoryCalendarPage({super.key});

  @override
  State<HistoryCalendarPage> createState() => _HistoryCalendarPageState();
}

class _HistoryCalendarPageState extends State<HistoryCalendarPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MovieProvider>().jumpToCurrentHistoryMonth();
    });
  }

  void _openDaySheet(BuildContext context, HistoryDaySummary summary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _HistoryDaySheet(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
        ),
        title: const Text('\u65e5\u5386'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      body: Selector<
        MovieProvider,
        ({
          bool isHistoryCalendarLoading,
          bool hasLoadedHistoryCalendar,
          HistoryMonthKey visibleMonth,
          HistoryMonthData? visibleMonthData,
          String? error,
        })
      >(
        selector: (_, provider) => (
          isHistoryCalendarLoading: provider.isHistoryCalendarLoading,
          hasLoadedHistoryCalendar: provider.hasLoadedHistoryCalendar,
          visibleMonth: provider.visibleHistoryMonth,
          visibleMonthData: provider.visibleHistoryMonthData,
          error: provider.error,
        ),
        builder: (context, state, _) {
          return _HistoryCalendarView(
            visibleMonth: state.visibleMonth,
            monthData: state.visibleMonthData,
            isLoading: state.isHistoryCalendarLoading,
            hasLoaded: state.hasLoadedHistoryCalendar,
            error: state.error,
            onPreviousMonth: () {
              context.read<MovieProvider>().setVisibleHistoryMonth(
                state.visibleMonth.previous(),
              );
            },
            onNextMonth: () {
              context.read<MovieProvider>().setVisibleHistoryMonth(
                state.visibleMonth.next(),
              );
            },
            onJumpToToday: () {
              context.read<MovieProvider>().jumpToCurrentHistoryMonth();
            },
            onRetry: () {
              context.read<MovieProvider>().refreshHistoryCalendarMonth(
                forceRefresh: true,
              );
            },
            onTapDay: (summary) => _openDaySheet(context, summary),
          );
        },
      ),
    );
  }
}

class _HistoryListView extends StatelessWidget {
  final ScrollController scrollController;
  final List<Movie> watchedMovies;
  final bool hasLoadedHistory;
  final bool isHistoryLoading;
  final bool isHistoryLoadingMore;
  final bool hasMoreHistory;
  final String? error;

  const _HistoryListView({
    required this.scrollController,
    required this.watchedMovies,
    required this.hasLoadedHistory,
    required this.isHistoryLoading,
    required this.isHistoryLoadingMore,
    required this.hasMoreHistory,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if ((!hasLoadedHistory || isHistoryLoading) && watchedMovies.isEmpty) {
      return const LoadingState(message: '\u52a0\u8f7d\u4e2d...');
    }

    if (error != null && watchedMovies.isEmpty) {
      return ErrorState(
        message: error!,
        onRetry: context.read<MovieProvider>().refreshWatchedHistory,
      );
    }

    if (watchedMovies.isEmpty) {
      return const EmptyState(
        title: '\u8fd8\u6ca1\u6709\u89c2\u5f71\u8bb0\u5f55',
        subtitle:
            '\u5728\u7247\u5e93\u4e2d\u5c06\u7535\u5f71\u6807\u8bb0\u4e3a\u201c\u5df2\u770b\u201d\u540e\uff0c\u8bb0\u5f55\u4f1a\u51fa\u73b0\u5728\u8fd9\u91cc\u3002',
        icon: Icons.visibility_outlined,
      );
    }

    final itemCount =
        hasMoreHistory || isHistoryLoadingMore
        ? watchedMovies.length + 1
        : watchedMovies.length;

    return ListView.separated(
      key: const PageStorageKey('history-list'),
      controller: scrollController,
      cacheExtent: MediaQuery.of(context).size.height * 1.25,
      padding: const EdgeInsets.only(
        top: AppTheme.spacingMedium,
        left: AppTheme.spacingMedium,
        right: AppTheme.spacingMedium,
        bottom: AppTheme.spacingXLarge * 3,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spacingMedium),
      itemBuilder: (context, index) {
        if (index >= watchedMovies.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLarge),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final movie = watchedMovies[index];
        return RepaintBoundary(
          child: _WatchHistoryCard(
            key: ValueKey(movie.id),
            movie: movie,
            onTap: () => context.push('/movies/detail/${movie.id}'),
          ),
        );
      },
    );
  }
}

class _HistoryCalendarView extends StatelessWidget {
  static const List<String> _weekdays = [
    '\u65e5',
    '\u4e00',
    '\u4e8c',
    '\u4e09',
    '\u56db',
    '\u4e94',
    '\u516d',
  ];

  final HistoryMonthKey visibleMonth;
  final HistoryMonthData? monthData;
  final bool isLoading;
  final bool hasLoaded;
  final String? error;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onJumpToToday;
  final VoidCallback onRetry;
  final ValueChanged<HistoryDaySummary> onTapDay;

  const _HistoryCalendarView({
    required this.visibleMonth,
    required this.monthData,
    required this.isLoading,
    required this.hasLoaded,
    required this.error,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onJumpToToday,
    required this.onRetry,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    if ((!hasLoaded || isLoading) && monthData == null) {
      return const LoadingState(
        message:
            '\u6b63\u5728\u51c6\u5907\u672c\u6708\u6d77\u62a5...',
      );
    }

    if (error != null && monthData == null) {
      return ErrorState(message: error!, onRetry: onRetry);
    }

    final firstDay = visibleMonth.firstDay;
    final leadingSlots = firstDay.weekday % 7;
    final firstGridDay = firstDay.subtract(Duration(days: leadingSlots));
    final today = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, AppTheme.spacingXLarge * 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 240) return;
          if (velocity < 0) {
            onNextMonth();
          } else {
            onPreviousMonth();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CalendarMonthHeader(
              visibleMonth: visibleMonth,
              onPreviousMonth: onPreviousMonth,
              onNextMonth: onNextMonth,
            ),
            const SizedBox(height: 14),
            Row(
              children: _weekdays
                  .map(
                    (weekday) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          weekday,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            GridView.builder(
              key: ValueKey(visibleMonth.toString()),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final date = firstGridDay.add(Duration(days: index));
                final isCurrentMonth = date.month == visibleMonth.month;
                final isToday =
                    date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final summary = isCurrentMonth
                    ? monthData?.summaryForDay(date.day)
                    : null;

                return RepaintBoundary(
                  child: _HistoryCalendarCell(
                    date: date,
                    summary: summary,
                    isCurrentMonth: isCurrentMonth,
                    isToday: isToday,
                    onTap: summary == null ? null : () => onTapDay(summary),
                  ),
                );
              },
            ),
            if ((monthData == null || monthData!.isEmpty) && !isLoading) ...[
              const SizedBox(height: AppTheme.spacingLarge),
              Center(
                child: TextButton(
                  onPressed: onJumpToToday,
                  child: const Text(
                    '\u8fd9\u4e2a\u6708\u8fd8\u6ca1\u6709\u89c2\u5f71\u8bb0\u5f55',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  final HistoryMonthKey visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _CalendarMonthHeader({
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final yearText = DateFormat('yyyy').format(visibleMonth.firstDay);
    final monthText = DateFormat('MM').format(visibleMonth.firstDay);

    return Column(
      children: [
        _MonthStepperRow(
          label: yearText,
          onPrevious: () {
            context.read<MovieProvider>().setVisibleHistoryMonth(
              HistoryMonthKey(
                year: visibleMonth.year - 1,
                month: visibleMonth.month,
              ),
            );
          },
          onNext: () {
            context.read<MovieProvider>().setVisibleHistoryMonth(
              HistoryMonthKey(
                year: visibleMonth.year + 1,
                month: visibleMonth.month,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        _MonthStepperRow(
          label: monthText,
          onPrevious: onPreviousMonth,
          onNext: onNextMonth,
          textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MonthStepperRow extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final TextStyle? textStyle;

  const _MonthStepperRow({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextStyle =
        textStyle ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        );

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: baseTextStyle,
          ),
        ),
        IconButton(
          onPressed: onNext,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded, size: 24),
        ),
      ],
    );
  }
}

class _HistoryCalendarCell extends StatelessWidget {
  final DateTime date;
  final HistoryDaySummary? summary;
  final bool isCurrentMonth;
  final bool isToday;
  final VoidCallback? onTap;

  const _HistoryCalendarCell({
    required this.date,
    required this.summary,
    required this.isCurrentMonth,
    required this.isToday,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMovie = summary != null && summary!.hasMovies;
    final textColor = isCurrentMonth
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.18);
    const cellRadius = 10.0;
    final dayTextStyle = TextStyle(
      color: hasMovie ? Colors.white : textColor,
      fontSize: hasMovie ? 18 : 17,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      shadows: hasMovie
          ? const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(cellRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cellRadius),
            border: isToday && !hasMovie
                ? Border.all(color: colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasMovie)
                ClipRRect(
                  borderRadius: BorderRadius.circular(cellRadius),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final devicePixelRatio =
                          MediaQuery.of(context).devicePixelRatio;
                      final cacheWidth =
                          (constraints.maxWidth * devicePixelRatio).round();
                      final posterUrl = summary!.primaryPoster;

                      if (posterUrl.isEmpty) {
                        return ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.movie_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.42),
                          ),
                        );
                      }

                      return CachedNetworkImage(
                        imageUrl: posterUrl,
                        httpHeaders: ApiConfig.imageHeaders,
                        fit: BoxFit.cover,
                        memCacheWidth: cacheWidth.clamp(72, 180).toInt(),
                        maxWidthDiskCache: cacheWidth.clamp(72, 180).toInt(),
                        fadeInDuration: Duration.zero,
                        placeholder: (_, _) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.movie_outlined, size: 18),
                        ),
                      );
                    },
                  ),
                ),
              if (hasMovie)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cellRadius),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.22),
                              blurRadius: 0,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.06),
                        Colors.black.withValues(alpha: 0.24),
                      ],
                    ),
                  ),
                ),
              Center(
                child: Text('${date.day}', style: dayTextStyle),
              ),
              if (summary != null && summary!.count > 1)
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDaySheet extends StatelessWidget {
  final HistoryDaySummary summary;

  const _HistoryDaySheet({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('yyyy\u5e74M\u6708d\u65e5').format(summary.date);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMedium,
            0,
            AppTheme.spacingMedium,
            AppTheme.spacingLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppTheme.spacingXSmall),
              Text(
                '\u5171 ${summary.count} \u90e8',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              Expanded(
                child: ListView.separated(
                  itemCount: summary.movies.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spacingSmall),
                  itemBuilder: (context, index) {
                    final movie = summary.movies[index];
                    return _HistoryDayMovieTile(movie: movie);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDayMovieTile extends StatelessWidget {
  final Movie movie;

  const _HistoryDayMovieTile({required this.movie});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final watchDate = movie.watchedAt ?? movie.createdAt;

    return SoftContainer(
      showShadow: false,
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/movies/detail/${movie.id}');
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: SizedBox(
                width: 52,
                height: 74,
                child: movie.poster.isEmpty
                    ? ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie_outlined, size: 20),
                      )
                    : CachedNetworkImage(
                        imageUrl: movie.poster,
                        httpHeaders: ApiConfig.imageHeaders,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        maxWidthDiskCache: 120,
                        fadeInDuration: Duration.zero,
                        placeholder: (_, _) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.movie_outlined, size: 20),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(watchDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (movie.year.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(movie.year, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchHistoryCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const _WatchHistoryCard({super.key, required this.movie, this.onTap});

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
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SoftContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: SizedBox(
                      width: 80,
                      height: 112,
                      child: movie.poster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.poster,
                              httpHeaders: ApiConfig.imageHeaders,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              maxWidthDiskCache: 160,
                              fadeInDuration: Duration.zero,
                              placeholder: (_, _) => ColoredBox(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (_, _, _) => ColoredBox(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.movie, size: 28),
                              ),
                            )
                          : ColoredBox(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                    alpha: isDark ? 0.18 : 0.10,
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
                              DateFormat(
                                'yyyy\u5e74M\u6708d\u65e5',
                              ).format(watchDate),
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
                        if (movie.userRating != null && movie.userRating! > 0)
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                final starValue = (index + 1).toDouble();
                                return Icon(
                                  movie.userRating! >= starValue
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 18,
                                  color: movie.userRating! >= starValue
                                      ? Colors.amber
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.2,
                                        ),
                                );
                              }),
                              const SizedBox(width: 6),
                              Text(
                                '\u6211\u7684\u8bc4\u5206',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (movie.userReview != null &&
                            movie.userReview!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              '“${movie.userReview!}”',
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
                          ),
                        ] else
                          const Spacer(),
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
