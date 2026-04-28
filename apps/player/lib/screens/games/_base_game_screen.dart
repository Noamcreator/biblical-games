import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

/// Écran de base partagé par tous les jeux côté joueur.
/// Gère le stream Firestore, le timer, et la navigation finale.
class BaseGameScreen extends StatelessWidget {
  final String sessionCode;
  final String gameTitle;
  final Widget Function(Map<String, dynamic> data) questionBuilder;

  const BaseGameScreen({
    super.key,
    required this.sessionCode,
    required this.gameTitle,
    required this.questionBuilder,
  });

  @override
  Widget build(BuildContext context) {
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

        if (session.isFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/$sessionCode');
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(gameTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Q ${session.currentQuestionIndex + 1} / ${session.totalQuestions}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: session.isReviewing
                ? _ReviewBanner(session: session)
                : session.currentQuestionData == null
                ? const Center(child: Text('En attente de la question…'))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: questionBuilder(session.currentQuestionData!),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  final Session session;
  const _ReviewBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_empty, size: 48),
          const SizedBox(height: 12),
          Text(
            'Le Game Master corrige…',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Prochaine question dans un instant !'),
        ],
      ),
    );
  }
}