import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class ResultsScreen extends StatelessWidget {
  final String sessionCode;
  const ResultsScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Classement final')),
      body: FutureBuilder<List<Player>>(
        future: SessionService().getFinalScores(sessionCode),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snap.data!;
          return Column(
            children: [
              const SizedBox(height: 24),
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                'Partie terminée !',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, i) {
                    final p = players[i];
                    final medal = i == 0
                        ? '🥇'
                        : i == 1
                        ? '🥈'
                        : i == 2
                        ? '🥉'
                        : '${i + 1}.';
                    return ListTile(
                      leading: Text(medal,
                          style: const TextStyle(fontSize: 24)),
                      title: Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      trailing: Text('${p.score} pts',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary)),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Nouvelle partie'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}