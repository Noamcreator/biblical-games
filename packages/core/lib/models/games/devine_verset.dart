import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────
// JEU : DEVINE TON VERSET
// ─────────────────────────────────────────────────────────────

class DevineVersetQuestion extends Equatable {
  final String id;
  final String texteVerset; // le verset à deviner
  final String reference; // ex: "Jean 3:16"
  final String livre;
  final List<String> choixLivres; // pour QCM
  final List<String> choixReferences; // pour QCM
  final int pointsMax;
  final int dureeSecondes;

  const DevineVersetQuestion({
    required this.id,
    required this.texteVerset,
    required this.reference,
    required this.livre,
    required this.choixLivres,
    required this.choixReferences,
    this.pointsMax = 200,
    this.dureeSecondes = 40,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'texteVerset': texteVerset,
    'reference': reference,
    'livre': livre,
    'choixLivres': choixLivres,
    'choixReferences': choixReferences,
    'pointsMax': pointsMax,
    'dureeSecondes': dureeSecondes,
  };

  factory DevineVersetQuestion.fromMap(Map<String, dynamic> map) =>
      DevineVersetQuestion(
        id: map['id'] as String,
        texteVerset: map['texteVerset'] as String,
        reference: map['reference'] as String,
        livre: map['livre'] as String,
        choixLivres: List<String>.from(map['choixLivres'] as List),
        choixReferences: List<String>.from(map['choixReferences'] as List),
        pointsMax: (map['pointsMax'] as num).toInt(),
        dureeSecondes: (map['dureeSecondes'] as num).toInt(),
      );

  static DevineVersetQuestion get exemple => const DevineVersetQuestion(
    id: 'dv1',
    texteVerset:
    'Car Dieu a tant aimé le monde qu\'il a donné son Fils unique, afin que quiconque croit en lui ne périsse point, mais qu\'il ait la vie éternelle.',
    reference: 'Jean 3:16',
    livre: 'Jean',
    choixLivres: ['Jean', 'Matthieu', 'Luc', 'Marc'],
    choixReferences: ['Jean 3:16', 'Jean 1:1', 'Romains 8:28', 'Psaume 23:1'],
  );

  @override
  List<Object?> get props => [id, reference];
}

// ─────────────────────────────────────────────────────────────
// JEU : CARTE BIBLIQUE
// ─────────────────────────────────────────────────────────────

class LieuBiblique extends Equatable {
  final String id;
  final String nom;
  final double latitude;
  final double longitude;
  final String description;
  final String? evenement;
  final String? reference;

  const LieuBiblique({
    required this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.evenement,
    this.reference,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'evenement': evenement,
    'reference': reference,
  };

  factory LieuBiblique.fromMap(Map<String, dynamic> map) => LieuBiblique(
    id: map['id'] as String,
    nom: map['nom'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    description: map['description'] as String,
    evenement: map['evenement'] as String?,
    reference: map['reference'] as String?,
  );

  static List<LieuBiblique> get exemples => [
    const LieuBiblique(
      id: 'jerusalem',
      nom: 'Jérusalem',
      latitude: 31.7683,
      longitude: 35.2137,
      description: 'Ville sainte, capitale de David',
      evenement: 'Crucifixion et Résurrection de Jésus',
      reference: 'Luc 23-24',
    ),
    const LieuBiblique(
      id: 'bethleem',
      nom: 'Bethléem',
      latitude: 31.7054,
      longitude: 35.2024,
      description: 'Ville natale de David et de Jésus',
      evenement: 'Naissance de Jésus',
      reference: 'Luc 2:4-7',
    ),
    const LieuBiblique(
      id: 'nazareth',
      nom: 'Nazareth',
      latitude: 32.6996,
      longitude: 35.3035,
      description: 'Ville où Jésus a grandi',
      evenement: 'Enfance de Jésus',
      reference: 'Luc 2:39-40',
    ),
  ];
  
  @override
  List<Object?> get props => [id, nom, latitude, longitude, description];
}

/// Question : pointer un lieu sur la carte
class VerseMapQuestion extends Equatable {
  final String id;
  final LieuBiblique lieu;
  final String question; // ex: "Où Jésus a-t-il été baptisé ?"
  final int pointsMax;
  final int dureeSecondes;
  final double rayonToleranceKm; // distance max pour avoir les points

  const VerseMapQuestion({
    required this.id,
    required this.lieu,
    required this.question,
    this.pointsMax = 150,
    this.dureeSecondes = 45,
    this.rayonToleranceKm = 50,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'lieu': lieu.toMap(),
    'question': question,
    'pointsMax': pointsMax,
    'dureeSecondes': dureeSecondes,
    'rayonToleranceKm': rayonToleranceKm,
  };

  factory VerseMapQuestion.fromMap(Map<String, dynamic> map) {
    if (map['lieu'] is Map) {
      return VerseMapQuestion(
        id: (map['id'] ?? '').toString(),
        lieu: LieuBiblique.fromMap(map['lieu'] as Map<String, dynamic>),
        question: map['question'] as String,
        pointsMax: (map['pointsMax'] as num?)?.toInt() ?? 150,
        dureeSecondes: (map['dureeSecondes'] as num?)?.toInt() ?? 45,
        rayonToleranceKm: (map['rayonToleranceKm'] as num?)?.toDouble() ?? 50,
      );
    }

    final lieu = LieuBiblique(
      id: (map['id'] ?? '').toString(),
      nom: map['lieu_correct'] as String? ?? 'Lieu inconnu',
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      description: map['evenement'] as String? ?? 'Lieu biblique',
      evenement: map['evenement'] as String?,
      reference: null,
    );

    return VerseMapQuestion(
      id: (map['id'] ?? '').toString(),
      lieu: lieu,
      question: map['evenement'] as String? ?? 'Où était cet événement ?',
      pointsMax: (map['pointsMax'] as num?)?.toInt() ?? 150,
      dureeSecondes: (map['dureeSecondes'] as num?)?.toInt() ?? 45,
      rayonToleranceKm: (map['rayonToleranceKm'] as num?)?.toDouble() ?? 50,
    );
  }

  @override
  List<Object?> get props => [id, lieu];
}

// ─────────────────────────────────────────────────────────────
// JEU : RÉDACTION DE LA BIBLE
// ─────────────────────────────────────────────────────────────

class LivreBible extends Equatable {
  final String id;
  final String nom;
  final String auteur; // ou tradition d'attribution
  final String lieu;
  final int anneeFinRedaction; // négatif = av. J.-C.
  final String periodeCouverte;
  final String testament; // 'AT' ou 'NT'
  final String genre; // Histoire, Poésie, Prophétie, Épître...

  const LivreBible({
    required this.id,
    required this.nom,
    required this.auteur,
    required this.lieu,
    required this.anneeFinRedaction,
    required this.periodeCouverte,
    required this.testament,
    required this.genre,
  });

  String get anneeLabel {
    if (anneeFinRedaction < 0) {
      return '${anneeFinRedaction.abs()} av. J.-C.';
    }
    return '${anneeFinRedaction} ap. J.-C.';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'auteur': auteur,
    'lieu': lieu,
    'anneeFinRedaction': anneeFinRedaction,
    'periodeCouverte': periodeCouverte,
    'testament': testament,
    'genre': genre,
  };

  factory LivreBible.fromMap(Map<String, dynamic> map) => LivreBible(
    id: map['id'] as String,
    nom: map['nom'] as String,
    auteur: map['auteur'] as String,
    lieu: map['lieu'] as String,
    anneeFinRedaction: (map['anneeFinRedaction'] as num).toInt(),
    periodeCouverte: map['periodeCouverte'] as String,
    testament: map['testament'] as String,
    genre: map['genre'] as String,
  );

  static List<LivreBible> get exemples => [
    const LivreBible(
      id: 'genese',
      nom: 'Genèse',
      auteur: 'Moïse (tradition)',
      lieu: 'Désert du Sinaï',
      anneeFinRedaction: -1445,
      periodeCouverte: 'De la Création à la mort de Joseph',
      testament: 'AT',
      genre: 'Histoire',
    ),
    const LivreBible(
      id: 'jean',
      nom: 'Évangile de Jean',
      auteur: 'Jean l\'Apôtre',
      lieu: 'Éphèse',
      anneeFinRedaction: 90,
      periodeCouverte: 'Ministère de Jésus',
      testament: 'NT',
      genre: 'Évangile',
    ),
    const LivreBible(
      id: 'romains',
      nom: 'Romains',
      auteur: 'Paul',
      lieu: 'Corinthe',
      anneeFinRedaction: 57,
      periodeCouverte: 'Épître doctrinale',
      testament: 'NT',
      genre: 'Épître',
    ),
  ];

  @override
  List<Object?> get props => [id, nom];
}

/// Question : associer les bons champs au livre
class RedactionQuestion extends Equatable {
  final String id;
  final LivreBible livre;
  final List<String> champsCaches; // quels champs sont à deviner
  final List<LivreBible> choixPossibles;
  final int pointsMax;
  final int dureeSecondes;

  const RedactionQuestion({
    required this.id,
    required this.livre,
    required this.champsCaches,
    required this.choixPossibles,
    this.pointsMax = 120,
    this.dureeSecondes = 35,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'livre': livre.toMap(),
    'champsCaches': champsCaches,
    'choixPossibles': choixPossibles.map((l) => l.toMap()).toList(),
    'pointsMax': pointsMax,
    'dureeSecondes': dureeSecondes,
  };

  factory RedactionQuestion.fromMap(Map<String, dynamic> map) =>
      RedactionQuestion(
        id: map['id'] as String,
        livre: LivreBible.fromMap(map['livre'] as Map<String, dynamic>),
        champsCaches: List<String>.from(map['champsCaches'] as List),
        choixPossibles: (map['choixPossibles'] as List)
            .map((e) => LivreBible.fromMap(e as Map<String, dynamic>))
            .toList(),
        pointsMax: (map['pointsMax'] as num).toInt(),
        dureeSecondes: (map['dureeSecondes'] as num).toInt(),
      );

  @override
  List<Object?> get props => [id, livre];
}