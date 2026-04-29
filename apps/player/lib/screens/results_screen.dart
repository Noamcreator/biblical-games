import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class ResultsScreen extends StatelessWidget {
  final String sessionCode;
  const ResultsScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    // Palette identique à JoinScreen
    final primaryBlue = Colors.indigo[700]!;
    final secondaryBlue = Colors.blue[600]!;
    final accentBlue = Colors.cyan[400]!;

    return Scaffold(
      body: Stack(
        children: [
          // Arrière-plan dégradé
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue,
                  secondaryBlue,
                  accentBlue.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Cercles décoratifs
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: Colors.white.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: FutureBuilder<List<Player>>(
              future: SessionService().getFinalScores(sessionCode),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Erreur : ${snap.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final players = snap.data!;

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 500),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 32),
                              // En-tête trophée
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('🏆', style: TextStyle(fontSize: 48)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Classement Final',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Partie terminée !',
                                style: TextStyle(
                                  color: Colors.blueGrey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Liste des joueurs
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: players.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: Colors.grey[200],
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                  itemBuilder: (context, i) {
                                    final p = players[i];
                                    return _buildPlayerTile(i, p, primaryBlue);
                                  },
                                ),
                              ),

                              // Bouton retour
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: FilledButton(
                                    onPressed: () => context.go('/'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: primaryBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text(
                                      'NOUVELLE PARTIE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(int index, Player player, Color primaryColor) {
    final medal = index == 0
        ? '🥇'
        : index == 1
            ? '🥈'
            : index == 2
                ? '🥉'
                : '${index + 1}.';

    return ListTile(
      leading: Container(
        width: 45,
        alignment: Alignment.center,
        child: Text(
          medal,
          style: TextStyle(
            fontSize: index < 3 ? 28 : 16,
            fontWeight: index < 3 ? FontWeight.normal : FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      ),
      title: Text(
        player.name,
        style: TextStyle(
          fontWeight: index == 0 ? FontWeight.w900 : FontWeight.bold,
          color: index == 0 ? primaryColor : Colors.black87,
          fontSize: 16,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: index == 0 ? primaryColor.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${player.score} pts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: index == 0 ? primaryColor : Colors.blueGrey[700],
          ),
        ),
      ),
    );
  }
}