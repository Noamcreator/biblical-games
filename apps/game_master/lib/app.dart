import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/create_session_screen.dart';
import 'screens/control_screen.dart';

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
    return MaterialApp.router(
      title: 'Game Master — Jeux Bibliques',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _router,
    );
  }
}