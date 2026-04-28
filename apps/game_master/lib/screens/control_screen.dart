import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:core/core.dart';

class ControlScreen extends StatelessWidget {
  final String sessionCode;
  const ControlScreen({super.key, required this.sessionCode});

  // URL de ton GitHub Pages à personnaliser
  static const String baseUrl = 'https://noamcreator.github.io/biblical-games';

  String get joinUrl => '$baseUrl/join/$sessionCode';

  @override
  Widget build(BuildContext context) {
    final service = SessionService();
    return StreamBuilder<Session>(
      stream: service.watchSession(sessionCode),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final session = snap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('${session.gameType.emoji} Salle : $sessionCode'),
            actions: [
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Terminer la partie',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Terminer la partie ?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Terminer')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await service.endGame(sessionCode);
                    if (context.mounted) context.go('/');
                  }
                },
              ),
            ],
          ),
          body: Row(
            children: [
              // ── Panneau gauche : QR + joueurs ─────────────────
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    // QR code
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text('Rejoindre',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              const SizedBox(height: 8),
                              QrImageView(
                                data: joinUrl,
                                size: 180,
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: sessionCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Code copié !')),
                                  );
                                },
                                child: Chip(
                                  label: Text(
                                    sessionCode,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2),
                                  ),
                                  avatar: const Icon(Icons.copy, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Liste joueurs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${session.players.length} joueur(s)',
                            style:
                            Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: (session.players.values.toList()
                          ..sort((a, b) => b.score.compareTo(a.score)))
                          .map((p) => ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                    radius: 14, 
                                    child: Icon(Icons.person, size: 14)),
                                title: Text(p.name),
                                trailing: Text(
                                  '${p.score} pts',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ))
                          .toList(),
                      ),
                    )
                  ],
                ),
              ),

              const VerticalDivider(width: 1),

              // ── Panneau droite : contrôles ────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // État
                      _StatusBadge(state: session.state),
                      const SizedBox(height: 16),

                      // Progression
                      LinearProgressIndicator(
                        value: session.totalQuestions > 0
                            ? session.currentQuestionIndex /
                            session.totalQuestions
                            : 0,
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Question ${session.currentQuestionIndex + 1} / ${session.totalQuestions}'),

                      const Spacer(),

                      // Boutons d'action
                      if (session.isWaiting)
                        _ActionButton(
                          label: 'Lancer la partie',
                          icon: Icons.play_arrow,
                          color: Colors.green,
                          onTap: () => service.startGame(sessionCode),
                        ),

                      if (session.isPlaying)
                        _ActionButton(
                          label: 'Passer en correction',
                          icon: Icons.check_circle_outline,
                          color: Colors.orange,
                          onTap: () => service.showReview(sessionCode),
                        ),

                      if (session.isReviewing) ...[
                        _ActionButton(
                          label: session.currentQuestionIndex <
                              session.totalQuestions - 1
                              ? 'Question suivante'
                              : 'Voir le classement',
                          icon: Icons.navigate_next,
                          color: Colors.blue,
                          onTap: () async {
                            if (session.currentQuestionIndex <
                                session.totalQuestions - 1) {
                              await service.drawNextPersonnage(sessionCode);
                            } else {
                              await service.endGame(sessionCode);
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SessionState state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SessionState.waiting => ('⏳ En attente', Colors.orange),
      SessionState.playing => ('▶ En jeu', Colors.green),
      SessionState.reviewing => ('📝 Correction', Colors.blue),
      SessionState.finished => ('🏁 Terminé', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 38),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}