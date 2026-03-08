import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/providers/providers.dart';
import 'package:random_movie/router/app_router.dart';

/// 应用主组件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => MovieProvider()),
        ChangeNotifierProvider(create: (_) => DrawHistoryProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
      ],
      child: MaterialApp.router(
        title: '随影',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          final overlay = brightness == Brightness.dark
              ? AppTheme.overlayStyleLight
              : AppTheme.overlayStyleDark;
          final navColor = brightness == Brightness.dark
              ? AppTheme.backgroundDarker
              : AppTheme.backgroundLight;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: navColor,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
