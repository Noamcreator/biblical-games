import 'package:equatable/equatable.dart';

class VraiFauxQuestion extends Equatable {
  final String id;
  final String affirmation;
  final bool reponse; // true = Vrai, false = Faux
  final String explication;
  final String? reference; // ex: "Jean 3:16"
  final int pointsMax;
  final int dureeSecondes;

  const VraiFauxQuestion({
    required this.id,
    required this.affirmation,
    required this.reponse,
    required this.explication,
    this.reference,
    this.pointsMax = 100,
    this.dureeSecondes = 20,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'affirmation': affirmation,
    'reponse': reponse,
    'explication': explication,
    'reference': reference,
    'pointsMax': pointsMax,
    'dureeSecondes': dureeSecondes,
  };

  factory VraiFauxQuestion.fromMap(Map<String, dynamic> map) =>
      VraiFauxQuestion(
        id: map['id'] as String,
        affirmation: map['affirmation'] as String,
        reponse: map['reponse'] as bool,
        explication: map['explication'] as String,
        reference: map['reference'] as String?,
        pointsMax: (map['pointsMax'] as num).toInt(),
        dureeSecondes: (map['dureeSecondes'] as num).toInt(),
      );

  static List<VraiFauxQuestion> get exemples => [
    const VraiFauxQuestion(
      id: 'vf1',
      affirmation: 'Moïse a traversé la mer Rouge à pied sec.',
      reponse: true,
      explication:
      'Dieu a fendu la mer Rouge pour permettre la fuite d\'Israël (Exode 14).',
      reference: 'Exode 14:21-22',
    ),
    const VraiFauxQuestion(
      id: 'vf2',
      affirmation: 'Jonas a passé 3 jours dans le ventre d\'une baleine.',
      reponse: true,
      explication:
      'La Bible dit "grand poisson" (dag gadol), pas nécessairement une baleine.',
      reference: 'Jonas 1:17',
    ),
    const VraiFauxQuestion(
      id: 'vf3',
      affirmation: 'Jésus est né à Nazareth.',
      reponse: false,
      explication:
      'Jésus est né à Bethléem, même s\'il a grandi à Nazareth.',
      reference: 'Luc 2:4-7',
    ),
  ];

  @override
  List<Object?> get props => [id, affirmation, reponse];
}