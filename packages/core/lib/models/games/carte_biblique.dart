import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────
// MODÈLE LIEU
// ─────────────────────────────────────────────────────────────

class MapLieu extends Equatable {
  final String nom;
  final double latitude;
  final double longitude;
  final String description;

  const MapLieu({
    required this.nom,
    required this.latitude,
    required this.longitude,
    this.description = '',
  });

  /// Désérialisation depuis le JSON source (assets)
  factory MapLieu.fromJson(Map<String, dynamic> json) {
    return MapLieu(
      nom:         json['lieu_correct'] as String,
      latitude:    (json['lat'] as num).toDouble(),
      longitude:   (json['lng'] as num).toDouble(),
      description: json['description'] as String? ?? '',
    );
  }

  /// Désérialisation depuis les données stockées en session Firestore
  factory MapLieu.fromMap(Map<String, dynamic> map) {
    return MapLieu(
      nom:         map['nom'] as String,
      latitude:    (map['latitude'] as num).toDouble(),
      longitude:   (map['longitude'] as num).toDouble(),
      description: map['description'] as String? ?? '',
    );
  }

  /// Sérialisation vers Firestore
  Map<String, dynamic> toMap() => {
    'nom':         nom,
    'latitude':    latitude,
    'longitude':   longitude,
    'description': description,
  };

  @override
  List<Object?> get props => [nom, latitude, longitude];
}

// ─────────────────────────────────────────────────────────────
// MODÈLE QUESTION (Carte Biblique)
// ─────────────────────────────────────────────────────────────

class MapQuestion extends Equatable {
  final int id;
  final String question;
  final MapLieu lieu;
  final String difficulte;
  final double rayonToleranceKm;
  final int pointsMax;

  const MapQuestion({
    required this.id,
    required this.question,
    required this.lieu,
    required this.difficulte,
    this.rayonToleranceKm = 50.0,
    this.pointsMax = 100,
  });

  /// Désérialisation depuis le JSON source (assets)
  factory MapQuestion.fromJson(
    Map<String, dynamic> json,
    List<String> difficultyLevels,
  ) {
    // Le JSON utilise 'evenement' comme texte de la question
    // et 'difficulte' comme string directement (pas un index)
    return MapQuestion(
      id:                (json['id'] as num).toInt(),
      question:          json['evenement'] as String,
      lieu:              MapLieu.fromJson(json),
      difficulte:        json['difficulte'] as String,
      rayonToleranceKm:  (json['rayon_tolerance_km'] as num?)?.toDouble() ?? 50.0,
      pointsMax:         (json['points_max'] as num?)?.toInt() ?? 100,
    );
  }

  /// Désérialisation depuis les données stockées en session Firestore
  factory MapQuestion.fromMap(Map<String, dynamic> map) {
    return MapQuestion(
      id:               (map['id'] as num).toInt(),
      question:         map['question'] as String,
      lieu:             MapLieu.fromMap(map['lieu'] as Map<String, dynamic>),
      difficulte:       map['difficulte'] as String,
      rayonToleranceKm: (map['rayonToleranceKm'] as num?)?.toDouble() ?? 50.0,
      pointsMax:        (map['pointsMax'] as num?)?.toInt() ?? 100,
    );
  }

  /// Sérialisation vers Firestore
  Map<String, dynamic> toMap() => {
    'id':               id,
    'question':         question,
    'lieu':             lieu.toMap(),
    'difficulte':       difficulte,
    'rayonToleranceKm': rayonToleranceKm,
    'pointsMax':        pointsMax,
  };

  @override
  List<Object?> get props => [id];
}

// ─────────────────────────────────────────────────────────────
// CONFIG DU JEU (Chargement du JSON complet)
// ─────────────────────────────────────────────────────────────

class MapGameConfig {
  final String langue;
  final String version;
  final String description;
  final List<String> difficultyLevels;
  final List<MapQuestion> questions;

  const MapGameConfig({
    required this.langue,
    required this.version,
    required this.description,
    required this.difficultyLevels,
    required this.questions,
  });

  factory MapGameConfig.fromJson(Map<String, dynamic> json) {
    final meta   = json['meta'] as Map<String, dynamic>;
    final levels = List<String>.from(meta['difficulty_levels'] as List);

    return MapGameConfig(
      langue:           meta['language'] as String,
      version:          meta['version'] as String,
      description:      meta['description'] as String,
      difficultyLevels: levels,
      questions: (json['questions'] as List)
          .map((q) => MapQuestion.fromJson(q as Map<String, dynamic>, levels))
          .toList(),
    );
  }

  List<MapQuestion> generateQuiz({int? limit, String? filterDifficulty}) {
    var filtered = List<MapQuestion>.from(questions);
    if (filterDifficulty != null) {
      filtered = filtered.where((q) => q.difficulte == filterDifficulty).toList();
    }
    filtered.shuffle();
    if (limit != null && limit < filtered.length) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }
}