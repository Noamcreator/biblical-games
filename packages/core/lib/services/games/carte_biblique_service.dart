import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session.dart';
import '../../models/game_type.dart';
import '../../models/games/carte_biblique.dart'; // ✅ bon import
import '../../services/json_loader.dart';

class CarteBibliqueService {
  final FirebaseFirestore _db;
  final JsonLoader _jsonLoader;

  CarteBibliqueService({FirebaseFirestore? db, JsonLoader? jsonLoader})
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
    final raw = await _jsonLoader.loadCarteBiblique();

    // ✅ fromJson lit le JSON brut (evenement / lat / lng / lieu_correct)
    final levels = List<String>.from(
      (raw['meta'] as Map<String, dynamic>)['difficulty_levels'] as List,
    );
    final questions = (raw['questions'] as List)
        .map((e) => MapQuestion.fromJson(Map<String, dynamic>.from(e), levels))
        .toList();

    var adjustedTotal = totalQuestions;
    if (adjustedTotal > questions.length) adjustedTotal = questions.length;

    questions.shuffle();
    final selected = questions.take(adjustedTotal).toList();

    // ✅ Les clés Firestore sont des String (id.toString())
    final questionsMap = {
      for (final q in selected) q.id.toString(): q.toMap()
    };
    final questionQueue = selected.map((q) => q.id.toString()).toList();

    final currentQuestionData = <String, dynamic>{
      'questions':        questionsMap,
      'questionQueue':    questionQueue,
      'currentQuestionId': null,
      'question':         null,
      'roundState':       'idle',
      'roundNumber':      0,
      'roundTimeSeconds': roundTimeSeconds,
      'reviewTimeSeconds': 15,
    };

    final session = Session(
      code:                 code,
      masterUid:            uid,
      gameType:             GameType.map,
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
    final qData = session.currentQuestionData;
    final currentQuestionId = qData?['currentQuestionId'] as String?;
    if (currentQuestionId == null) {
      await drawNextQuestion(code);
    } else {
      await _sessions.doc(code).update({'state': SessionState.playing.name});
    }
  }

  Future<void> drawNextQuestion(String code) async {
    final doc = await _sessions.doc(code).get();
    final data = doc.data()!;
    final qData = Map<String, dynamic>.from(
        data['currentQuestionData'] as Map<String, dynamic>);

    final queue = List<String>.from(qData['questionQueue'] as List? ?? []);
    final questions = Map<String, dynamic>.from(
        qData['questions'] as Map<String, dynamic>? ?? {});

    if (queue.isEmpty) {
      await _sessions.doc(code).update({'state': SessionState.finished.name});
      return;
    }

    final nextId = queue.removeAt(0); // String
    final questionData = Map<String, dynamic>.from(
        questions[nextId] as Map<String, dynamic>);

    final players = Map<String, dynamic>.from(
        data['players'] as Map<String, dynamic>? ?? {});
    final playerUpdates = <String, dynamic>{};
    for (final uid in players.keys) {
      playerUpdates['players.$uid.roundCompleted']   = false;
      playerUpdates['players.$uid.roundCorrect']     = false;
      playerUpdates['players.$uid.roundCompletedAt'] = null;
    }

    final roundNum    = ((qData['roundNumber'] as num?)?.toInt() ?? 0) + 1;
    final currentQIdx = (data['currentQuestionIndex'] as num?)?.toInt() ?? 0;
    final firstDraw   = qData['currentQuestionId'] == null ||
        ((qData['roundNumber'] as num?)?.toInt() ?? 0) == 0;
    final nextQuestionIndex = firstDraw ? currentQIdx : currentQIdx + 1;

    await _sessions.doc(code).update({
      ...playerUpdates,
      'currentQuestionIndex': nextQuestionIndex,
      'state': SessionState.playing.name,
      'currentQuestionData': {
        'questions':         questions,
        'questionQueue':     queue,
        'currentQuestionId': nextId,
        'question':          questionData, // ✅ toMap() stocké → fromMap() relu
        'roundState':        'playing',
        'roundNumber':       roundNum,
        'roundTimeSeconds':  qData['roundTimeSeconds'],
        'reviewTimeSeconds': qData['reviewTimeSeconds'],
        'roundStartedAt':    DateTime.now().toIso8601String(),
      },
    });
  }

  Future<String> _signInAnonymously() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;
    final cred = await auth.signInAnonymously();
    return cred.user!.uid;
  }

  static String _generateCode() {
    const words = ['RUTH', 'ADAM', 'NOAH', 'ABEL', 'SARA',
      'JOEL', 'AMOS', 'EZRA', 'LEVI', 'PAUL'];
    final word = words[DateTime.now().millisecond % words.length];
    final num  = (DateTime.now().second % 90) + 10;
    return '$word-$num';
  }
}