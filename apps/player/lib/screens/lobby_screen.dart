import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class LobbyScreen extends ConsumerWidget {
  final String sessionCode;
  const LobbyScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryBlue = Colors.indigo[700]!;
    final secondaryBlue = Colors.blue[600]!;
    final accentBlue = Colors.cyan[400]!;
    final service = SessionService();

    return StreamBuilder<Session>(
      stream: service.watchSession(sessionCode),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Erreur : ${snap.error}', style: const TextStyle(color: Colors.white))),
            backgroundColor: primaryBlue,
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            body: const Center(child: CircularProgressIndicator(color: Colors.white)),
            backgroundColor: primaryBlue,
          );
        }

        final session = snap.data!;

        // Navigation automatique
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
          body: Stack(
            children: [
              // Fond dégradé
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryBlue, secondaryBlue, accentBlue.withOpacity(0.8)],
                  ),
                ),
              ),

              // Cercles décoratifs
              Positioned(
                bottom: -40,
                left: -40,
                child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withOpacity(0.05)),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Header personnalisé (remplace l'AppBar)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                            onPressed: () => context.go('/'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'SALLE : ${session.code}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 450),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 32),
                                    
                                    // Info du jeu
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(session.gameType.emoji, style: const TextStyle(fontSize: 40)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      session.gameType.label,
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryBlue),
                                    ),
                                    const SizedBox(height: 24),

                                    // Status
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'En attente du Game Master…',
                                      style: TextStyle(color: Colors.blueGrey[400], fontWeight: FontWeight.w500),
                                    ),
                                    
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Divider(indent: 40, endIndent: 40),
                                    ),

                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Row(
                                        children: [
                                          Icon(Icons.people_outline, size: 20, color: primaryBlue),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${session.players.length} joueur(s) en ligne',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Liste des joueurs
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        children: session.players.values.map((player) {
                                          return _buildPlayerTile(player, primaryBlue);
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildPlayerTile(Player player, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: primaryColor, size: 20),
        ),
        title: Text(
          player.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: player.isReady
            ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: Colors.orange[300], shape: BoxShape.circle),
              ),
      ),
    );
  }

  String _routeForGame(GameType type, String code) {
    switch (type) {
      case GameType.fichePerso: return '/game/fiche-perso/$code';
      case GameType.vraiFaux: return '/game/vrai-faux/$code';
      case GameType.friseChronologique: return '/game/frise/$code';
      case GameType.devineVerset: return '/game/devine-verset/$code';
      case GameType.map: return '/game/map/$code';
      case GameType.redactionBible: return '/game/redaction/$code';
    }
  }
}