import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/pages/history/history_page.dart';
import 'package:random_movie/pages/movies/add_movie_page.dart';
import 'package:random_movie/pages/movies/movie_detail_page.dart';
import 'package:random_movie/pages/movies/movies_page.dart';
import 'package:random_movie/pages/room/draw_history_page.dart';
import 'package:random_movie/pages/room/room_detail_page.dart';
import 'package:random_movie/pages/room/room_hub_page.dart';
import 'package:random_movie/pages/room/solo_draw_page.dart';
import 'package:random_movie/providers/movie_provider.dart';
import 'package:random_movie/providers/user_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _moviesNavigatorKey = GlobalKey<NavigatorState>();
final _roomNavigatorKey = GlobalKey<NavigatorState>();
final _historyNavigatorKey = GlobalKey<NavigatorState>();

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final Set<int> _primedBranches = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _primeCurrentBranch();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _primeCurrentBranch();
    }
  }

  void _primeCurrentBranch() {
    final index = widget.navigationShell.currentIndex;
    if (_primedBranches.contains(index)) return;
    _primedBranches.add(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index == 0) {
        context.read<MovieProvider>().ensureLibraryLoaded();
      } else if (index == 1) {
        context.read<UserProvider>().ensureInitialized();
      } else if (index == 2) {
        context.read<MovieProvider>().ensureHistoryLoaded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _primeCurrentBranch();
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: (index) {
                        if (index == widget.navigationShell.currentIndex) return;
                        widget.navigationShell.goBranch(index);
                      },
                      selectedItemColor: colorScheme.primary,
                      unselectedItemColor: colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                      showUnselectedLabels: true,
                      type: BottomNavigationBarType.fixed,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.movie_outlined),
                          activeIcon: Icon(Icons.movie),
                          label: '片库',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.meeting_room_outlined),
                          activeIcon: Icon(Icons.meeting_room),
                          label: '房间',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.visibility_outlined),
                          activeIcon: Icon(Icons.visibility),
                          label: '观影',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/movies',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _moviesNavigatorKey,
          routes: [
            GoRoute(
              path: '/movies',
              builder: (context, state) => const MoviesPage(),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const AddMoviePage(),
                ),
                GoRoute(
                  path: 'detail/:movieId',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final movieId = state.pathParameters['movieId']!;
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      transitionDuration: const Duration(milliseconds: 160),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 120,
                      ),
                      child: MovieDetailPage(movieId: movieId),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            final fade = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                              reverseCurve: Curves.easeInCubic,
                            );
                            return FadeTransition(opacity: fade, child: child);
                          },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _roomNavigatorKey,
          routes: [
            GoRoute(
              path: '/room',
              builder: (context, state) => const RoomHubPage(),
              routes: [
                GoRoute(
                  path: 'solo-draw',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SoloDrawPage(),
                ),
                GoRoute(
                  path: 'draw-history',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const DrawHistoryPage(),
                ),
                GoRoute(
                  path: 'detail/:code',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final code = state.pathParameters['code']!;
                    return RoomDetailPage(roomCode: code);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _historyNavigatorKey,
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
