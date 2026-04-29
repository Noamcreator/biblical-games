import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session.dart';
import '../../models/game_type.dart';
import '../../models/games/vrai_ou_faux.dart';
import '../../services/json_loader.dart';

class VraiFauxService {
  final FirebaseFirestore _db;
  final JsonLoader _jsonLoader;

  VraiFauxService({FirebaseFirestore? db, JsonLoader? jsonLoader})
      : _db = db ?? FirebaseFirestore.instance,
        _jsonLoader = jsonLoader ?? JsonLoader();

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  Future<Session> createSession({
    required int totalQuestions,
    required int roundTimeSeconds,
  }) async {
    final uid = await _signInAnonymously();
    final code = _generateCode();

    final rawJson = await _jsonLoader.loadVraiFaux();
    final config  = VraiFauxGameConfig.fromJson(rawJson);

    final allQuestions = List<VraiFauxQuestion>.from(config.questions)
      ..shuffle(Random.secure()); // ✅ FIX : Random.secure() pour une vraie distribution
    final selectedQuestions = allQuestions.take(totalQuestions).toList();
    final adjustedTotal     = selectedQuestions.length;

    final questionsMap = {
      for (final q in selectedQuestions) q.id.toString(): q.toJson()
    };
    final selectedIds = selectedQuestions.map((q) => q.id.toString()).toList();

    final currentQuestionData = <String, dynamic>{
      'questions':         questionsMap,
      'questionQueue':     selectedIds,
      'currentQuestionId': null,
      'question':          null,
      'roundState':        'idle',
      'roundNumber':       0,
      'roundTimeSeconds':  roundTimeSeconds,
      'reviewTimeSeconds': 10,
    };

    final session = Session(
      code:                 code,
      masterUid:            uid,
      gameType:             GameType.vraiFaux,
      state:                SessionState.waiting,
      currentQuestionIndex: 0,
      totalQuestions:       adjustedTotal,
      players:              const {},
      createdAt:            DateTime.now(),
      currentQuestionData:  currentQuestionData,
    );

    await _sessions.doc(code).set(session.toMap());
    return session;
  }

  Future<void> startGame(String code, Session session) async {
    final qData            = session.currentQuestionData;
    final currentQuestionId = qData?['currentQuestionId'];

    if (currentQuestionId == null) {
      await drawNextQuestion(code);
    } else {
      await _sessions
          .doc(code)
          .update({'state': SessionState.playing.name});
    }
  }

  Future<void> drawNextQuestion(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists) return;

    final data  = doc.data()!;
    final qData = Map<String, dynamic>.from(
        data['currentQuestionData'] ?? <String, dynamic>{});

    final queue     = List<String>.from(qData['questionQueue'] ?? []);
    final questions = Map<String, dynamic>.from(qData['questions'] ?? {});

    if (queue.isEmpty) {
      await _sessions
          .doc(code)
          .update({'state': SessionState.finished.name});
      return;
    }

    final nextId      = queue.removeAt(0);
    final questionData =
        Map<String, dynamic>.from(questions[nextId] as Map<String, dynamic>);

    // Reset des états joueurs pour le nouveau round
    final players      = Map<String, dynamic>.from(data['players'] ?? {});
    final playerUpdates = <String, dynamic>{};
    for (final uid in players.keys) {
      playerUpdates['players.$uid.roundCompleted']  = false;
      playerUpdates['players.$uid.roundCorrect']    = false;
      playerUpdates['players.$uid.roundCompletedAt'] = null;
    }

    final roundNum         = (qData['roundNumber'] as int? ?? 0) + 1;
    final currentQIdx      = (data['currentQuestionIndex'] as int? ?? 0);
    final isFirstQuestion  = qData['currentQuestionId'] == null;
    final nextQuestionIndex = isFirstQuestion ? 1 : currentQIdx + 1;

    await _sessions.doc(code).update({
      ...playerUpdates,
      'currentQuestionIndex': nextQuestionIndex,
      'state':                SessionState.playing.name,
      'currentQuestionData': {
        ...qData,
        'questionQueue':     queue,
        'currentQuestionId': nextId,
        'question':          questionData,
        'roundState':        'playing',
        'roundNumber':       roundNum,
        'roundStartedAt':    DateTime.now().toIso8601String(),
        'reviewStartedAt':   null,
      },
    });
  }

  // ── Helpers ──────────────────────────────────────────────

  Future<String> _signInAnonymously() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;
    final cred = await auth.signInAnonymously();
    return cred.user!.uid;
  }

  // ✅ FIX : utilisation de Random.secure() pour une vraie distribution uniforme
  static String _generateCode() {
    const words = [
      'RUTH', 'ADAM', 'NOAH', 'ABEL', 'SARA',
      'JOEL', 'AMOS', 'EZRA', 'LEVI', 'PAUL'
    ];
    final rng  = Random.secure();
    final word = words[rng.nextInt(words.length)];
    final num  = 10 + rng.nextInt(90); // [10, 99]
    return '$word-$num';
  }
}