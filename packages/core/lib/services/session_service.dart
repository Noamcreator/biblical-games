import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/games/fiche_perso.dart';
import '../models/games/vrai_ou_faux.dart';
import '../models/games/devine_verset.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../models/game_type.dart';
import '../services/json_loader.dart';
import '../services/games/vrai_faux_service.dart';
import '../services/games/carte_biblique_service.dart';

class SessionService {
  final FirebaseFirestore db;
  final FirebaseAuth _auth;

  SessionService({FirebaseFirestore? db, FirebaseAuth? auth})
      : db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      db.collection('sessions');

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
  // GESTION DE SESSION (commune)
  // ═══════════════════════════════════════════════════════════

  static String _generateCode() {
    const words = ['RUTH', 'ADAM', 'NOAH', 'ABEL', 'SARA',
                   'JOEL', 'AMOS', 'EZRA', 'LEVI', 'PAUL'];
    final word = words[DateTime.now().millisecond % words.length];
    final num  = (DateTime.now().second % 90) + 10;
    return '$word-$num';
  }

  late final VraiFauxService _vraiFauxHelper = VraiFauxService(db: db);
  late final CarteBibliqueService _carteBibliqueHelper = CarteBibliqueService(db: db);

  Future<Session> createSession({
    required GameType gameType,
    required int totalQuestions,
    int roundTimeSeconds = 60,
    bool sameCardForAll = true,
  }) async {
    switch (gameType) {
      case GameType.fichePerso:
        return _createFichePersoSession(
          totalQuestions:  totalQuestions,
          roundTimeSeconds: roundTimeSeconds,
          sameCardForAll:  sameCardForAll,
        );
      case GameType.map:
        return _carteBibliqueHelper.createSession(
          totalQuestions: totalQuestions,
          roundTimeSeconds: roundTimeSeconds,
        );
      case GameType.vraiFaux:
        return _vraiFauxHelper.createSession(
          totalQuestions: totalQuestions,
          roundTimeSeconds: roundTimeSeconds,
        );
      case GameType.friseChronologique:
        throw UnimplementedError();
      case GameType.devineVerset:
        throw UnimplementedError();
      case GameType.redactionBible:
        throw UnimplementedError();
    }
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
    switch (session.gameType) {
      case GameType.fichePerso:
        await _startFichePerso(code, session);
        break;
      case GameType.map:
        await _carteBibliqueHelper.startGame(code, session);
        break;
      case GameType.vraiFaux:
        await _vraiFauxHelper.startGame(code, session);
        break;
      case GameType.friseChronologique:
        throw UnimplementedError();
      case GameType.devineVerset:
        throw UnimplementedError();
      case GameType.redactionBible:
        throw UnimplementedError();
    }
  }

  Future<void> drawNextQuestion(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists) throw Exception('Session introuvable : $code');
    final session = Session.fromMap(doc.data()!);
    switch (session.gameType) {
      case GameType.fichePerso:
        await drawNextPersonnage(code);
        break;
      case GameType.map:
        await _carteBibliqueHelper.drawNextQuestion(code);
        break;
      case GameType.vraiFaux:
        await _vraiFauxHelper.drawNextQuestion(code);
        break;
      case GameType.friseChronologique:
        throw UnimplementedError();
      case GameType.devineVerset:
        throw UnimplementedError();
      case GameType.redactionBible:
        throw UnimplementedError();
    }
  }

  Future<List<Player>> getFinalScores(String code) async {
    final doc     = await _sessions.doc(code).get();
    final session = Session.fromMap(doc.data()!);
    return session.players.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  // ═══════════════════════════════════════════════════════════
  // ── FICHE PERSO ────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  // ── Création ─────────────────────────────────────────────

  Future<Session> _createFichePersoSession({
    required int totalQuestions,
    required int roundTimeSeconds,
    required bool sameCardForAll,
  }) async {
    final uid    = await signInAnonymously();
    final code   = _generateCode();
    final config = await JsonLoader().loadFichePerso();
    final availableIds = config.generatePioche();

    var adjustedTotal = totalQuestions;
    if (sameCardForAll && adjustedTotal > availableIds.length) {
      adjustedTotal = availableIds.length;
    }

    final selectedIds = sameCardForAll
        ? availableIds.take(adjustedTotal).toList()
        : availableIds;

    // Stocker tous les personnages sérialisés dans la session
    final personnages = <String, dynamic>{};
    for (final p in config.personnages.where((p) => selectedIds.contains(p.id))) {
      personnages[p.id] = p.toJson();
    }

    final currentQuestionData = <String, dynamic>{
      'personnages':         personnages,
      'piocheQueue':         selectedIds,
      'piocheUsed':          <String>[],
      'currentPersonnageId': null,
      'fiche':               null,
      'champsVisibles':      <String>[],
      'cards':               <String>[],
      'roundState':          'idle',
      'roundNumber':         0,
      'roundWinnerId':       null,
      'roundWinnerName':     null,
      'roundTimeSeconds':    roundTimeSeconds,
      'reviewTimeSeconds':   config.reviewTimeSeconds,
      'sameCardForAll':      sameCardForAll,
      'playerQuestions':     null,
    };

    final session = Session(
      code:                 code,
      masterUid:            uid,
      gameType:             GameType.fichePerso,
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

  // ── Démarrage ────────────────────────────────────────────

  Future<void> _startFichePerso(String code, Session session) async {
    final qData               = session.currentQuestionData;
    final currentPersonnageId = qData?['currentPersonnageId'] as String?;
    if (currentPersonnageId == null) {
      await drawNextPersonnage(code);
    } else {
      await _sessions.doc(code).update({'state': SessionState.playing.name});
    }
  }

  // ── Tirage du prochain personnage (Game Master) ───────────

  Future<void> drawNextPersonnage(String code) async {
    final doc   = await _sessions.doc(code).get();
    final data  = doc.data()!;
    final qData = Map<String, dynamic>.from(
        data['currentQuestionData'] as Map<String, dynamic>);

    final queue       = List<String>.from(qData['piocheQueue'] as List? ?? []);
    final used        = List<String>.from(qData['piocheUsed']  as List? ?? []);
    final personnages = Map<String, dynamic>.from(
        qData['personnages'] as Map<String, dynamic>? ?? {});
    final sameCardForAll   = qData['sameCardForAll']   as bool? ?? true;
    final roundTimeSeconds = (qData['roundTimeSeconds'] as num?)?.toInt() ?? 60;
    final reviewTimeSeconds = (qData['reviewTimeSeconds'] as num?)?.toInt() ?? 15;

    if (queue.isEmpty) {
      await _sessions.doc(code).update({'state': SessionState.finished.name});
      return;
    }

    final roundNum          = ((qData['roundNumber'] as num?)?.toInt() ?? 0) + 1;
    final currentQIdx       = (data['currentQuestionIndex'] as num?)?.toInt() ?? 0;
    final firstDraw         = qData['currentPersonnageId'] == null ||
        ((qData['roundNumber'] as num?)?.toInt() ?? 0) == 0;
    final nextQuestionIndex = firstDraw ? currentQIdx : currentQIdx + 1;

    final config          = await JsonLoader().loadFichePerso();
    final duplicateFactor = config.duplicateCardsPerField;

    // Visibles : nom et localisation sont affichés pour orienter le joueur
    const visibleFields = ['nom', 'localisation'];

    // Réinitialiser les états joueurs
    final players       = Map<String, dynamic>.from(
        data['players'] as Map<String, dynamic>? ?? {});
    final playerUpdates = <String, dynamic>{};
    for (final uid in players.keys) {
      playerUpdates['players.$uid.roundCompleted']   = false;
      playerUpdates['players.$uid.roundCorrect']     = false;
      playerUpdates['players.$uid.roundCompletedAt'] = null;
    }

    Map<String, dynamic>? playerQuestions;
    String?              currentPersonnageId;
    Map<String, dynamic>? ficheJson;
    List<Map<String, dynamic>>? cards;

    if (!sameCardForAll && players.isNotEmpty) {
      // ── Mode cartes différentes par joueur ────────────────
      final playerIds = players.keys.toList();
      final nextIds   = <String>[];

      while (nextIds.length < playerIds.length) {
        if (queue.isEmpty) {
          if (used.isEmpty) break;
          queue.addAll(used..shuffle());
          used.clear();
        }
        nextIds.add(queue.removeAt(0));
        used.add(nextIds.last);
      }

      final allIds = personnages.keys.toList();
      while (nextIds.length < playerIds.length) {
        nextIds.add(allIds[nextIds.length % allIds.length]);
      }

      playerQuestions = <String, dynamic>{};
      for (var i = 0; i < playerIds.length; i++) {
        final playerId     = playerIds[i];
        final personnageId = nextIds[i];
        final fiche        = FichePersoPersonnage.fromJson(
            Map<String, dynamic>.from(
                personnages[personnageId] as Map<String, dynamic>));
        final questionCards = fiche
            .generateCards(duplicateFactor: duplicateFactor)
            .where((card) => !visibleFields.contains(card.champ))
            .map((card) => card.toJson())
            .toList();

        playerQuestions[playerId] = {
          'fiche':          Map<String, dynamic>.from(
              personnages[personnageId] as Map<String, dynamic>),
          'champsVisibles': visibleFields,
          'cards':          questionCards,
          'pointsMax':      100,
        };
      }
      currentPersonnageId = nextIds.first;

    } else {
      // ── Mode même carte pour tous ─────────────────────────
      final next = queue.removeAt(0);
      used.add(next);
      currentPersonnageId = next;
      ficheJson = Map<String, dynamic>.from(
          personnages[next] as Map<String, dynamic>);

      final fiche = FichePersoPersonnage.fromJson(ficheJson);
      cards = fiche
          .generateCards(duplicateFactor: duplicateFactor)
          .where((card) => !visibleFields.contains(card.champ))
          .map((card) => card.toJson())
          .toList();

      playerQuestions = <String, dynamic>{};
      for (final playerId in players.keys) {
        playerQuestions[playerId] = {
          'fiche':          ficheJson,
          'champsVisibles': visibleFields,
          'cards':          cards,
          'pointsMax':      100,
        };
      }
    }

    await _sessions.doc(code).update({
      ...playerUpdates,
      'currentQuestionIndex': nextQuestionIndex,
      'state': SessionState.playing.name,
      'currentQuestionData': {
        'personnages':          personnages,
        'piocheQueue':          queue,
        'piocheUsed':           used,
        'currentPersonnageId':  currentPersonnageId,
        'fiche':                ficheJson,
        'champsVisibles':       visibleFields,
        'cards':                cards,
        'playerQuestions':      playerQuestions,
        'sameCardForAll':       sameCardForAll,
        'roundTimeSeconds':     roundTimeSeconds,
        'reviewTimeSeconds':    reviewTimeSeconds,
        'roundState':           'playing',
        'roundNumber':          roundNum,
        'roundWinnerId':        null,
        'roundWinnerName':      null,
        'roundStartedAt':       DateTime.now().toIso8601String(),
      },
    });
  }

  /// GM clôture le round
  Future<void> endRound(String code) async {
    await _sessions.doc(code).update({
      'currentQuestionData.roundState': 'roundEnd',
    });
  }

  /// GM passe en mode correction
  Future<void> showReview(String code) async {
    await _sessions.doc(code).update({
      'state': SessionState.reviewing.name,
    });
  }

  // ── Soumission joueur (Fiche Perso) ──────────────────────

  /// [points] est calculé côté client (proportionnel + bonus temps).
  /// Si [isCorrect] + premier à finir → bonus supplémentaire géré ici.
  Future<void> submitFicheBoard({
    required String code,
    required String playerId,
    required Map<String, String> placements,
    required bool isCorrect,
    int points = 0,
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Enregistre dans la sous-collection boards
    await db
        .collection('sessions')
        .doc(code)
        .collection('boards')
        .doc(playerId)
        .set({
      'placements':  placements,
      'isCorrect':   isCorrect,
      'points':      points,
      'submittedAt': now,
    }, SetOptions(merge: false));

    // 2. Mise à jour du joueur
    final updates = <String, dynamic>{
      'players.$playerId.roundCompleted':   true,
      'players.$playerId.roundCorrect':     isCorrect,
      'players.$playerId.roundCompletedAt': now,
    };

    // Bonus "premier à avoir tout bon"
    if (isCorrect) {
      final doc        = await _sessions.doc(code).get();
      final qData      = doc.data()?['currentQuestionData'] as Map<String, dynamic>?;
      final alreadyWon = qData?['roundWinnerId'] != null;

      if (!alreadyWon) {
        // 🥇 Premier tout correct → +50 pts bonus
        updates['players.$playerId.score']            = FieldValue.increment(points + 50);
        updates['currentQuestionData.roundWinnerId']  = playerId;
        final playerData =
            (doc.data()?['players'] as Map<String, dynamic>?)?[playerId];
        updates['currentQuestionData.roundWinnerName'] =
            (playerData?['name'] as String?) ?? 'Joueur';
      } else {
        updates['players.$playerId.score'] = FieldValue.increment(points);
      }
    } else {
      // Pas tout correct mais des bonnes réponses → points proportionnels
      if (points > 0) {
        updates['players.$playerId.score'] = FieldValue.increment(points);
      }
    }

    await _sessions.doc(code).update(updates);
    await _endRoundIfAllCompleted(code);
  }

  Future<void> _endRoundIfAllCompleted(String code) async {
    final doc = await _sessions.doc(code).get();
    final data = doc.data();
    if (data == null) return;

    final session = Session.fromMap(data);

    if (session.state == SessionState.reviewing ||
        session.state == SessionState.finished) {
      return;
    }

    final players = session.players;
    if (players.isEmpty) return;

    final allDone = players.values.every((p) => p.roundCompleted);
    if (!allDone) return;

    await _sessions.doc(code).update({
      'state': SessionState.reviewing.name,
      'currentQuestionData.roundState': 'roundEnd',
      'currentQuestionData.reviewStartedAt': DateTime.now().toIso8601String(),
    });
  }

  // ═══════════════════════════════════════════════════════════
  // ── AUTRE JEU (exemple de structure séparée) ───────────────
  // ═══════════════════════════════════════════════════════════
  //
  // Future<Session> _createAutreJeuSession({...}) async { ... }
  // Future<void> _startAutreJeu(String code) async { ... }
  // Future<void> submitAutreJeuAnswer({...}) async { ... }

  // ═══════════════════════════════════════════════════════════
  // RÉPONSE GÉNÉRIQUE (tous jeux)
  // ═══════════════════════════════════════════════════════════

  Future<void> submitAnswer({
    required String sessionCode,
    required String playerId,
    required dynamic answer,
    required int points,
  }) async {
    if (playerId.isEmpty) {
      throw Exception('Player ID manquant pour la soumission.');
    }

    final now = DateTime.now().toIso8601String();

    await db
        .collection('sessions')
        .doc(sessionCode)
        .collection('answers')
        .add({
      'playerId': playerId,
      'answer': answer,
      'points': points,
      'submittedAt': now,
    });

    final updates = <String, dynamic>{
      'players.$playerId.roundCompleted': true,
      'players.$playerId.roundCompletedAt': now,
    };

    if (points != 0) {
      updates['players.$playerId.score'] = FieldValue.increment(points);
    }

    await _sessions.doc(sessionCode).update(updates);

    // Vérifie automatiquement si tout le monde a terminé
    await _endRoundIfAllCompleted(sessionCode);
  }

  Future<void> forceEndRound(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists) return;

    final session = Session.fromMap(doc.data()!);

    if (session.state == SessionState.reviewing ||
        session.state == SessionState.finished) {
      return;
    }

    await _sessions.doc(code).update({
      'state': SessionState.reviewing.name,
      'currentQuestionData.roundState': 'roundEnd',
      'currentQuestionData.reviewStartedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> autoAdvanceAfterReview(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists) return;

    final session = Session.fromMap(doc.data()!);

    if (session.state == SessionState.finished) return;

    if (session.currentQuestionIndex >= session.totalQuestions) {
      await endGame(code);
      return;
    }

    await drawNextQuestion(code);
  }

  // ═══════════════════════════════════════════════════════════
  // STREAMS UTILITAIRES
  // ═══════════════════════════════════════════════════════════

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBoards(String code) {
    return db
        .collection('sessions')
        .doc(code)
        .collection('boards')
        .snapshots();
  }
}