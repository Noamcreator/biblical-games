import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

final PageController _controller = PageController(
  viewportFraction: 0.7,
);

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

  @override
  Widget build(BuildContext context) {
    final games = GameType.values;

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 80),

          Text(
            "Choisis ton jeu",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
                final scale = (1 - (diff.abs() * 0.25)).clamp(0.75, 1.0);
                final opacity = (1 - (diff.abs() * 0.6)).clamp(0.3, 1.0);

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: _GameCarouselCard(
                      game: game,
                      onTap: () => context.push('/create', extra: game),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _GameCarouselCard extends StatelessWidget {
  final GameType game;
  final VoidCallback onTap;

  const _GameCarouselCard({
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 🔥 Glow background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    radius: 1,
                  ),
                ),
              ),
            ),

            // 🎮 Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    game.emoji,
                    style: const TextStyle(fontSize: 70),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    game.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}