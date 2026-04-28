import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/games/fiche_perso.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../models/game_type.dart';
import '../services/json_loader.dart';

class SessionService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  SessionService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  // ═══════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════

  Future<String> signInAnonymously() async {
    if (_auth.currentUser != null) return _auth.currentUser!.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  String? get currentUid => _auth.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════
  // GESTION DE SESSION
  // ═══════════════════════════════════════════════════════════

  static String _generateCode() {
    const words = ['RUTH', 'ADAM', 'NOAH', 'ABEL', 'SARA',
                   'JOEL', 'AMOS', 'EZRA', 'LEVI', 'PAUL'];
    final word = words[DateTime.now().millisecond % words.length];
    final num = (DateTime.now().second % 90) + 10;
    return '$word-$num';
  }

  static List<String> _chooseVisibleFields({int count = 4}) {
    final candidates = [
      'localisation',
      'role',
      'periodeHistorique',
      'livreBible',
      'symbole',
      'evenementMarquant',
      'qualite',
      'defaut',
    ];
    final fields = List<String>.from(candidates)..shuffle();
    return fields.take(count).toList();
  }

  Future<Session> createSession({
    required GameType gameType,
    required int totalQuestions,
  }) async {
    final uid = await signInAnonymously();
    final code = _generateCode();

    Map<String, dynamic>? currentQuestionData;
    var adjustedTotalQuestions = totalQuestions;

    if (gameType == GameType.fichePerso) {
      final config = await JsonLoader().loadFichePerso();
      final availableIds = config.generatePioche();
      if (adjustedTotalQuestions > availableIds.length) {
        adjustedTotalQuestions = availableIds.length;
      }
      final selectedIds = availableIds.take(adjustedTotalQuestions).toList();
      final personnages = <String, dynamic>{};
      for (final personnage in config.personnages.where((p) => selectedIds.contains(p.id))) {
        personnages[personnage.id] = personnage.toJson();
      }
      currentQuestionData = {
        'personnages': personnages,
        'piocheQueue': selectedIds,
        'piocheUsed': <String>[],
        'currentPersonnageId': null,
        'fiche': null,
        'champsVisibles': <String>[],
        'cards': <String>[],
        'roundState': 'idle',
        'roundNumber': 0,
        'roundWinnerId': null,
        'roundWinnerName': null,
      };
    }

    final session = Session(
      code: code,
      masterUid: uid,
      gameType: gameType,
      state: SessionState.waiting,
      currentQuestionIndex: 0,
      totalQuestions: adjustedTotalQuestions,
      players: const {},
      createdAt: DateTime.now(),
      currentQuestionData: currentQuestionData,
    );
    await _sessions.doc(code).set(session.toMap());
    return session;
  }

  Future<Session> joinSession({
    required String code,
    required String playerName,
  }) async {
    final uid = await signInAnonymously();
    final doc = await _sessions.doc(code).get();
    if (!doc.exists) throw Exception('Salle introuvable : $code');

    final session = Session.fromMap(doc.data()!);
    if (session.isFinished) throw Exception('Cette partie est déjà terminée.');

    final player = Player(id: uid, name: playerName, joinedAt: DateTime.now());
    await _sessions.doc(code).update({'players.$uid': player.toMap()});
    return session;
  }

  Stream<Session> watchSession(String code) {
    return _sessions.doc(code).snapshots().map((snap) {
      if (!snap.exists) throw Exception('Session disparue');
      return Session.fromMap(snap.data()!);
    });
  }

  Future<void> endGame(String code) async {
    await _sessions.doc(code).update({'state': SessionState.finished.name});
  }

  Future<void> startGame(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists) throw Exception('Session introuvable : $code');

    final session = Session.fromMap(doc.data()!);
    if (session.gameType == GameType.fichePerso) {
      final qData = session.currentQuestionData;
      final currentPersonnageId = qData?['currentPersonnageId'] as String?;
      if (currentPersonnageId == null) {
        await drawNextPersonnage(code);
      } else {
        await _sessions.doc(code).update({'state': SessionState.playing.name});
      }
      return;
    }

    await _sessions.doc(code).update({'state': SessionState.playing.name});
  }

  Future<List<Player>> getFinalScores(String code) async {
    final doc = await _sessions.doc(code).get();
    final session = Session.fromMap(doc.data()!);
    return session.players.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<void> showReview(String code) async {
    await _sessions.doc(code).update({'state': SessionState.reviewing.name});
  }

  // ═══════════════════════════════════════════════════════════
  // FICHE PERSO — GAME MASTER
  // ═══════════════════════════════════════════════════════════

  /// Initialise la pioche (appelé par le GM après CreateSession)
  Future<void> initFichePerso({
    required String code,
    required List<String> piocheIds,
  }) async {
    await _sessions.doc(code).update({
      'currentQuestionData': {
        'piocheQueue': piocheIds,
        'piocheUsed': <String>[],
        'currentPersonnageId': null,
        'roundState': 'idle',
        'roundNumber': 0,
        'roundWinnerId': null,
        'roundWinnerName': null,
      },
      'state': SessionState.playing.name,
    });
  }

  /// GM tire le prochain personnage de la pioche
  Future<void> drawNextPersonnage(String code) async {
    final doc = await _sessions.doc(code).get();
    final data = doc.data()!;
    final qData = Map<String, dynamic>.from(
        data['currentQuestionData'] as Map<String, dynamic>);

    final queue = List<String>.from(qData['piocheQueue'] as List? ?? []);
    final used = List<String>.from(qData['piocheUsed'] as List? ?? []);
    final personnages = Map<String, dynamic>.from(
        qData['personnages'] as Map<String, dynamic>? ?? {});

    if (queue.isEmpty) {
      await _sessions.doc(code).update({'state': SessionState.finished.name});
      return;
    }

    final next = queue.removeAt(0);
    used.add(next);
    final roundNum = ((qData['roundNumber'] as num?)?.toInt() ?? 0) + 1;

    final currentQuestionIndex = (data['currentQuestionIndex'] as num?)?.toInt() ?? 0;
    final firstDraw = qData['currentPersonnageId'] == null ||
        ((qData['roundNumber'] as num?)?.toInt() ?? 0) == 0;
    final nextQuestionIndex = firstDraw ? currentQuestionIndex : currentQuestionIndex + 1;

    // Charger le config du JSON pour obtenir duplicateFactor et reviewTime
    final config = await JsonLoader().loadFichePerso();
    final duplicateFactor = config.duplicateCardsPerField;
    final reviewTimeSeconds = config.reviewTimeSeconds;

    final ficheJson = Map<String, dynamic>.from(
        personnages[next] as Map<String, dynamic>);
    final fiche = FichePersoPersonnage.fromJson(ficheJson);
    final visibleFields = _chooseVisibleFields();
    final cards = fiche
        .generateCards(duplicateFactor: duplicateFactor)
        .where((card) => !visibleFields.contains(card.champ))
        .map((card) => card.toJson())
        .toList();

    // Réinitialiser les états joueurs pour ce round
    final players = Map<String, dynamic>.from(
        data['players'] as Map<String, dynamic>? ?? {});
    final playerUpdates = <String, dynamic>{};
    for (final uid in players.keys) {
      playerUpdates['players.$uid.roundCompleted'] = false;
      playerUpdates['players.$uid.roundCorrect'] = false;
      playerUpdates['players.$uid.roundCompletedAt'] = null;
    }

    await _sessions.doc(code).update({
      ...playerUpdates,
      'currentQuestionIndex': nextQuestionIndex,
      'state': SessionState.playing.name,
      'currentQuestionData': {
        'personnages':        personnages,
        'piocheQueue':        queue,
        'piocheUsed':         used,
        'currentPersonnageId': next,
        'fiche':               ficheJson,
        'champsVisibles':      visibleFields,
        'cards':               cards,
        'roundState':         'playing',
        'roundNumber':        roundNum,
        'roundWinnerId':      null,
        'roundWinnerName':    null,
        'reviewTimeSeconds':  reviewTimeSeconds,
        'roundStartedAt':     DateTime.now().toIso8601String(),
      },
    });
  }

  /// GM clôture le round → affiche les réponses à tous
  Future<void> endRound(String code) async {
    await _sessions.doc(code).update({
      'currentQuestionData.roundState': 'roundEnd',
    });
  }

  // ═══════════════════════════════════════════════════════════
  // FICHE PERSO — JOUEUR
  // ═══════════════════════════════════════════════════════════

  /// Soumet la plaquette complétée (appelé quand le joueur valide)
  Future<void> submitFicheBoard({
    required String code,
    required String playerId,
    required Map<String, String> placements,
    required bool isCorrect,
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Enregistre dans la sous-collection boards
    await _db
        .collection('sessions')
        .doc(code)
        .collection('boards')
        .doc(playerId)
        .set({
      'placements': placements,
      'isCorrect':  isCorrect,
      'submittedAt': now,
    }, SetOptions(merge: false));

    // 2. Mise à jour du player dans la session
    final updates = <String, dynamic>{
      'players.$playerId.roundCompleted':  true,
      'players.$playerId.roundCorrect':    isCorrect,
      'players.$playerId.roundCompletedAt': now,
    };

    if (isCorrect) {
      // Vérifie si c'est le premier à avoir bon
      final doc = await _sessions.doc(code).get();
      final qData = doc.data()?['currentQuestionData'] as Map<String, dynamic>?;
      final alreadyWon = qData?['roundWinnerId'] != null;

      if (!alreadyWon) {
        // 🥇 Premier → +100 pts
        updates['players.$playerId.score'] = FieldValue.increment(100);
        updates['currentQuestionData.roundWinnerId'] = playerId;
        final playerData =
            (doc.data()?['players'] as Map<String, dynamic>?)?[playerId];
        updates['currentQuestionData.roundWinnerName'] =
            (playerData?['name'] as String?) ?? 'Joueur';
      } else {
        // Correct mais pas premier → +30 pts
        updates['players.$playerId.score'] = FieldValue.increment(30);
      }
    }

    await _sessions.doc(code).update(updates);
  }

  /// Soumet une réponse de jeu générique (tous les jeux côté joueur)
  Future<void> submitAnswer({
    required String sessionCode,
    required String playerId,
    required Object answer,
    required int points,
  }) async {
    if (playerId.isEmpty) {
      throw Exception('Player ID manquant pour la soumission.');
    }

    final now = DateTime.now().toIso8601String();

    await _db
        .collection('sessions')
        .doc(sessionCode)
        .collection('answers')
        .add({
      'playerId': playerId,
      'answer': answer,
      'points': points,
      'submittedAt': now,
    });

    if (points != 0) {
      await _sessions.doc(sessionCode).update({
        'players.$playerId.score': FieldValue.increment(points),
      });
    }
  }

  /// Stream des boards (Game Master peut voir les soumissions en temps réel)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBoards(String code) {
    return _db
        .collection('sessions')
        .doc(code)
        .collection('boards')
        .snapshots();
  }
}