import 'dart:async';

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
import 'package:random_movie/widgets/movie/selectable_movie_grid.dart';

class RoomDetailPage extends StatefulWidget {
  final String roomCode;
  const RoomDetailPage({super.key, required this.roomCode});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  static const int _pageSize = 48;
  final StorageService _storageService = StorageService();
  final ScrollController _hostScrollController = ScrollController();
  final TextEditingController _luckyController = TextEditingController();
  final Set<String> _selectedIds = {};
  final Map<String, Movie> _movieCache = {};
  List<Movie> _hostMovies = [];
  List<Movie> _animCandidates = [];
  Timer? _shuffleTimer;
  Timer? _countdownTimer;
  Timer? _syncTimer;
  DrawResultData? _animResult;
  String? _previousStatus;
  int _displayIndex = 0;
  int _shuffleCount = 0;
  int _countdown = 5;
  int _hostPage = 0;
  int _hostTotal = 0;
  bool _hostLoading = true;
  bool _hostLoadingMore = false;
  bool _hasMoreHost = true;
  bool _selectionSynced = false;
  bool _luckySubmitted = false;
  bool _animationStarted = false;
  bool _animationComplete = false;
  bool _historySaved = false;
  bool _autoPopping = false;

  @override
  void initState() {
    super.initState();
    _hostScrollController.addListener(_handleHostScroll);
    _loadInitialHostMovies();
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
    _hostScrollController.dispose();
    _luckyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, _) {
        final room = roomProvider.currentRoom;
        if (room == null) return _buildDisconnected(roomProvider);
        _handleTransition(room, roomProvider);
        final canLeave = room.isWaiting || room.isCompleted;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && canLeave) _showLeaveDialog(roomProvider);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                room.isCollecting
                    ? '输入幸运数字'
                    : room.isDrawing
                    ? '抽奖中...'
                    : room.isCompleted
                    ? '抽奖结果'
                    : '房间 ${room.code}',
              ),
              leading: canLeave
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _showLeaveDialog(roomProvider),
                    )
                  : const SizedBox.shrink(),
              automaticallyImplyLeading: false,
            ),
            body: room.isWaiting
                ? _buildWaiting(room, roomProvider)
                : room.isCollecting
                ? _buildCollecting(room)
                : room.isDrawing || (_animationStarted && !_animationComplete)
                ? _buildDrawing(room)
                : _buildCompleted(room, roomProvider),
          ),
        );
      },
    );
  }

  Widget _buildDisconnected(RoomProvider roomProvider) {
    if (roomProvider.error != null && !_autoPopping) {
      _autoPopping = true;
      final reason = roomProvider.error!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppToast.error(context, reason, duration: const Duration(seconds: 3));
        context.pop();
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('房间')),
      body: _autoPopping
          ? const LoadingState(message: '正在返回...')
          : ErrorState(message: '房间连接已断开', onRetry: () => context.pop()),
    );
  }

  void _handleTransition(Room room, RoomProvider roomProvider) {
    if (!_selectionSynced && room.selectedMovieIds.isNotEmpty) {
      _selectedIds
        ..clear()
        ..addAll(room.selectedMovieIds);
      _cacheRoomMovies(room.moviesById);
      _selectionSynced = true;
    }
    if (room.isCollecting && _previousStatus != 'collecting') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
    }
    if (room.isDrawing && !_animationStarted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startDrawAnimation(room, roomProvider.drawStartData),
      );
    }
    if (room.isWaiting &&
        _previousStatus != null &&
        _previousStatus != 'waiting') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetState());
    }
    _previousStatus = room.status;
  }

  Future<void> _loadInitialHostMovies() async {
    if (!mounted) return;
    setState(() => _hostLoading = true);
    try {
      final results = await Future.wait<Object>([
        _storageService.countMovies(),
        _storageService.queryMovies(limit: _pageSize, offset: 0),
      ]);
      if (!mounted) return;
      final total = results[0] as int;
      final movies = results[1] as List<Movie>;
      setState(() {
        _hostTotal = total;
        _hostMovies = movies;
        _hostPage = 0;
        _hasMoreHost = movies.length < total;
      });
      _cacheMovies(movies);
    } finally {
      if (mounted) setState(() => _hostLoading = false);
    }
  }

  void _handleHostScroll() {
    if (!_hostScrollController.hasClients) return;
    if (_hostScrollController.position.pixels >=
        _hostScrollController.position.maxScrollExtent - 320) {
      _loadMoreHostMovies();
    }
  }

  Future<void> _loadMoreHostMovies() async {
    if (_hostLoading || _hostLoadingMore || !_hasMoreHost) return;
    setState(() => _hostLoadingMore = true);
    try {
      final nextPage = _hostPage + 1;
      final movies = await _storageService.queryMovies(
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _hostMovies = [..._hostMovies, ...movies];
        _hostPage = nextPage;
        _hasMoreHost = _hostMovies.length < _hostTotal;
      });
      _cacheMovies(movies);
    } finally {
      if (mounted) setState(() => _hostLoadingMore = false);
    }
  }

  void _cacheMovies(Iterable<Movie> movies) {
    for (final movie in movies) {
      _movieCache[movie.id] = movie;
    }
  }

  void _cacheRoomMovies(Map<String, dynamic>? moviesById) {
    if (moviesById == null) return;
    for (final entry in moviesById.entries) {
      final raw = entry.value;
      if (raw is Map<String, dynamic>) {
        try {
          final movie = Movie.fromJson(raw);
          _movieCache[movie.id] = movie;
        } catch (_) {}
      }
    }
  }

  List<Movie> _selectedMoviesFromRoom(Room room) {
    _cacheRoomMovies(room.moviesById);
    return room.selectedMovieIds
        .map((id) => _movieCache[id])
        .whereType<Movie>()
        .toList();
  }

  Future<void> _selectAll() async {
    final ids = await _storageService.queryMovieIds();
    if (!mounted) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
    _scheduleSync();
  }

  Future<void> _selectUnwatched() async {
    final ids = await _storageService.queryMovieIds(unwatchedOnly: true);
    if (!mounted) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
    _scheduleSync();
  }

  void _toggleMovie(Movie movie) {
    setState(() {
      if (_selectedIds.contains(movie.id)) {
        _selectedIds.remove(movie.id);
      } else {
        _selectedIds.add(movie.id);
      }
    });
    _movieCache[movie.id] = movie;
    _scheduleSync();
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(
      const Duration(milliseconds: 250),
      _syncSelectionToServer,
    );
  }

  Future<void> _syncSelectionToServer() async {
    final userId = context.read<UserProvider>().user?.id ?? '';
    final roomProvider = context.read<RoomProvider>();
    final missing = _selectedIds
        .where((id) => !_movieCache.containsKey(id))
        .toList();
    if (missing.isNotEmpty)
      _cacheMovies(await _storageService.getMoviesByIds(missing));
    final moviesData = <String, dynamic>{};
    for (final id in _selectedIds) {
      final movie = _movieCache[id];
      if (movie != null) moviesData[id] = movie.toJson();
    }
    roomProvider.updateRoomMovies(userId, _selectedIds.toList(), moviesData);
  }

  Widget _buildWaiting(Room room, RoomProvider roomProvider) {
    final userId = context.read<UserProvider>().user?.id ?? '';
    final isHost = room.isUserHost(userId);
    final colorScheme = Theme.of(context).colorScheme;
    final selectedMovies = isHost
        ? _selectedIds.map((id) => _movieCache[id]).whereType<Movie>().toList()
        : _selectedMoviesFromRoom(room);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.meeting_room, size: 18),
              const SizedBox(width: 8),
              Text(
                '房间号 ${room.code}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: room.code));
                  AppToast.info(context, '房间码已复制');
                },
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            key: const PageStorageKey('room-members'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: room.participants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final participant = room.participants[index];
              final initial = participant.name.isNotEmpty
                  ? participant.name.characters.first
                  : '?';
              return Chip(
                avatar: CircleAvatar(
                  child: Center(
                    child: Text(
                      initial,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                      strutStyle: const StrutStyle(
                        height: 1,
                        leading: 0,
                        forceStrutHeight: true,
                      ),
                    ),
                  ),
                ),
                label: Text(
                  participant.isHost
                      ? '${participant.name} ★'
                      : participant.name,
                ),
              );
            },
          ),
        ),
        if (selectedMovies.isNotEmpty)
          SizedBox(
            height: 128,
            child: ListView.separated(
              key: const PageStorageKey('room-selected-preview'),
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              scrollDirection: Axis.horizontal,
              itemCount: selectedMovies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = selectedMovies[index];
                return SizedBox(
                  width: 84,
                  child: Column(
                    children: [
                      Expanded(child: _poster(movie.poster, 84)),
                      const SizedBox(height: 4),
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (isHost)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
            ),
            child: Row(
              children: [
                Text(
                  '已选 ${_selectedIds.length} / 共 $_hostTotal 部',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: _selectAll, child: const Text('全选')),
                TextButton(
                  onPressed: _selectUnwatched,
                  child: const Text('仅未看'),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Text(
              selectedMovies.isEmpty
                  ? '等待房主选择电影...'
                  : '房主已选 ${selectedMovies.length} 部电影',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        Expanded(
          child: isHost
              ? _hostLoading
                    ? const LoadingState(message: '加载片库中...')
                    : _hostTotal == 0
                    ? EmptyState(
                        title: '片库是空的',
                        subtitle: '先去添加几部电影吧',
                        icon: Icons.movie_outlined,
                        onAction: () => context.go('/movies/add'),
                        actionLabel: '去添加',
                      )
                    : SelectableMovieGrid(
                        storageKey: const PageStorageKey('room-host-grid'),
                        controller: _hostScrollController,
                        movies: _hostMovies,
                        selectedIds: _selectedIds,
                        hasMore: _hasMoreHost,
                        isLoadingMore: _hostLoadingMore,
                        onToggle: _toggleMovie,
                      )
              : GridView.builder(
                  key: const PageStorageKey('room-member-grid'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMedium,
                  ),
                  cacheExtent: MediaQuery.of(context).size.height * 1.5,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.60,
                    crossAxisSpacing: AppTheme.spacingSmall,
                    mainAxisSpacing: AppTheme.spacingSmall,
                  ),
                  itemCount: selectedMovies.length,
                  itemBuilder: (context, index) =>
                      _posterStack(selectedMovies[index]),
                ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(AppTheme.spacingMedium),
          child: isHost
              ? PrimaryButton(
                  label: _selectedIds.isNotEmpty
                      ? '准备抽奖（${_selectedIds.length} 部）'
                      : '请先选择电影',
                  icon: Icons.casino,
                  onPressed: _selectedIds.isNotEmpty
                      ? () => roomProvider.startDraw(userId)
                      : null,
                )
              : Text(
                  '等待房主开始抽奖...',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _poster(String url, double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: SizedBox(
        width: width,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                httpHeaders: ApiConfig.imageHeaders,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                maxWidthDiskCache: 240,
                fadeInDuration: Duration.zero,
              )
            : const ColoredBox(
                color: Colors.black12,
                child: Center(child: Icon(Icons.movie)),
              ),
      ),
    );
  }

  Widget _posterStack(Movie movie) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Stack(
        children: [
          Positioned.fill(child: _poster(movie.poster, double.infinity)),
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
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startCountdown() {
    _countdown = 5;
    _luckySubmitted = false;
    _luckyController.clear();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          final room = context.read<RoomProvider>().currentRoom;
          final userId = context.read<UserProvider>().user?.id ?? '';
          if (room != null)
            _submitLucky(
              userId,
              DrawService.autoLuckyNumber(userId, room.code),
            );
        }
      });
    });
  }

  void _submitLucky(String userId, int number) {
    if (_luckySubmitted) return;
    context.read<RoomProvider>().submitLuckyNumber(userId, number);
    setState(() {
      _luckySubmitted = true;
      _luckyController.text = number.toString();
    });
  }

  Widget _buildCollecting(Room room) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = context.read<UserProvider>().user?.id ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        children: [
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
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXLarge),
          SoftContainer(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              children: [
                const Text(
                  '输入你的幸运数字',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                if (_luckySubmitted)
                  Text(
                    '已提交 ${_luckyController.text}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  )
                else ...[
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _luckyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '1-99',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  PrimaryButton(
                    label: '确认',
                    icon: Icons.check,
                    isFullWidth: false,
                    onPressed: () {
                      final number = int.tryParse(_luckyController.text.trim());
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
          SoftContainer(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              children: room.participants
                  .map(
                    (participant) => ListTile(
                      dense: true,
                      leading: Icon(
                        participant.luckyNumber != null
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        color: participant.luckyNumber != null
                            ? Colors.green
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      title: Text(participant.name),
                      trailing: Text(
                        participant.luckyNumber?.toString() ?? '...',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _startDrawAnimation(Room room, DrawStartData? drawStartData) {
    final candidates = <Movie>[];
    if (drawStartData != null) {
      for (final raw in drawStartData.movies) {
        if (raw is Map<String, dynamic>) {
          try {
            candidates.add(Movie.fromJson(raw));
          } catch (_) {}
        } else if (raw is String && _movieCache[raw] != null) {
          candidates.add(_movieCache[raw]!);
        }
      }
    }
    if (candidates.isEmpty) candidates.addAll(_selectedMoviesFromRoom(room));
    if (candidates.isEmpty) return;
    _animationStarted = true;
    _animationComplete = false;
    _animCandidates = candidates;
    _animResult = drawStartData == null
        ? null
        : DrawService.roomRandom(candidates, drawStartData.seed);
    _shuffleCount = 0;
    _displayIndex = 0;
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return timer.cancel();
      _shuffleCount++;
      if (_shuffleCount <= 20) {
        setState(
          () => _displayIndex = (_displayIndex + 1) % _animCandidates.length,
        );
      } else {
        timer.cancel();
        _startSlowPhase(0);
      }
    });
  }

  void _startSlowPhase(int step) {
    if (step >= 4) {
      _resolveAnimResult();
      setState(() {
        if (_animResult == null) {
          _displayIndex = 0;
        } else {
          final resultIndex = _animCandidates.indexOf(
            _animResult!.selectedMovie,
          );
          _displayIndex = resultIndex < 0 ? 0 : resultIndex;
        }
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _animationComplete = true);
        _saveHistory();
      });
      return;
    }
    Future.delayed(Duration(milliseconds: 200 + step * 100), () {
      if (!mounted) return;
      setState(
        () => _displayIndex = (_displayIndex + 1) % _animCandidates.length,
      );
      _startSlowPhase(step + 1);
    });
  }

  void _resolveAnimResult() {
    if (_animResult != null) return;
    final roomProvider = context.read<RoomProvider>();
    if (roomProvider.drawStartData != null) {
      _animResult = DrawService.roomRandom(
        _animCandidates,
        roomProvider.drawStartData!.seed,
      );
      return;
    }
    final room = roomProvider.currentRoom;
    if (room?.drawResult != null) {
      final movie = _animCandidates.firstWhere(
        (candidate) => candidate.id == room!.drawResult!.movieId,
        orElse: () => _animCandidates.first,
      );
      _animResult = DrawResultData(
        selectedMovie: movie,
        seed: room!.drawResult!.seed,
        index: _animCandidates.indexOf(movie),
      );
      return;
    }
    _animResult = DrawResultData(
      selectedMovie: _animCandidates.first,
      seed: 0,
      index: 0,
    );
  }

  void _saveHistory() {
    if (_historySaved) return;
    final room = context.read<RoomProvider>().currentRoom;
    if (room == null || room.drawResult == null) return;
    _historySaved = true;
    final poster = _movieCache[room.drawResult!.movieId]?.poster ?? '';
    final record = DrawService.buildRoomRecord(
      roomCode: room.code,
      drawResult: room.drawResult!,
      participants: room.participants,
      candidateCount: _animCandidates.isEmpty
          ? room.selectedMovieIds.length
          : _animCandidates.length,
      moviePoster: poster,
    );
    context.read<DrawHistoryProvider>().addRecord(record);
  }

  Widget _buildDrawing(Room room) {
    if (_animationComplete)
      return _buildCompleted(room, context.read<RoomProvider>());
    if (_animCandidates.isEmpty)
      return const LoadingState(message: '准备抽奖数据...');
    final movie = _animCandidates[_displayIndex % _animCandidates.length];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: DrawShuffleCard(movie: movie, shuffleCount: _shuffleCount),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          const Text(
            '抽取中...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleted(Room room, RoomProvider roomProvider) {
    Movie? movie;
    if (room.drawResult != null) movie = _movieCache[room.drawResult!.movieId];
    movie ??= _animResult?.selectedMovie;
    if (movie == null) return const LoadingState(message: '加载抽奖结果...');
    final resultMovie = movie;
    final userId = context.read<UserProvider>().user?.id ?? '';
    final isHost = room.isUserHost(userId);
    if (!_historySaved && room.drawResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveHistory());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        children: [
          const Icon(Icons.celebration, size: 48, color: AppTheme.accent),
          const SizedBox(height: AppTheme.spacingSmall),
          const Text(
            '恭喜抽中！',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          SizedBox(
            width: 200,
            height: 330,
            child: MovieCard(
              movie: resultMovie,
              showWatchedBadge: false,
              onTap: () => context.push('/movies/detail/${resultMovie.id}'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXLarge),
          SoftContainer(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: room.participants
                  .map(
                    (participant) => ListTile(
                      dense: true,
                      title: Text(
                        participant.isHost
                            ? '${participant.name} ★'
                            : participant.name,
                      ),
                      trailing: Text('${participant.luckyNumber ?? '-'}'),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (room.drawResult != null) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              'seed: ${room.drawResult!.seed}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
          const SizedBox(height: AppTheme.spacingXLarge),
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
            onPressed: () => context.push('/movies/detail/${resultMovie.id}'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(RoomProvider roomProvider) {
    final userId = context.read<UserProvider>().user?.id ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出房间'),
        content: const Text('确定要退出当前房间吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              roomProvider.leaveRoom(userId);
              context.pop();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _resetState() {
    _shuffleTimer?.cancel();
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
    _animCandidates = [];
    _animResult = null;
    _displayIndex = 0;
    _shuffleCount = 0;
    _countdown = 5;
    _animationStarted = false;
    _animationComplete = false;
    _luckySubmitted = false;
    _historySaved = false;
    _selectionSynced = false;
    _selectedIds.clear();
    _luckyController.clear();
  }
}
