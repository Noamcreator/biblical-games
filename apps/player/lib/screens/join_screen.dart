import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart'; 

class JoinScreen extends ConsumerStatefulWidget {
  final String? prefilledCode;
  const JoinScreen({super.key, this.prefilledCode});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null) {
      _codeController.text = widget.prefilledCode!.toUpperCase();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final service = SessionService();
      await service.joinSession(code: code, playerName: name);
      if (mounted) context.go('/lobby/$code');
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Palette de couleurs plus harmonieuse (Bleu/Indigo)
    final primaryBlue = Colors.indigo[700]!;
    final secondaryBlue = Colors.blue[600]!;
    final accentBlue = Colors.cyan[400]!;

    return Scaffold(
      body: Stack(
        children: [
          // Arrière-plan dégradé plus sobre
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
          
          // Cercles décoratifs (plus subtils)
          Positioned(
            top: -30,
            left: -30,
            child: CircleAvatar(radius: 120, backgroundColor: Colors.white.withOpacity(0.05)),
          ),

          // Boutons Paramètres et Langue en haut
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
                      onPressed: () {
                        // Action pour la langue
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                      onPressed: () {
                        // Action pour les paramètres
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icone stylisée
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.games_rounded, size: 42, color: primaryBlue),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Jeux Bibliques',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rejoins une salle',
                          style: TextStyle(color: Colors.blueGrey[400], fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 32),

                        _buildTextField(
                          controller: _codeController,
                          label: 'Code de la salle',
                          icon: Icons.qr_code_scanner_rounded,
                          isUppercase: true,
                          activeColor: primaryBlue,
                        ),
                        const SizedBox(height: 20),

                        _buildTextField(
                          controller: _nameController,
                          label: 'Ton pseudo',
                          icon: Icons.person_outline_rounded,
                          activeColor: primaryBlue,
                        ),
                        
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Bouton principal
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _join,
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                  )
                                : const Text(
                                    'REJOINDRE', 
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color activeColor,
    bool isUppercase = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[700])),
        ),
        TextField(
          controller: controller,
          textCapitalization: isUppercase ? TextCapitalization.characters : TextCapitalization.words,
          style: TextStyle(color: activeColor, fontSize: 14, fontWeight: FontWeight.bold),
          onChanged: isUppercase ? (v) {
            controller.value = controller.value.copyWith(
              text: v.toUpperCase(),
              selection: TextSelection.collapsed(offset: v.length),
            );
          } : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            labelStyle: const TextStyle(fontSize: 14, color: Colors.deepPurple),
            prefixIcon: Icon(icon, size: 22),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: activeColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}