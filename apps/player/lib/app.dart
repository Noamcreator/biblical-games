import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/join_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/results_screen.dart';
import 'screens/games/fiche_perso_screen.dart';
import 'screens/games/vrai_faux_screen.dart';
import 'screens/games/frise_screen.dart';
import 'screens/games/devine_verset_screen.dart';
import 'screens/games/map_screen.dart';
import 'screens/games/redaction_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const JoinScreen(),
    ),
    // URL directe avec code : /join/RUTH-42
    GoRoute(
      path: '/join/:code',
      builder: (context, state) =>
          JoinScreen(prefilledCode: state.pathParameters['code']),
    ),
    GoRoute(
      path: '/lobby/:code',
      builder: (context, state) =>
          LobbyScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/game/fiche-perso/:code',
      builder: (context, state) =>
          FichePersoScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/game/vrai-faux/:code',
      builder: (context, state) =>
          VraiFauxScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/game/frise/:code',
      builder: (context, state) =>
          FriseScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/game/devine-verset/:code',
      builder: (context, state) =>
          DevineVersetScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/game/map/:code',
      builder: (context, state) =>
          MapScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/game/redaction/:code',
      builder: (context, state) =>
          RedactionScreen(sessionCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/results/:code',
      builder: (context, state) =>
          ResultsScreen(sessionCode: state.pathParameters['code']!),
    ),
  ],
);

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jeux Bibliques',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      routerConfig: _router,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5C4033), // brun parchemin
        brightness: brightness,
      ),
      fontFamily: 'Georgia',
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF2C1A0E) : const Color(0xFF8B6347),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}