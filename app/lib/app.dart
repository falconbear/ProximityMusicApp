// Application root + router configuration.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/presentation/pages/dashboard_page.dart';
import 'package:proximity_music_app/presentation/pages/discover_page.dart';
import 'package:proximity_music_app/presentation/pages/player_page.dart';

class ProximityMusicApp extends StatelessWidget {
  const ProximityMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/player',
          builder: (context, state) => const PlayerPage(),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const DiscoverPage(),
        ),
        // '/settings' route — placeholder so the route exists on this
        // branch even before Issue #2 (onboarding + permissions) is
        // merged. When Issue #2 lands, the real SettingsPage will
        // replace this builder. Kept inline (no new file) to avoid
        // colliding with Issue #2's app/lib/presentation/pages/
        // settings_page.dart.
        GoRoute(
          path: '/settings',
          builder: (context, state) => const _SettingsPlaceholder(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Proximity Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          secondary: Color(0xFF1DB954),
          surface: Color(0xFF181818),
          onPrimary: Colors.black,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF181818),
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text(
          'Settings will arrive with Issue #2.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
