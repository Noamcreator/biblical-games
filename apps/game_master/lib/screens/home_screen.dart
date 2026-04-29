import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:game_master/core/theme_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _controller = PageController(viewportFraction: 0.72);
  double currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        currentPage = _controller.page ?? 0;
      });
    });
  }

  // Fonction utilitaire pour extraire les nuances sans crash (Material vs Accent)
  Color _getShade(Color color, {bool darker = false}) {
    if (color is MaterialColor) {
      return darker ? color[700]! : color[400]!;
    } else if (color is MaterialAccentColor) {
      return darker ? color[400]! : color[100]!;
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final games = GameType.values;

    // On écoute les changements globaux
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, accentColorNotifier]),
      builder: (context, _) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final accentColor = accentColorNotifier.value;

        // On génère nos nuances dynamiquement
        final primaryColor = _getShade(accentColor, darker: true);
        final secondaryColor = _getShade(accentColor, darker: false);

        return Scaffold(
          body: Stack(
            children: [
              // --- FOND DÉGRADÉ DYNAMIQUE ---
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [primaryColor, secondaryColor.withOpacity(0.8)],
                  ),
                ),
              ),

              // Cercles décoratifs
              Positioned(
                bottom: -50,
                right: -50,
                child: CircleAvatar(
                  radius: 150,
                  backgroundColor: Colors.white.withOpacity(isDark ? 0.03 : 0.08),
                ),
              ),

              // Barre d'outils
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.language_rounded, color: Colors.white70),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 100),
                  Text(
                    "Choisis ton jeu",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Prêt pour l'aventure ?",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        final diff = (currentPage - index);
                        final scale = (1 - (diff.abs() * 0.2)).clamp(0.8, 1.0);
                        final opacity = (1 - (diff.abs() * 0.5)).clamp(0.4, 1.0);

                        return Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: _GameCarouselCard(
                              game: game,
                              // On passe la couleur d'accent pour que la carte s'adapte aussi
                              primaryColor: accentColor,
                              isDarkMode: isDark,
                              onTap: () => context.push('/create', extra: game),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GameCarouselCard extends StatelessWidget {
  final GameType game;
  final Color primaryColor;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _GameCarouselCard({
    required this.game,
    required this.primaryColor,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.2),
              blurRadius: 25,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                // La carte devient sombre ou claire selon le thème
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: Colors.white.withOpacity(isDarkMode ? 0.1 : 0.4),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -20,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: primaryColor.withOpacity(0.1),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            game.emoji,
                            style: const TextStyle(fontSize: 74),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          game.label.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            // Le texte de la carte utilise la couleur d'accent
                            color: isDarkMode ? Colors.white : primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          child: const Text(
                            "JOUER",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}