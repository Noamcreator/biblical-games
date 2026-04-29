import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:game_master/core/theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = themeNotifier.value == ThemeMode.dark;
  Color _selectedThemeColor = accentColorNotifier.value;

  final List<Map<String, dynamic>> _themeColors = [
    {'name': 'Indigo', 'color': Colors.indigo},
    {'name': 'Violet', 'color': Colors.deepPurple},
    {'name': 'Orange', 'color': Colors.orange},
    {'name': 'Rouge', 'color': Colors.redAccent},
    {'name': 'Vert', 'color': Colors.teal},
  ];

  @override
  Widget build(BuildContext context) {
    // On adapte la palette en fonction de la couleur sélectionnée
    // Si la nuance 700 n'existe pas, on utilise la couleur de base
    // Récupère la nuance 700 si c'est une MaterialColor, sinon garde la couleur de base
    final primaryColor = (_selectedThemeColor is MaterialColor)
        ? (_selectedThemeColor as MaterialColor)[700]!
        : _selectedThemeColor;

    // Récupère la nuance 400 ou l'équivalent Accent, sinon garde la couleur de base
    final secondaryColor = (_selectedThemeColor is MaterialColor)
        ? (_selectedThemeColor as MaterialColor)[400]!
        : (_selectedThemeColor is MaterialAccentColor)
            ? (_selectedThemeColor as MaterialAccentColor)[400]! // Les Accents ont aussi un index 400
            : _selectedThemeColor;

    return Scaffold(
      body: Stack(
        children: [
          // Fond dégradé dynamique basé sur le thème
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode 
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
                  : [primaryColor.withOpacity(0.8), secondaryColor.withOpacity(0.6)],
              ),
            ),
          ),

          // Cercles décoratifs
          Positioned(
            top: -100,
            left: -100,
            child: CircleAvatar(
              radius: 200, 
              backgroundColor: Colors.white.withOpacity(_isDarkMode ? 0.03 : 0.1)
            ),
          ),

          CustomScrollView(
            slivers: [
              // AppBar stylisée
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                expandedHeight: 120,
                flexibleSpace: const FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    "PARAMÈTRES",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel("APPARENCE"),
                      const SizedBox(height: 16),
                      
                      // Carte Thème Sombre/Clair
                      _buildGlassCard(
                        child: SwitchListTile(
                          secondary: Icon(
                            _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: _isDarkMode ? Colors.amber[300] : Colors.white,
                          ),
                          title: const Text(
                            "Mode Sombre",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _isDarkMode ? "Activé" : "Désactivé",
                            style: TextStyle(color: Colors.white.withOpacity(0.6)),
                          ),
                          value: _isDarkMode,
                          activeColor: _selectedThemeColor,
                          onChanged: (val) {
                            setState(() => _isDarkMode = val);
                            themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                          }
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildSectionLabel("COULEUR D'ACCENT"),
                      const SizedBox(height: 16),

                      // Carte Sélection de couleur
                      _buildGlassCard(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                scrollDirection: Axis.horizontal,
                                itemCount: _themeColors.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 20),
                                itemBuilder: (context, index) {
                                  final item = _themeColors[index];
                                  final isSelected = _selectedThemeColor == item['color'];
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedThemeColor = item['color']);
                                      accentColorNotifier.value = item['color'];
                                    },
                                    child: Column(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? Colors.white : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 22,
                                            backgroundColor: item['color'],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['name'],
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white60,
                                            fontSize: 10,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildSectionLabel("À PROPOS"),
                      const SizedBox(height: 16),
                      
                      _buildGlassCard(
                        child: Column(
                          children: [
                            _buildSimpleTile(Icons.info_outline, "Version de l'application", "1.0.0"),
                            const Divider(color: Colors.white10),
                            _buildSimpleTile(Icons.security_rounded, "Politique de confidentialité", null),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- COMPOSANTS UI ---

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_isDarkMode ? 0.05 : 0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSimpleTile(IconData icon, String title, String? trailing) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: trailing != null 
        ? Text(trailing, style: const TextStyle(color: Colors.white38)) 
        : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
    );
  }
}