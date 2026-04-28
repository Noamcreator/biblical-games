import 'package:equatable/equatable.dart';
import 'game_type.dart';
import 'player.dart';

enum SessionState { waiting, playing, reviewing, finished }

class Session extends Equatable {
  final String code;
  final String masterUid;
  final GameType gameType;
  final SessionState state;
  final int currentQuestionIndex;
  final int totalQuestions;
  final Map<String, Player> players;
  final DateTime createdAt;
  final Map<String, dynamic>? currentQuestionData;

  const Session({
    required this.code,
    required this.masterUid,
    required this.gameType,
    required this.state,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.players,
    required this.createdAt,
    this.currentQuestionData,
  });

  bool get isWaiting   => state == SessionState.waiting;
  bool get isPlaying   => state == SessionState.playing;
  bool get isFinished  => state == SessionState.finished;
  bool get isReviewing => state == SessionState.reviewing;

  // ─── Helpers Fiche Perso ──────────────────────────────────

  String? get currentPersonnageId =>
      currentQuestionData?['currentPersonnageId'] as String?;

  String get roundState =>
      (currentQuestionData?['roundState'] as String?) ?? 'idle';

  int get roundNumber =>
      (currentQuestionData?['roundNumber'] as num?)?.toInt() ?? 0;

  String? get roundWinnerId  => currentQuestionData?['roundWinnerId']  as String?;
  String? get roundWinnerName => currentQuestionData?['roundWinnerName'] as String?;

  List<String> get piocheQueue =>
      List<String>.from(currentQuestionData?['piocheQueue'] as List? ?? []);
  List<String> get piocheUsed =>
      List<String>.from(currentQuestionData?['piocheUsed'] as List? ?? []);

  bool get roundIsPlaying => roundState == 'playing';
  bool get roundIsEnded   => roundState == 'roundEnd';
  bool get roundIsIdle    => roundState == 'idle';

  int get completedPlayersCount =>
      players.values.where((p) => p.roundCompleted).length;

  // ─── Sérialisation ────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'code': code,
        'masterUid': masterUid,
        'gameType': gameType.toJson(),
        'state': state.name,
        'currentQuestionIndex': currentQuestionIndex,
        'totalQuestions': totalQuestions,
        'players': players.map((k, v) => MapEntry(k, v.toMap())),
        'createdAt': createdAt.toIso8601String(),
        if (currentQuestionData != null) 'currentQuestionData': currentQuestionData,
      };

  factory Session.fromMap(Map<String, dynamic> map) {
    final playersRaw = (map['players'] as Map<String, dynamic>?) ?? {};
    return Session(
      code: map['code'] as String,
      masterUid: map['masterUid'] as String,
      gameType: GameType.fromJson(map['gameType'] as String),
      state: SessionState.values.byName(map['state'] as String),
      currentQuestionIndex: (map['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      players: playersRaw.map(
          (k, v) => MapEntry(k, Player.fromMap(v as Map<String, dynamic>))),
      createdAt: DateTime.parse(map['createdAt'] as String),
      currentQuestionData: map['currentQuestionData'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [code, state, roundState, roundWinnerId, players];
}