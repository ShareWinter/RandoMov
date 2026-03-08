import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/providers/providers.dart';
import 'package:random_movie/services/services.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';
import 'package:random_movie/widgets/movie/draw_shuffle_card.dart';
import 'package:random_movie/widgets/movie/movie_card.dart';

/// Room detail page — four phases driven by room.status
class RoomDetailPage extends StatefulWidget {
  final String roomCode;
  const RoomDetailPage({super.key, required this.roomCode});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  // Draw animation state (reuses SoloDrawPage pattern)
  Timer? _shuffleTimer;
  int _displayIndex = 0;
  int _shuffleCount = 0;
  bool _animationStarted = false;
  bool _animationComplete = false;
  List<Movie> _animCandidates = [];
  DrawResultData? _animResult;

  // Movie selection
  final Set<String> _selectedMovieIds = {};
  bool _selectionSynced = false;

  // Lucky number
  final TextEditingController _luckyNumberController = TextEditingController();
  bool _luckyNumberSubmitted = false;
  int _countdown = 5;
  Timer? _countdownTimer;

  // History save guard (prevent duplicate saves)
  bool _historySaved = false;

  // Auto-pop guard (prevent re-entry)
  bool _isAutoPopping = false;

  // Track previous status to detect phase transitions
  String? _previousStatus;

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _countdownTimer?.cancel();
    _luckyNumberController.dispose();
    super.dispose();
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, _) {
        final room = roomProvider.currentRoom;

        // Room closed or left
        if (room == null) {
          // Only auto-pop when server explicitly reported an error
          // (room-closed / kicked events set roomProvider.error).
          // Do NOT auto-pop during initial load or manual leave.
          if (roomProvider.error != null && !_isAutoPopping) {
            _isAutoPopping = true;
            final reason = roomProvider.error!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              AppToast.error(
                context,
                reason,
                duration: const Duration(seconds: 3),
              );
              context.pop();
            });
          }

          // Already auto-popping — show transition state
          if (_isAutoPopping) {
            return Scaffold(
              appBar: AppBar(title: const Text('房间')),
              body: const LoadingState(message: '正在返回...'),
            );
          }

          // Fallback: no error but room is null (edge case / loading)
          return Scaffold(
            appBar: AppBar(title: const Text('房间')),
            body: ErrorState(message: '房间连接已断开', onRetry: () => context.pop()),
          );
        }

        // Detect phase transitions
        _handlePhaseTransition(room, roomProvider);

        final canLeave = room.isWaiting || room.isCompleted;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (canLeave) {
              _showLeaveConfirmDialog(context, roomProvider);
            }
            // Collecting / Drawing: do nothing, block back
          },
          child: Scaffold(
            appBar: _buildAppBar(context, room),
            body: _buildBody(context, room, roomProvider),
          ),
        );
      },
    );
  }

  void _handlePhaseTransition(Room room, RoomProvider roomProvider) {
    final prevStatus = _previousStatus;
    _previousStatus = room.status; // Update synchronously

    // Defer setState-triggering operations to avoid calling during build
    if (room.isCollecting && prevStatus != 'collecting') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown();
      });
    }

    if (room.isDrawing && !_animationStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startDrawAnimation(room, roomProvider.drawStartData);
      });
    }

    if (room.isWaiting && prevStatus != null && prevStatus != 'waiting') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetState();
      });
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Room room) {
    final canLeave = room.isWaiting || room.isCompleted;

    String title;
    if (room.isCollecting) {
      title = '输入幸运数字';
    } else if (room.isDrawing) {
      title = '抽奖中...';
    } else if (room.isCompleted) {
      title = '抽奖结果';
    } else {
      title = '房间 ${room.code}';
    }

    return AppBar(
      title: Text(title),
      leading: canLeave
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _showLeaveConfirmDialog(
                context,
                context.read<RoomProvider>(),
              ),
            )
          : const SizedBox.shrink(),
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildBody(
    BuildContext context,
    Room room,
    RoomProvider roomProvider,
  ) {
    if (room.isWaiting) return _buildWaitingPhase(context, room, roomProvider);
    if (room.isCollecting)
      return _buildCollectingPhase(context, room, roomProvider);
    // Keep showing animation until it completes, even if server already moved to completed
    if (room.isDrawing || (_animationStarted && !_animationComplete)) {
      return _buildDrawingPhase(context, room);
    }
    if (room.isCompleted)
      return _buildCompletedPhase(context, room, roomProvider);
    return const LoadingState(message: '加载中...');
  }

  // ==================== Dialogs ====================

  void _showLeaveConfirmDialog(
    BuildContext context,
    RoomProvider roomProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = context.read<UserProvider>().user?.id ?? '';

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
              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
              width: 1,
            ),
          ),
          title: Text(
            '退出房间',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
            ),
          ),
          content: Text(
            '确定要退出当前房间吗？',
            style: TextStyle(
              color: isDark
                  ? AppTheme.textSecondary
                  : AppTheme.textSecondaryDarkOnLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
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
                Navigator.of(ctx).pop();
                roomProvider.leaveRoom(userId);
                context.pop();
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
              child: const Text(
                '退出',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Phase 1: Waiting ====================

  Widget _buildWaitingPhase(
    BuildContext context,
    Room room,
    RoomProvider roomProvider,
  ) {
    final userId = context.read<UserProvider>().user?.id ?? '';
    final isHost = room.isUserHost(userId);

    if (isHost) {
      return _buildHostWaitingView(context, room, roomProvider, userId);
    } else {
      return _buildMemberWaitingView(context, room, userId);
    }
  }

  /// Host view: select movies from local library
  Widget _buildHostWaitingView(
    BuildContext context,
    Room room,
    RoomProvider roomProvider,
    String userId,
  ) {
    final movieProvider = context.read<MovieProvider>();
    final allMovies = movieProvider.allMovies;
    final candidateCount = _selectedMovieIds.length;

    // Sync initial selection from server state
    if (!_selectionSynced) {
      if (room.selectedMovieIds.isNotEmpty) {
        _selectedMovieIds.addAll(room.selectedMovieIds);
      }
      _selectionSynced = true;
    }

    return Column(
      children: [
        // Room code (compact bar)
        _buildRoomCodeBar(context, room),

        // Participants list
        _buildParticipantsList(context, room),

        // Host's selected movies preview
        _buildHostSelectedPreview(context, room),

        // Selection toolbar (count + 全选/仅未看)
        _buildSelectionToolbar(context, allMovies),

        // Movie grid
        Expanded(
          child: allMovies.isEmpty
              ? EmptyState(
                  title: '片库是空的',
                  subtitle: '先去添加几部影片吧',
                  icon: Icons.movie_outlined,
                  onAction: () => context.go('/movies/add'),
                  actionLabel: '去添加',
                )
              : _buildMovieGrid(context, allMovies, userId, roomProvider),
        ),

        // Bottom button
        SafeArea(
          minimum: const EdgeInsets.all(AppTheme.spacingMedium),
          child: PrimaryButton(
            label: candidateCount > 0 ? '准备抽奖（$candidateCount 部候选）' : '请先选择影片',
            icon: Icons.casino,
            onPressed: candidateCount > 0
                ? () => roomProvider.startDraw(userId)
                : null,
          ),
        ),
      ],
    );
  }

  /// Member view: read-only candidate pool
  Widget _buildMemberWaitingView(
    BuildContext context,
    Room room,
    String userId,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Room code (compact bar)
        _buildRoomCodeBar(context, room),

        // Participants list
        _buildParticipantsList(context, room),

        // Main content: candidate pool (large, prominent)
        Expanded(child: _buildMemberCandidatePool(context, room)),

        // Bottom: waiting text
        SafeArea(
          minimum: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Text(
            '等待房主开始抽奖...',
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomCodeBar(BuildContext context, Room room) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
        AppTheme.spacingMedium,
        AppTheme.spacingXSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppTheme.spacingXSmall),
          Text(
            '房间号:',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Text(
            room.code,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: AppTheme.spacingXSmall),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              AppToast.info(context, '房间码已复制');
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.copy,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(BuildContext context, Room room) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: room.participants.length,
          separatorBuilder: (_, __) =>
              const SizedBox(width: AppTheme.spacingMedium),
          itemBuilder: (context, index) {
            final p = room.participants[index];
            final initial = p.name.isNotEmpty ? p.name.characters.first : '?';

            return SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.isHost
                              ? AppTheme.accent.withValues(
                                  alpha: isDark ? 0.25 : 0.15,
                                )
                              : colorScheme.onSurface.withValues(
                                  alpha: isDark ? 0.12 : 0.08,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: p.isHost
                              ? Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.5),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: p.isHost
                                  ? AppTheme.accent
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      // Host badge
                      if (p.isHost)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Name
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: p.isHost
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Host: horizontal preview of currently selected movies
  Widget _buildHostSelectedPreview(BuildContext context, Room room) {
    if (_selectedMovieIds.isEmpty || room.moviesById == null)
      return const SizedBox.shrink();

    final candidates = <Movie>[];
    for (final id in _selectedMovieIds) {
      final json = room.moviesById![id];
      if (json is Map<String, dynamic>) {
        try {
          candidates.add(Movie.fromJson(json));
        } catch (_) {}
      }
    }
    if (candidates.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
        AppTheme.spacingMedium,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_movies,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: AppTheme.spacingXSmall),
              Text(
                '已选影片 (${candidates.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXSmall),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: candidates.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppTheme.spacingSmall),
              itemBuilder: (context, index) {
                final movie = candidates[index];
                return SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                          child: movie.poster.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: movie.poster,
                                  httpHeaders: ApiConfig.imageHeaders,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.movie, size: 24),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Member: large candidate pool showing host's selections (read-only)
  Widget _buildMemberCandidatePool(BuildContext context, Room room) {
    final colorScheme = Theme.of(context).colorScheme;

    if (room.selectedMovieIds.isEmpty || room.moviesById == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              '等待房主选择影片...',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final candidates = <Movie>[];
    for (final id in room.selectedMovieIds) {
      final json = room.moviesById![id];
      if (json is Map<String, dynamic>) {
        try {
          candidates.add(Movie.fromJson(json));
        } catch (_) {}
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacingSmall),
          Row(
            children: [
              Icon(
                Icons.local_movies,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: AppTheme.spacingXSmall),
              Text(
                '房主已选 ${candidates.length} 部影片',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.60,
                crossAxisSpacing: AppTheme.spacingSmall,
                mainAxisSpacing: AppTheme.spacingSmall,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final movie = candidates[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 0.65,
                        child: movie.poster.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: movie.poster,
                                httpHeaders: ApiConfig.imageHeaders,
                                fit: BoxFit.cover,
                              )
                            : Container(
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
                      // Title at bottom
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar(BuildContext context, List<Movie> allMovies) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSelected =
        allMovies.isNotEmpty &&
        allMovies.every((m) => _selectedMovieIds.contains(m.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingXSmall,
        AppTheme.spacingMedium,
        AppTheme.spacingXSmall,
      ),
      child: Row(
        children: [
          Text(
            '已选 ${_selectedMovieIds.length} / 共 ${allMovies.length} 部',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedMovieIds.clear();
                } else {
                  _selectedMovieIds.clear();
                  _selectedMovieIds.addAll(allMovies.map((m) => m.id));
                }
              });
              _syncSelectionToServer(allMovies);
            },
            child: Text(allSelected ? '反全选' : '全选'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedMovieIds.clear();
                final unwatched = allMovies.where((m) => !m.watched);
                _selectedMovieIds.addAll(unwatched.map((m) => m.id));
              });
              _syncSelectionToServer(allMovies);
            },
            child: const Text('仅未看'),
          ),
        ],
      ),
    );
  }

  void _syncSelectionToServer(List<Movie> allMovies) {
    final userId = context.read<UserProvider>().user?.id ?? '';
    final roomProvider = context.read<RoomProvider>();
    final moviesData = <String, dynamic>{};
    for (final id in _selectedMovieIds) {
      final m = allMovies.firstWhere(
        (m) => m.id == id,
        orElse: () => allMovies.first,
      );
      moviesData[id] = m.toJson();
    }
    roomProvider.updateRoomMovies(
      userId,
      _selectedMovieIds.toList(),
      moviesData,
    );
  }

  Widget _buildMovieGrid(
    BuildContext context,
    List<Movie> allMovies,
    String userId,
    RoomProvider roomProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: AppTheme.spacingSmall,
        mainAxisSpacing: AppTheme.spacingSmall,
      ),
      itemCount: allMovies.length,
      itemBuilder: (context, index) {
        final movie = allMovies[index];
        final selected = _selectedMovieIds.contains(movie.id);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedMovieIds.remove(movie.id);
              } else {
                _selectedMovieIds.add(movie.id);
              }
            });
            // Sync single toggle to server
            final moviesData = <String, dynamic>{};
            for (final id in _selectedMovieIds) {
              final m = allMovies.firstWhere(
                (m) => m.id == id,
                orElse: () => movie,
              );
              moviesData[id] = m.toJson();
            }
            roomProvider.updateRoomMovies(
              userId,
              _selectedMovieIds.toList(),
              moviesData,
            );
          },
          child: AnimatedOpacity(
            opacity: selected ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                Container(
                  decoration: selected
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          border: Border.all(color: AppTheme.accent, width: 2),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppTheme.radiusLarge - 1,
                    ),
                    child: AspectRatio(
                      aspectRatio: 0.65,
                      child: movie.poster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.poster,
                              httpHeaders: ApiConfig.imageHeaders,
                              fit: BoxFit.cover,
                            )
                          : Container(
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
                // Checkbox overlay
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppTheme.accent
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                // Title at bottom
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
      },
    );
  }

  // ==================== Phase 2: Collecting ====================

  void _startCountdown() {
    _countdown = 5;
    _luckyNumberSubmitted = false;
    _luckyNumberController.clear();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          _autoSubmitLuckyNumber();
        }
      });
    });
  }

  void _autoSubmitLuckyNumber() {
    if (_luckyNumberSubmitted) return;
    final userId = context.read<UserProvider>().user?.id ?? '';
    final room = context.read<RoomProvider>().currentRoom;
    if (room == null) return;
    final autoNumber = DrawService.autoLuckyNumber(userId, room.code);
    _submitLucky(userId, autoNumber);
  }

  void _submitLucky(String userId, int number) {
    if (_luckyNumberSubmitted) return;
    setState(() => _luckyNumberSubmitted = true);
    context.read<RoomProvider>().submitLuckyNumber(userId, number);
  }

  Widget _buildCollectingPhase(
    BuildContext context,
    Room room,
    RoomProvider roomProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = context.read<UserProvider>().user?.id ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingXLarge),

          // Countdown display
          Text(
            '$_countdown',
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.w900,
              color: _countdown <= 2 ? AppTheme.accent : colorScheme.onSurface,
            ),
          ),
          Text(
            '秒后自动分配',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: AppTheme.spacingXLarge),

          // Lucky number input
          GlassContainer(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              children: [
                Text(
                  '输入你的幸运数字',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                if (_luckyNumberSubmitted)
                  Text(
                    '已提交: ${_luckyNumberController.text.isNotEmpty ? _luckyNumberController.text : "自动分配"}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  )
                else ...[
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _luckyNumberController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: '1-99',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 2,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  PrimaryButton(
                    label: '确认',
                    icon: Icons.check,
                    isFullWidth: false,
                    onPressed: () {
                      final text = _luckyNumberController.text.trim();
                      if (text.isEmpty) return;
                      final number = int.tryParse(text);
                      if (number == null || number < 1 || number > 99) {
                        AppToast.error(context, '请输入 1-99 之间的数字');
                        return;
                      }
                      _submitLucky(userId, number);
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingLarge),

          // Participant status list
          GlassContainer(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '参与者状态',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                ...room.participants.map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          p.luckyNumber != null
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          size: 18,
                          color: p.luckyNumber != null
                              ? Colors.green
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: AppTheme.spacingSmall),
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          p.luckyNumber != null ? '${p.luckyNumber}' : '...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: p.luckyNumber != null
                                ? AppTheme.accent
                                : colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            '倒计时结束将自动分配随机数字',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Phase 3: Drawing ====================

  void _startDrawAnimation(Room room, DrawStartData? drawStartData) {
    // Build candidates from multiple sources (robust fallback chain)
    List<Movie> candidates = [];

    // Source 1: drawStartData.movies (preferred, has server seed)
    if (drawStartData != null && drawStartData.movies.isNotEmpty) {
      for (final movieData in drawStartData.movies) {
        try {
          if (movieData is Map<String, dynamic>) {
            candidates.add(Movie.fromJson(movieData));
          } else if (movieData is String && room.moviesById != null) {
            final json = room.moviesById![movieData];
            if (json is Map<String, dynamic>) {
              candidates.add(Movie.fromJson(json));
            }
          }
        } catch (_) {
          // Skip unparseable entries
        }
      }
    }

    // Source 2: room.moviesById + selectedMovieIds (fallback)
    if (candidates.isEmpty && room.moviesById != null) {
      for (final id in room.selectedMovieIds) {
        try {
          final json = room.moviesById![id];
          if (json is Map<String, dynamic>) {
            candidates.add(Movie.fromJson(json));
          }
        } catch (_) {}
      }
      // Last resort: all movies in moviesById
      if (candidates.isEmpty) {
        for (final entry in room.moviesById!.entries) {
          try {
            if (entry.value is Map<String, dynamic>) {
              candidates.add(
                Movie.fromJson(entry.value as Map<String, dynamic>),
              );
            }
          } catch (_) {}
        }
      }
    }

    // If still no candidates, don't mark as started — will retry on next rebuild
    if (candidates.isEmpty) return;

    _animationStarted = true;
    _animationComplete = false;
    _animCandidates = candidates;

    // Calculate result if server seed is available
    if (drawStartData != null) {
      _animResult = DrawService.roomRandom(_animCandidates, drawStartData.seed);
    }
    // If no seed yet, _animResult stays null — resolved in _startSlowPhase

    // Start shuffle animation (same pattern as SoloDrawPage)
    _shuffleCount = 0;
    _displayIndex = 0;

    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _shuffleCount++;
      if (_shuffleCount <= 20) {
        setState(() {
          _displayIndex = (_displayIndex + 1) % _animCandidates.length;
        });
      } else {
        timer.cancel();
        _startSlowPhase(0);
      }
    });
  }

  void _startSlowPhase(int step) {
    const int slowSteps = 4;
    if (step >= slowSteps) {
      // Resolve result if not yet determined (drawStartData arrived late or absent)
      _resolveAnimResult();

      // Final: land on result
      setState(() {
        if (_animResult != null) {
          _displayIndex = _animCandidates.indexOf(_animResult!.selectedMovie);
          if (_displayIndex == -1) _displayIndex = 0;
        }
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _animationComplete = true);
        _saveHistory();
      });
      return;
    }

    final delay = Duration(milliseconds: 200 + step * 100);
    Future.delayed(delay, () {
      if (!mounted) return;
      setState(() {
        _displayIndex = (_displayIndex + 1) % _animCandidates.length;
      });
      _startSlowPhase(step + 1);
    });
  }

  /// Resolve _animResult from available data sources (drawStartData or drawResult)
  void _resolveAnimResult() {
    if (_animResult != null) return;

    final roomProvider = context.read<RoomProvider>();

    // Try 1: drawStartData arrived late — use its seed
    if (roomProvider.drawStartData != null) {
      _animResult = DrawService.roomRandom(
        _animCandidates,
        roomProvider.drawStartData!.seed,
      );
      return;
    }

    // Try 2: draw-result already arrived — use drawResult
    final room = roomProvider.currentRoom;
    if (room?.drawResult != null) {
      final resultMovie = _animCandidates.firstWhere(
        (m) => m.id == room!.drawResult!.movieId,
        orElse: () => _animCandidates.first,
      );
      _animResult = DrawResultData(
        selectedMovie: resultMovie,
        seed: room!.drawResult!.seed,
        index: _animCandidates.indexOf(resultMovie),
      );
      return;
    }

    // Last resort: pick first candidate (should rarely happen)
    _animResult = DrawResultData(
      selectedMovie: _animCandidates.first,
      seed: 0,
      index: 0,
    );
  }

  void _saveHistory() {
    if (_historySaved) return;
    _historySaved = true;

    final room = context.read<RoomProvider>().currentRoom;
    if (room == null || room.drawResult == null) return;

    final record = DrawService.buildRoomRecord(
      roomCode: room.code,
      drawResult: room.drawResult!,
      participants: room.participants,
      candidateCount: _animCandidates.isNotEmpty
          ? _animCandidates.length
          : room.selectedMovieIds.length,
      moviePoster: room.moviesById?[room.drawResult!.movieId]?['poster'] ?? '',
    );
    context.read<DrawHistoryProvider>().addRecord(record);
  }

  Widget _buildDrawingPhase(BuildContext context, Room room) {
    // If animation is complete, show completed phase directly
    if (_animationComplete) {
      return _buildCompletedPhase(context, room, context.read<RoomProvider>());
    }

    if (_animCandidates.isEmpty) {
      return const LoadingState(message: '准备抽奖数据...');
    }

    final currentMovie =
        _animCandidates[_displayIndex % _animCandidates.length];
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: DrawShuffleCard(
              movie: currentMovie,
              shuffleCount: _shuffleCount,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          Text(
            '抽取中...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Phase 4: Completed ====================

  Widget _buildCompletedPhase(
    BuildContext context,
    Room room,
    RoomProvider roomProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = context.read<UserProvider>().user?.id ?? '';
    final isHost = room.isUserHost(userId);

    // Get result movie
    Movie? resultMovie;
    if (room.drawResult != null && room.moviesById != null) {
      final movieJson = room.moviesById![room.drawResult!.movieId];
      if (movieJson is Map<String, dynamic>) {
        resultMovie = Movie.fromJson(movieJson);
      }
    }
    // Fallback: use animation result
    resultMovie ??= _animResult?.selectedMovie;

    if (resultMovie == null) {
      return const LoadingState(message: '加载抽奖结果...');
    }

    // Ensure history is saved (deferred to avoid setState during build)
    if (!_historySaved && room.drawResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveHistory();
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.spacingMedium,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingSmall),
          Icon(Icons.celebration, size: 48, color: AppTheme.accent),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            '恭喜抽中！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),

          // Result movie card
          SizedBox(
            width: 200,
            height: 330,
            child: MovieCard(
              movie: resultMovie,
              showWatchedBadge: false,
              onTap: () => context.push('/movies/detail/${resultMovie!.id}'),
            ),
          ),

          const SizedBox(height: AppTheme.spacingXLarge),

          // Participant lucky numbers table
          GlassContainer(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全员幸运数字',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                // Table header
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '名称',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '幸运数字',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppTheme.spacingMedium),
                // Table rows
                ...room.participants.map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              if (p.isHost)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${p.luckyNumber ?? '-'}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Seed info
          if (room.drawResult != null) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              'seed: ${room.drawResult!.seed}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacingXLarge),

          // Action buttons
          if (isHost)
            PrimaryButton(
              label: '再来一次',
              icon: Icons.casino,
              onPressed: () => roomProvider.resetRoom(userId),
            ),
          const SizedBox(height: AppTheme.spacingMedium),
          PrimaryButton(
            label: '就看这个，退出房间',
            icon: Icons.exit_to_app,
            onPressed: () {
              roomProvider.leaveRoom(userId);
              context.pop();
            },
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          SecondaryButton(
            label: '查看详情',
            icon: Icons.info_outline,
            onPressed: () => context.push('/movies/detail/${resultMovie!.id}'),
          ),
          const SizedBox(height: AppTheme.spacingXLarge),
        ],
      ),
    );
  }

  // ==================== Helpers ====================

  void _resetState() {
    _shuffleTimer?.cancel();
    _countdownTimer?.cancel();
    _animationStarted = false;
    _animationComplete = false;
    _animCandidates = [];
    _animResult = null;
    _shuffleCount = 0;
    _displayIndex = 0;
    _luckyNumberSubmitted = false;
    _luckyNumberController.clear();
    _countdown = 5;
    _historySaved = false;
    _isAutoPopping = false;
    _selectedMovieIds.clear();
    _selectionSynced = false;
  }
}
