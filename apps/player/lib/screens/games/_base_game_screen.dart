// ─────────────────────────────────────────────────────────────
// BASE GAME SCREEN — Redesign complet
// Design : Indigo/Bleu, mobile-first, glassmorphism
// ─────────────────────────────────────────────────────────────
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

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

    final primaryBlue   = Colors.indigo[700]!;
    final secondaryBlue = Colors.blue[600]!;
    final accentCyan    = Colors.cyan[400]!;

    return StreamBuilder<Session>(
      stream: service.watchSession(sessionCode),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorView(error: snap.error.toString());
        }
        if (!snap.hasData) {
          return _LoadingView(primary: primaryBlue);
        }

        final session = snap.data!;

        if (session.isFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/$sessionCode');
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // ── Arrière-plan dégradé ─────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [
                      primaryBlue,
                      secondaryBlue,
                      accentCyan.withOpacity(0.75),
                    ],
                  ),
                ),
              ),

              // ── Cercle déco ──────────────────────────────
              Positioned(
                top: -40, left: -40,
                child: CircleAvatar(
                  radius: 130,
                  backgroundColor: Colors.white.withOpacity(0.04),
                ),
              ),
              Positioned(
                bottom: -60, right: -60,
                child: CircleAvatar(
                  radius: 160,
                  backgroundColor: Colors.white.withOpacity(0.04),
                ),
              ),

              // ── Contenu ──────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      session:     session,
                      gameTitle:   gameTitle,
                      sessionCode: sessionCode,
                      primary:     primaryBlue,
                    ),
                    Expanded(
                      child: session.isFinished
                          ? const SizedBox()
                          : session.currentQuestionData == null
                              ? _WaitingView(primary: primaryBlue)
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                                  child: questionBuilder(session.currentQuestionData!),
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BARRE DU HAUT
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Session session;
  final String  gameTitle;
  final String  sessionCode;
  final Color   primary;

  const _TopBar({
    required this.session,
    required this.gameTitle,
    required this.sessionCode,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final progress = session.totalQuestions > 0
        ? (session.currentQuestionIndex + 1) / session.totalQuestions
        : 0.0;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.12),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.games_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gameTitle,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Bouton classement
                  _ScoreButton(session: session, sessionCode: sessionCode),
                  const SizedBox(width: 8),
                  // Compteur Q
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Question ${session.currentQuestionIndex + 1}/${session.totalQuestions}',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Barre de progression
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           progress.clamp(0, 1),
                  minHeight:       4,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor:      const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOUTON CLASSEMENT (popup)
// ─────────────────────────────────────────────────────────────

class _ScoreButton extends StatelessWidget {
  final Session session;
  final String  sessionCode;

  const _ScoreButton({required this.session, required this.sessionCode});

  void _showLeaderboard(BuildContext context) {
    final sorted = session.players.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaderboardSheet(players: sorted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLeaderboard(context),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.leaderboard_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FEUILLE CLASSEMENT
// ─────────────────────────────────────────────────────────────

class _LeaderboardSheet extends StatelessWidget {
  final List<Player> players;
  const _LeaderboardSheet({required this.players});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC107), size: 26),
            const SizedBox(width: 10),
            Text('Classement', style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w900,
              color:      Colors.indigo[800],
            )),
          ]),
          const SizedBox(height: 16),
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aucun joueur encore', style: TextStyle(color: Colors.grey[500])),
            )
          else
            ...players.asMap().entries.map((e) {
              final rank   = e.key;
              final player = e.value;
              final medals = ['🥇', '🥈', '🥉'];
              final medal  = rank < 3 ? medals[rank] : '${rank + 1}.';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        rank == 0
                      ? Colors.amber.shade50
                      : rank == 1
                          ? Colors.grey.shade50
                          : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: rank == 0
                        ? Colors.amber.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(medal, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(player.name, style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15,
                      )),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        Colors.indigo[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${player.score} pts',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ÉTATS DIVERS
// ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final Color primary;
  const _LoadingView({required this.primary});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: primary,
    body: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Erreur : $error')),
  );
}

class _WaitingView extends StatelessWidget {
  final Color primary;
  const _WaitingView({required this.primary});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withOpacity(0.15),
            child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'En attente\nde la question…',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  final Color primary;
  const _ReviewBanner({required this.primary});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.15),
            child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 16),
          const Text(
            'Le Game Master corrige…',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prochaine question dans un instant !',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}