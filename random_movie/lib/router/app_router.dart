import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:random_movie/pages/history/history_page.dart';
import 'package:random_movie/pages/movies/movies_page.dart';
import 'package:random_movie/pages/movies/add_movie_page.dart';
import 'package:random_movie/pages/movies/movie_detail_page.dart';
import 'package:random_movie/pages/room/room_hub_page.dart';
import 'package:random_movie/pages/room/solo_draw_page.dart';
import 'package:random_movie/pages/room/draw_history_page.dart';
import 'package:random_movie/pages/room/room_detail_page.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

// Root navigator key — routes using this key bypass the ShellRoute (no bottom nav)
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Pages will be created later
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      // No bottomNavigationBar — we overlay it via Stack
      body: Stack(
        children: [
          // Page content fills entire screen
          child,

          // Floating glass nav bar
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 8,
            child: GlassContainer(
              blurSigma: 24,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.zero,
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
                    currentIndex: _getCurrentIndex(context),
                    onTap: (index) => _onTap(index, context),
                    selectedItemColor: colorScheme.primary,
                    unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.55),
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
        ],
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/movies')) return 0;
    if (location.startsWith('/room')) return 1;
    if (location.startsWith('/history')) return 2;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/movies');
        break;
      case 1:
        context.go('/room');
        break;
      case 2:
        context.go('/history');
        break;
    }
  }
}

// Router configuration
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/movies',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
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
              builder: (context, state) {
                final movieId = state.pathParameters['movieId']!;
                return MovieDetailPage(movieId: movieId);
              },
            ),
          ],
        ),
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
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
        ),
      ],
    ),
  ],
);
