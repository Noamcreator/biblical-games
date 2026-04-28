import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/games/fiche_perso.dart';

/// Nommage des fichiers JSON :
///   {jeu}_{langue}.json
///   ex: fiche_perso_F.json (fiche perso, Français)
///       fiche_perso_E.json (fiche perso, Anglais)
///
/// Chemin dans les assets du package core :
///   packages/core/assets/data/{fichier}

class JsonLoader {
  static final JsonLoader _instance = JsonLoader._internal();
  factory JsonLoader() => _instance;
  JsonLoader._internal();

  // Cache en mémoire
  final Map<String, dynamic> _cache = {};

  static const String _basePath = 'packages/core/assets/data';

  /// Génère le nom de fichier selon la convention
  static String fileName(String jeu, String langue) => '${jeu}_$langue.json';

  /// Charge un JSON brut (avec cache)
  Future<Map<String, dynamic>> loadJson(String jeu, String langue) async {
    final key = '${jeu}_$langue';
    if (_cache.containsKey(key)) return _cache[key] as Map<String, dynamic>;

    final path = '$_basePath/${fileName(jeu, langue)}.json';
    // Essai avec .json dans le nom si pas déjà inclus
    final correctedPath = path.endsWith('.json.json') ? path.replaceAll('.json.json', '.json') : path;

    try {
      final raw = await rootBundle.loadString(correctedPath);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _cache[key] = decoded;
      return decoded;
    } catch (e) {
      throw Exception('Impossible de charger $correctedPath : $e');
    }
  }

  /// Charge la configuration complète du jeu Fiche Perso
  Future<FichePersoGameConfig> loadFichePerso({String langue = 'F'}) async {
    final raw = await loadJson('fiche_perso', langue);
    return FichePersoGameConfig.fromJson(raw);
  }

  /// Vide le cache (utile pour forcer un rechargement)
  void clearCache() => _cache.clear();

  /// Liste les fichiers disponibles pour un jeu donné
  /// (à utiliser dans le Game Master pour proposer les langues)
  static const Map<String, List<String>> availableFiles = {
    'fiche_perso': ['F'],   // F = Français. Ajouter 'E' pour anglais, etc.
    'vrai_faux':   ['F'],
    'frise':       ['F'],
    'devine_verset': ['F'],
    'jeu_map':     ['F'],
    'redaction':   ['F'],
  };
}