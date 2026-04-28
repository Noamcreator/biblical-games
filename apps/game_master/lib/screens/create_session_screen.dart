import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  late GameType _selectedType;
  int _totalQuestions = 5;
  bool _isCreating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final extra = GoRouterState.of(context).extra;

    if (extra is GameType) {
      _selectedType = extra;
    } else {
      _selectedType = GameType.fichePerso; // fallback sécurité
    }
  }

  Future<void> _create() async {
    setState(() => _isCreating = true);
    try {
      final service = SessionService();
      final session = await service.createSession(
        gameType: _selectedType,
        totalQuestions: _totalQuestions,
      );

      if (mounted) {
        context.go('/control/${session.code}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle partie'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎮 Jeu sélectionné (affichage propre)
            Text(
              'Jeu sélectionné',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Text(
                    _selectedType.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedType.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 🔢 Nombre de questions
            Text(
              'Nombre de questions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _totalQuestions.toDouble(),
                    min: 3,
                    max: 20,
                    divisions: 17,
                    label: '$_totalQuestions',
                    onChanged: (v) =>
                        setState(() => _totalQuestions = v.round()),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$_totalQuestions',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 🚀 Bouton lancer
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isCreating ? null : _create,
                icon: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isCreating
                      ? 'Création…'
                      : 'Créer la salle et démarrer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}