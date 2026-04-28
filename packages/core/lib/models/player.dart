import 'package:equatable/equatable.dart';

class Player extends Equatable {
  final String id;
  final String name;
  final int score;
  final bool isReady;
  final DateTime joinedAt;
  // Champs round (Fiche Perso)
  final bool roundCompleted;
  final bool roundCorrect;
  final String? roundCompletedAt;

  const Player({
    required this.id,
    required this.name,
    this.score = 0,
    this.isReady = false,
    required this.joinedAt,
    this.roundCompleted = false,
    this.roundCorrect = false,
    this.roundCompletedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'score': score,
        'isReady': isReady,
        'joinedAt': joinedAt.toIso8601String(),
        'roundCompleted': roundCompleted,
        'roundCorrect': roundCorrect,
        'roundCompletedAt': roundCompletedAt,
      };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
        id: map['id'] as String,
        name: map['name'] as String,
        score: (map['score'] as num?)?.toInt() ?? 0,
        isReady: map['isReady'] as bool? ?? false,
        joinedAt: DateTime.parse(map['joinedAt'] as String),
        roundCompleted: map['roundCompleted'] as bool? ?? false,
        roundCorrect: map['roundCorrect'] as bool? ?? false,
        roundCompletedAt: map['roundCompletedAt'] as String?,
      );

  @override
  List<Object?> get props => [id, score, roundCompleted, roundCorrect];
}