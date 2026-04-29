import 'package:flutter/material.dart';
import 'package:game_master/core/theme_manager.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/create_session_screen.dart';
import 'screens/control_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const GameMasterApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/create',
      builder: (_, __) => const CreateSessionScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/control/:code',
      builder: (context, state) =>
          ControlScreen(sessionCode: state.pathParameters['code']!),
    ),
  ],
);

class GameMasterApp extends StatelessWidget {
  const GameMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder écoute les deux Notifiers et reconstruit l'app quand ils changent
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, accentColorNotifier]),
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Game Master — Jeux Bibliques',
          debugShowCheckedModeBanner: false,
          
          // Thème Dynamique
          themeMode: themeNotifier.value,
          
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentColorNotifier.value,
              brightness: Brightness.light,
            ),
          ),
          
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentColorNotifier.value,
              brightness: Brightness.dark,
            ),
            // On peut forcer le fond sombre pour ton look "Slate/Nuit"
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          
          routerConfig: _router,
        );
      },
    );
  }
}