import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class LobbyScreen extends ConsumerWidget {
  final String sessionCode;
  const LobbyScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = SessionService();
    return StreamBuilder<Session>(
      stream: service.watchSession(sessionCode),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Erreur : ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snap.data!;

        // Navigation automatique quand le jeu démarre
        if (session.isPlaying) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final route = _routeForGame(session.gameType, sessionCode);
            context.go(route);
          });
        }
        if (session.isFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/$sessionCode');
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Salle ${session.code}'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  label: Text(session.gameType.label),
                  avatar: Text(session.gameType.emoji),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                'En attente du Game Master…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              Text(
                '${session.players.length} joueur(s) connecté(s)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: session.players.values.map((player) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(player.name),
                      subtitle: Text('Score : ${player.score}'),
                      trailing: player.isReady
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _routeForGame(GameType type, String code) {
    switch (type) {
      case GameType.fichePerso:
        return '/game/fiche-perso/$code';
      case GameType.vraiFaux:
        return '/game/vrai-faux/$code';
      case GameType.friseChronologique:
        return '/game/frise/$code';
      case GameType.devineVerset:
        return '/game/devine-verset/$code';
      case GameType.map:
        return '/game/map/$code';
      case GameType.redactionBible:
        return '/game/redaction/$code';
    }
  }
}