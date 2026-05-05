// Application root + router configuration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/presentation/pages/dashboard_page.dart';
import 'package:proximity_music_app/presentation/pages/onboarding/consent_page.dart';
import 'package:proximity_music_app/presentation/pages/onboarding/permissions_page.dart';
import 'package:proximity_music_app/presentation/pages/onboarding/privacy_battery_page.dart';
import 'package:proximity_music_app/presentation/pages/onboarding/welcome_page.dart';
import 'package:proximity_music_app/presentation/pages/player_page.dart';
import 'package:proximity_music_app/presentation/pages/session_page.dart';
import 'package:proximity_music_app/presentation/pages/settings_page.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';

class ProximityMusicApp extends ConsumerWidget {
  const ProximityMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final onboarding = ref.read(onboardingStateProvider);
        final service = ref.read(onboardingServiceProvider);
        // Reconsent only fires *after* a previous consent was recorded; a
        // pristine `consent == null` user is in first-run onboarding and
        // should reach the Welcome page instead. We therefore delegate to
        // OnboardingService.needsReconsent only when consent != null.
        final consent = onboarding.consent;
        final reconsent = consent != null &&
            service.needsReconsent(currentTermsVersion);

        // Stuck redirect: in reconsent mode every path resolves to
        // /onboarding/consent.
        if (reconsent) {
          if (state.matchedLocation == '/onboarding/consent') {
            return null;
          }
          return '/onboarding/consent';
        }

        // First-run / partial onboarding -> Welcome.
        if (onboarding.status != OnboardingStatus.completed) {
          if (state.matchedLocation.startsWith('/onboarding/')) {
            return null;
          }
          return '/onboarding/welcome';
        }

        return null;
      },
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
          path: '/session',
          builder: (context, state) => const SessionPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/onboarding/welcome',
          builder: (context, state) => const WelcomePage(),
        ),
        GoRoute(
          path: '/onboarding/privacy-battery',
          builder: (context, state) => const PrivacyBatteryPage(),
        ),
        GoRoute(
          path: '/onboarding/permissions',
          builder: (context, state) => const PermissionsPage(),
        ),
        GoRoute(
          path: '/onboarding/consent',
          builder: (context, state) => const ConsentPage(),
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
