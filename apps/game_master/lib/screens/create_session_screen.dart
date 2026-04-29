import 'package:flutter/material.dart';
import 'package:game_master/core/theme_manager.dart';
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
  int _roundDuration = 60;
  bool _sameCardForAll = true;
  bool _isCreating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    _selectedType = (extra is GameType) ? extra : GameType.fichePerso;
  }

  Future<void> _create() async {
    setState(() => _isCreating = true);
    try {
      final service = SessionService();
      final session = await service.createSession(
        gameType: _selectedType,
        totalQuestions: _totalQuestions,
        roundTimeSeconds: _roundDuration,
        sameCardForAll: _sameCardForAll,
      );

      if (mounted) context.go('/control/${session.code}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // Utilitaire pour les nuances de couleurs (identique à ton HomeScreen)
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
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, accentColorNotifier]),
      builder: (context, _) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final accentColor = accentColorNotifier.value;

        // Définition des couleurs selon le thème actuel
        final primaryColor = accentColor;
        final bgColor = isDark ? const Color(0xFF0F172A) : Colors.grey[50];
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BackButton(color: textColor.withOpacity(0.8)),
            title: Text(
              'Configuration',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER JEU ---
                _buildGameHero(primaryColor, isDark),

                const SizedBox(height: 32),

                // --- REGLAGES ---
                _buildLabel("Paramètres de la partie", isDark),
                const SizedBox(height: 16),

                _buildCustomCard(
                  cardColor,
                  isDark,
                  child: Column(
                    children: [
                      _buildModernSlider(
                        label: "Manches",
                        value: _totalQuestions.toDouble(),
                        min: 1,
                        max: 20,
                        activeColor: primaryColor,
                        isDark: isDark,
                        onChanged: (v) => setState(() => _totalQuestions = v.round()),
                      ),
                      if (_selectedType == GameType.fichePerso) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(
                            color: isDark ? Colors.white10 : Colors.black12,
                            height: 1,
                          ),
                        ),
                        _buildModernSlider(
                          label: "Temps",
                          value: _roundDuration.toDouble(),
                          min: 15,
                          max: 180,
                          suffix: "s",
                          activeColor: Colors.orangeAccent,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _roundDuration = v.round()),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (_selectedType == GameType.fichePerso) ...[
                  _buildLabel("Distribution", isDark),
                  const SizedBox(height: 16),
                  _buildCustomCard(
                    cardColor,
                    isDark,
                    child: Column(
                      children: [
                        _buildSelectionTile(
                          "Même carte pour tous",
                          true,
                          primaryColor,
                          isDark,
                        ),
                        Divider(
                          color: isDark ? Colors.white10 : Colors.black12,
                          height: 1,
                        ),
                        _buildSelectionTile(
                          "Cartes individuelles",
                          false,
                          primaryColor,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                // --- BOUTON FINAL ---
                _buildGradientButton(primaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGETS DE STYLE ---

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildGameHero(Color accent, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.8), accent.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Text(_selectedType.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedType.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Mode de jeu sélectionné",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCustomCard(Color color, bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: child,
    );
  }

  Widget _buildModernSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required bool isDark,
    String suffix = "",
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 16,
              ),
            ),
            Text(
              "${value.round()}$suffix",
              style: TextStyle(
                color: activeColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: activeColor,
            inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
            thumbColor: isDark ? Colors.white : activeColor,
            overlayColor: activeColor.withOpacity(0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildSelectionTile(String title, bool value, Color activeColor, bool isDark) {
    final isSelected = _sameCardForAll == value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return InkWell(
      onTap: () => setState(() => _sameCardForAll = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? activeColor : (isDark ? Colors.white24 : Colors.black26),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? textColor : textColor.withOpacity(0.5),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientButton(Color accent) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [accent, _getShade(accent, darker: true)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isCreating ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isCreating
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "DÉMARRER LA SESSION",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
      ),
    );
  }
}