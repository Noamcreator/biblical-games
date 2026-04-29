import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────
// MODÈLE QUESTION (Vrai/Faux)
// ─────────────────────────────────────────────────────────────

class VraiFauxQuestion extends Equatable {
  final int id;
  final String statement;
  final bool answer;
  final String explanation;
  final String? reference; // ✅ FIX : nullable, cohérent avec les null-checks de l'UI
  final String difficulte;
  final int pointsMax;

  const VraiFauxQuestion({
    required this.id,
    required this.statement,
    required this.answer,
    required this.explanation,
    this.reference, // ✅ FIX : optionnel
    required this.difficulte,
    required this.pointsMax,
  });

  /// Désérialisation depuis le JSON source (assets)
  factory VraiFauxQuestion.fromJson(
    Map<String, dynamic> json,
    List<String> difficultyLevels,
  ) {
    final diffIdx = (json['difficulty'] as num).toInt();
    return VraiFauxQuestion(
      id:          json['id'] as int,
      statement:   json['statement'] as String,
      answer:      json['answer'] as bool,
      explanation: json['explanation'] as String,
      reference:   json['reference'] as String?,        // ✅ nullable
      difficulte:  difficultyLevels[diffIdx],
      pointsMax:   100,
    );
  }

  /// Désérialisation depuis les données stockées en session Firestore
  factory VraiFauxQuestion.fromMap(Map<String, dynamic> map) {
    return VraiFauxQuestion(
      id:          (map['id'] as num).toInt(),
      statement:   map['enonce'] as String,
      answer:      map['reponseAttendue'] as bool,
      explanation: map['explication'] as String,
      reference:   map['reference'] as String?,         // ✅ nullable
      difficulte:  map['difficulte'] as String,
      pointsMax:   (map['pointsMax'] as num).toInt(),
    );
  }

  /// Sérialisation vers Firestore
  Map<String, dynamic> toJson() => {
    'id':              id,
    'enonce':          statement,
    'reponseAttendue': answer,
    'explication':     explanation,
    'reference':       reference,   // peut être null → Firestore l'ignore proprement
    'difficulte':      difficulte,
    'pointsMax':       pointsMax,
  };

  @override
  List<Object?> get props => [id];
}

// ─────────────────────────────────────────────────────────────
// CONFIG DU JEU (Chargement du JSON complet)
// ─────────────────────────────────────────────────────────────

class VraiFauxGameConfig {
  final String langue;
  final String version;
  final String description;
  final List<String> difficultyLevels;
  final List<VraiFauxQuestion> questions;

  const VraiFauxGameConfig({
    required this.langue,
    required this.version,
    required this.description,
    required this.difficultyLevels,
    required this.questions,
  });

  factory VraiFauxGameConfig.fromJson(Map<String, dynamic> json) {
    final meta   = json['meta'] as Map<String, dynamic>;
    final levels = List<String>.from(meta['difficulty_levels'] as List);

    return VraiFauxGameConfig(
      langue:           meta['language'] as String,
      version:          meta['version'] as String,
      description:      meta['description'] as String,
      difficultyLevels: levels,
      questions: (json['questions'] as List)
          .map((q) => VraiFauxQuestion.fromJson(q as Map<String, dynamic>, levels))
          .toList(),
    );
  }

  List<VraiFauxQuestion> generateQuiz({int? limit, String? filterDifficulty}) {
    var filtered = List<VraiFauxQuestion>.from(questions);
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

// ─────────────────────────────────────────────────────────────
// LOGIQUE DE SESSION (Gameplay local)
// ─────────────────────────────────────────────────────────────

class VraiFauxSession {
  final VraiFauxQuestion question;
  bool? reponseUtilisateur;
  bool isLocked = false;

  VraiFauxSession({required this.question});

  bool get isCorrect => reponseUtilisateur == question.answer;

  void repondre(bool choix) {
    if (!isLocked) {
      reponseUtilisateur = choix;
      isLocked = true;
    }
  }
}