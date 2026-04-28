import 'package:equatable/equatable.dart';

class EvenementBiblique extends Equatable {
  final String id;
  final String titre;
  final String description;
  final int annee; // négatif = av. J.-C.
  final String? reference;
  final String? personnagePrincipal;

  const EvenementBiblique({
    required this.id,
    required this.titre,
    required this.description,
    required this.annee,
    this.reference,
    this.personnagePrincipal,
  });

  String get anneeLabel {
    if (annee < 0) return '${annee.abs()} av. J.-C.';
    return '$annee ap. J.-C.';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'titre': titre,
    'description': description,
    'annee': annee,
    'reference': reference,
    'personnagePrincipal': personnagePrincipal,
  };

  factory EvenementBiblique.fromMap(Map<String, dynamic> map) =>
      EvenementBiblique(
        id: map['id'] as String,
        titre: map['titre'] as String,
        description: map['description'] as String,
        annee: (map['annee'] as num).toInt(),
        reference: map['reference'] as String?,
        personnagePrincipal: map['personnagePrincipal'] as String?,
      );

  @override
  List<Object?> get props => [id, annee];
}

/// Question : remettre ces événements dans l'ordre chronologique
class FriseQuestion extends Equatable {
  final String id;
  final List<EvenementBiblique> evenementsAOrdonner;
  final int pointsMax;
  final int dureeSecondes;

  const FriseQuestion({
    required this.id,
    required this.evenementsAOrdonner,
    this.pointsMax = 150,
    this.dureeSecondes = 60,
  });

  /// L'ordre correct (trié par année croissante)
  List<EvenementBiblique> get ordreCorrect {
    final sorted = List<EvenementBiblique>.from(evenementsAOrdonner);
    sorted.sort((a, b) => a.annee.compareTo(b.annee));
    return sorted;
  }

  /// Calcule les points en fonction de combien d'éléments sont bien placés
  int calculerPoints(List<String> ordreJoueur) {
    final correct = ordreCorrect.map((e) => e.id).toList();
    int bonnesPositions = 0;
    for (int i = 0; i < correct.length && i < ordreJoueur.length; i++) {
      if (correct[i] == ordreJoueur[i]) bonnesPositions++;
    }
    return (pointsMax * bonnesPositions / correct.length).round();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'evenementsAOrdonner':
    evenementsAOrdonner.map((e) => e.toMap()).toList(),
    'pointsMax': pointsMax,
    'dureeSecondes': dureeSecondes,
  };

  factory FriseQuestion.fromMap(Map<String, dynamic> map) => FriseQuestion(
    id: map['id'] as String,
    evenementsAOrdonner: (map['evenementsAOrdonner'] as List)
        .map((e) => EvenementBiblique.fromMap(e as Map<String, dynamic>))
        .toList(),
    pointsMax: (map['pointsMax'] as num).toInt(),
    dureeSecondes: (map['dureeSecondes'] as num).toInt(),
  );

  static FriseQuestion get exemple => FriseQuestion(
    id: 'frise1',
    evenementsAOrdonner: [
      const EvenementBiblique(
        id: 'creation',
        titre: 'La Création',
        description: 'Dieu crée le monde en 6 jours',
        annee: -4000,
        reference: 'Genèse 1',
      ),
      const EvenementBiblique(
        id: 'exode',
        titre: 'L\'Exode',
        description: 'Moïse conduit Israël hors d\'Égypte',
        annee: -1446,
        personnagePrincipal: 'Moïse',
        reference: 'Exode 12',
      ),
      const EvenementBiblique(
        id: 'roi_david',
        titre: 'Règne de David',
        description: 'David devient roi d\'Israël',
        annee: -1010,
        personnagePrincipal: 'David',
        reference: '2 Samuel 5',
      ),
      const EvenementBiblique(
        id: 'naissance_jesus',
        titre: 'Naissance de Jésus',
        description: 'Naissance à Bethléem',
        annee: -4,
        personnagePrincipal: 'Jésus',
        reference: 'Luc 2',
      ),
      const EvenementBiblique(
        id: 'pentecote',
        titre: 'La Pentecôte',
        description: 'Effusion du Saint-Esprit',
        annee: 33,
        reference: 'Actes 2',
      ),
    ],
  );

  @override
  List<Object?> get props => [id];
}