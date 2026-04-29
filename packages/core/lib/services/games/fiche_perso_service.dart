import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/games/fiche_perso.dart';
import '../../models/session.dart';
import '../../services/json_loader.dart';

class FichePersoService {
  final FirebaseFirestore _db;
  final JsonLoader _jsonLoader;

  FichePersoService({FirebaseFirestore? db, JsonLoader? jsonLoader})
      : _db = db ?? FirebaseFirestore.instance,
        _jsonLoader = jsonLoader ?? JsonLoader();

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  Future<Session> createSession({
    required int totalQuestions,
    required int roundTimeSeconds,
    required bool sameCardForAll,
  }) async {
    final config = await _jsonLoader.loadFichePerso();
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

    // Ici, on retournerait la session, mais comme c'est séparé, peut-être retourner les data
    // Pour l'instant, gardons simple, on peut l'intégrer dans SessionService
    throw UnimplementedError('Integrate with SessionService');
  }

  // Autres méthodes spécifiques à fiche_perso
}