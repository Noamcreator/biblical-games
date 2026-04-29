import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_master/core/theme_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:core/core.dart';

class ControlScreen extends StatelessWidget {
  final String sessionCode;
  const ControlScreen({super.key, required this.sessionCode});

  static const String baseUrl = 'https://noamcreator.github.io/biblical-games';
  String get joinUrl => '$baseUrl/#/join/$sessionCode';

  @override
  Widget build(BuildContext context) {
    final service = SessionService();

    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, accentColorNotifier]),
      builder: (context, _) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final accentColor = accentColorNotifier.value;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

        return StreamBuilder<Session>(
          stream: service.watchSession(sessionCode),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Scaffold(
                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final session = snap.data!;

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  '${session.gameType.emoji} Salle : $sessionCode',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.stop_circle_outlined, color: isDark ? Colors.redAccent[100] : Colors.red),
                    tooltip: 'Terminer la partie',
                    onPressed: () => _confirmEndGame(context, service),
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            color: cardColor,
                            elevation: isDark ? 0 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text('REJOINDRE',
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                      )),
                                  const SizedBox(height: 12),
                                  // QR Code s'adapte au thème pour être lisible
                                  QrImageView(
                                    data: joinUrl,
                                    size: 160,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildCodeChip(context, isDark, accentColor),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        _buildPlayerHeader(context, session, textColor),
                        
                        Expanded(
                          child: _buildPlayerList(session, isDark, textColor, accentColor),
                        )
                      ],
                    ),
                  ),

                  VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.black12),

                  // ── Panneau droite : contrôles ────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusBadge(state: session.state),
                          const SizedBox(height: 32),
                          
                          Text(
                            "Progression de la partie",
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              minHeight: 12,
                              backgroundColor: isDark ? Colors.white10 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              value: session.totalQuestions > 0
                                  ? (session.currentQuestionIndex + 1) / session.totalQuestions
                                  : 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Question ${session.currentQuestionIndex + 1} sur ${session.totalQuestions}',
                            style: TextStyle(color: textColor.withOpacity(0.6)),
                          ),

                          const Spacer(),

                          // Boutons d'action dynamiques
                          _buildActionArea(session, service, accentColor),
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
      },
    );
  }

  // --- WIDGETS HELPER ---

  Widget _buildCodeChip(BuildContext context, bool isDark, Color accentColor) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: sessionCode));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code copié dans le presse-papier !'), behavior: SnackBarBehavior.floating),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sessionCode,
              style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy, size: 18, color: accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader(BuildContext context, Session session, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 20, color: textColor.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            '${session.players.length} Joueurs',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList(Session session, bool isDark, Color textColor, Color accentColor) {
    final players = session.players.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final p = players[index];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: accentColor.withOpacity(0.2),
            child: Icon(Icons.person, size: 16, color: accentColor),
          ),
          title: Text(p.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
          trailing: Text(
            '${p.score} pts',
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildActionArea(Session session, SessionService service, Color accentColor) {
    if (session.isWaiting) {
      return _ActionButton(
        label: 'LANCER LA PARTIE',
        icon: Icons.play_arrow_rounded,
        color: Colors.green,
        onTap: () => service.startGame(sessionCode),
      );
    }

    if (session.isPlaying) {
      return _ActionButton(
        label: 'PASSER EN CORRECTION',
        icon: Icons.fact_check_rounded,
        color: Colors.orange,
        onTap: () => service.showReview(sessionCode),
      );
    }

    if (session.isReviewing) {
      final isLast = session.currentQuestionIndex >= session.totalQuestions - 1;
      return _ActionButton(
        label: isLast ? 'VOIR LE CLASSEMENT' : 'QUESTION SUIVANTE',
        icon: isLast ? Icons.emoji_events_rounded : Icons.skip_next_rounded,
        color: accentColor,
        onTap: () async {
          if (!isLast) {
            await service.drawNextPersonnage(sessionCode);
          } else {
            await service.endGame(sessionCode);
          }
        },
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _confirmEndGame(BuildContext context, SessionService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terminer la partie ?'),
        content: const Text('Cette action est irréversible et déconnectera tous les joueurs.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('TERMINER'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.endGame(sessionCode);
      if (context.mounted) context.go('/');
    }
  }
}

// --- SOUS-WIDGETS STYLISÉS ---

class _StatusBadge extends StatelessWidget {
  final SessionState state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SessionState.waiting => ('EN ATTENTE', Colors.orange),
      SessionState.playing => ('EN JEU', Colors.green),
      SessionState.reviewing => ('CORRECTION', Colors.blue),
      SessionState.finished => ('TERMINÉ', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}