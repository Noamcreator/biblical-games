import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/models/game_type.dart';
import 'package:core/models/session.dart';

abstract class GameService {
  final FirebaseFirestore _db;

  GameService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('sessions');

  Future<Session> createSession({
    required GameType gameType,
    required int totalQuestions,
    int roundTimeSeconds = 60,
    bool sameCardForAll = true,
  });

  Future<void> startGame(String code, Session session);

  Future<void> drawNextQuestion(String code);

  Future<void> submitAnswer({
    required String code,
    required String playerId,
    required Map<String, dynamic> answer,
  });

  Future<void> endRound(String code);

  Future<void> showReview(String code);
}