import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────
// BIBLIOTHÈQUE (index resolution)
// ─────────────────────────────────────────────────────────────

class FichePersoLibrary {
  final List<String> names;
  final List<String> locations;
  final List<String> roles;
  final List<String> historicalPeriods;
  final List<String> books;
  final List<String> symbols;
  final List<String> difficultyLevels;

  const FichePersoLibrary({
    required this.names,
    required this.locations,
    required this.roles,
    required this.historicalPeriods,
    required this.books,
    required this.symbols,
    required this.difficultyLevels,
  });

  factory FichePersoLibrary.fromJson(Map<String, dynamic> json) {
    return FichePersoLibrary(
      names:            List<String>.from(json['names']              as List),
      locations:        List<String>.from(json['locations']          as List),
      roles:            List<String>.from(json['roles']              as List),
      historicalPeriods:List<String>.from(json['historical_periods'] as List),
      books:            List<String>.from(json['books']              as List),
      symbols:          List<String>.from(json['symbols']            as List),
      difficultyLevels: List<String>.from(json['difficulty_levels']  as List),
    );
  }

  // ── Résolutions simples ───────────────────────────────────
  String resolveName(int i)       => names[i];
  String resolveLocation(int i)   => locations[i];
  String resolveRole(int i)       => roles[i];
  String resolvePeriod(int i)     => historicalPeriods[i];
  String resolveBook(int i)       => books[i];
  String resolveSymbol(int i)     => symbols[i];
  String resolveDifficulty(int i) => difficultyLevels[i];

  // ── Résolutions multiples (jointure) ─────────────────────
  String joinNames(List<int> indices) =>
      indices.map(resolveName).join(' / ');
  String joinLocations(List<int> indices) =>
      indices.map(resolveLocation).join(' / ');
  String joinRoles(List<int> indices) =>
      indices.map(resolveRole).join(' / ');
  String joinBooks(List<int> indices) =>
      indices.map(resolveBook).join(' / ');
  String joinSymbols(List<int> indices) =>
      indices.map(resolveSymbol).join(' / ');

  /// Relations → liste de noms résolus (pour les slots relation1 / relation2)
  List<String> resolveRelations(List<int> indices) =>
      indices.map(resolveName).toList();
}

// ─────────────────────────────────────────────────────────────
// MODÈLE PERSONNAGE (format plat — Firestore + gameplay)
// ─────────────────────────────────────────────────────────────

class FichePersoPersonnage extends Equatable {
  final String id;
  final String nom;
  final String? photoUrl;
  final String localisation;
  final String role;
  final String periodeHistorique;
  final List<String> relations;
  final String livreBible;
  final String symbole;
  final String evenementMarquant;
  final String difficulte;

  const FichePersoPersonnage({
    required this.id,
    required this.nom,
    this.photoUrl,
    required this.localisation,
    required this.role,
    required this.periodeHistorique,
    required this.relations,
    required this.livreBible,
    required this.symbole,
    required this.evenementMarquant,
    required this.difficulte,
  });

  // ── Désérialisation depuis Firestore (format plat) ────────
  factory FichePersoPersonnage.fromJson(Map<String, dynamic> json) {
    return FichePersoPersonnage(
      id:                json['id']                as String,
      nom:               json['nom']               as String,
      photoUrl:          json['photoUrl']           as String?,
      localisation:      json['localisation']       as String,
      role:              json['role']               as String,
      periodeHistorique: json['periodeHistorique']  as String,
      relations:         List<String>.from(json['relations'] as List),
      livreBible:        json['livreBible']         as String,
      symbole:           json['symbole']            as String,
      evenementMarquant: json['evenementMarquant']  as String,
      difficulte:        json['difficulte']         as String? ?? '',
    );
  }

  // ── Désérialisation depuis le JSON source (format indexé) ─
  factory FichePersoPersonnage.fromIndexed(
    Map<String, dynamic> json,
    FichePersoLibrary lib,
  ) {
    final nameIndices     = List<int>.from(json['name_indices']     as List);
    final locationIndices = List<int>.from(json['location_indices'] as List);
    final roleIndices     = List<int>.from(json['role_indices']     as List);
    final relationIndices = List<int>.from(json['relation_indices'] as List);
    final bookIndices     = List<int>.from(json['book_indices']     as List);
    final symbolIndices   = List<int>.from(json['symbol_indices']   as List);
    final photoUrls       = List<String>.from(json['photo_urls']    as List? ?? []);

    return FichePersoPersonnage(
      id:                json['id']             as String,
      nom:               lib.joinNames(nameIndices),
      photoUrl:          photoUrls.isNotEmpty ? photoUrls.first : null,
      localisation:      lib.joinLocations(locationIndices),
      role:              lib.joinRoles(roleIndices),
      periodeHistorique: lib.resolvePeriod(json['period_index'] as int),
      relations:         lib.resolveRelations(relationIndices),
      livreBible:        lib.joinBooks(bookIndices),
      symbole:           lib.joinSymbols(symbolIndices),
      evenementMarquant: json['key_event']      as String,
      difficulte:        lib.resolveDifficulty(json['difficulty_index'] as int),
    );
  }

  // ── Sérialisation vers Firestore (format plat) ────────────
  Map<String, dynamic> toJson() => {
    'id':                id,
    'nom':               nom,
    'photoUrl':          photoUrl,
    'localisation':      localisation,
    'role':              role,
    'periodeHistorique': periodeHistorique,
    'relations':         relations,
    'livreBible':        livreBible,
    'symbole':           symbole,
    'evenementMarquant': evenementMarquant,
    'difficulte':        difficulte,
  };

  // ── Génération des cartes mélangées ───────────────────────
  List<AttributeCard> generateCards({int duplicateFactor = 1}) {
    final cardsList = <AttributeCard>[];

    final baseCards = <AttributeCard>[
      AttributeCard(id: '${id}_nom_0',  champ: 'nom',               valeur: nom,               emoji: '📛'),
      AttributeCard(id: '${id}_loc_0',  champ: 'localisation',      valeur: localisation,      emoji: '📍'),
      AttributeCard(id: '${id}_role_0', champ: 'role',              valeur: role,              emoji: '👑'),
      AttributeCard(id: '${id}_per_0',  champ: 'periodeHistorique', valeur: periodeHistorique, emoji: '📅'),
      if (relations.isNotEmpty)
        AttributeCard(id: '${id}_r1_0', champ: 'relation1',         valeur: relations[0],      emoji: '🤝'),
      if (relations.length > 1)
        AttributeCard(id: '${id}_r2_0', champ: 'relation2',         valeur: relations[1],      emoji: '🤝'),
      AttributeCard(id: '${id}_lv_0',   champ: 'livreBible',        valeur: livreBible,        emoji: '📖'),
      AttributeCard(id: '${id}_sy_0',   champ: 'symbole',           valeur: symbole,           emoji: '🔷'),
      AttributeCard(id: '${id}_ev_0',   champ: 'evenementMarquant', valeur: evenementMarquant, emoji: '⭐'),
    ];

    for (int i = 0; i < duplicateFactor; i++) {
      for (final card in baseCards) {
        cardsList.add(AttributeCard(
          id:     '${card.id.replaceFirst('_0', '')}_$i',
          champ:  card.champ,
          valeur: card.valeur,
          emoji:  card.emoji,
        ));
      }
    }

    cardsList.shuffle();
    return cardsList;
  }

  // ── Validation de la plaquette ────────────────────────────
  ValidationResult validateBoard(Map<String, String> placements) {
    final wrong = <String>{};

    // Relations : ordre libre
    final rel1 = placements['relation1'] ?? '';
    final rel2 = placements['relation2'] ?? '';
    final expectedRels = Set<String>.from(relations.take(2));
    final placedRels   = <String>{if (rel1.isNotEmpty) rel1, if (rel2.isNotEmpty) rel2};
    if (placedRels != expectedRels) {
      if (!expectedRels.contains(rel1))           wrong.add('relation1');
      if (!expectedRels.contains(rel2) || rel2 == rel1) wrong.add('relation2');
    }

    // Champs simples
    void check(String champ, String expected) {
      if ((placements[champ] ?? '') != expected) wrong.add(champ);
    }

    check('nom',               nom);
    check('localisation',      localisation);
    check('role',              role);
    check('periodeHistorique', periodeHistorique);
    check('livreBible',        livreBible);
    check('symbole',           symbole);
    check('evenementMarquant', evenementMarquant);

    return ValidationResult(isCorrect: wrong.isEmpty, wrongSlots: wrong);
  }

  @override
  List<Object?> get props => [id];
}

// ─────────────────────────────────────────────────────────────
// CARTE ATTRIBUT (draggable)
// ─────────────────────────────────────────────────────────────

class AttributeCard extends Equatable {
  final String id;
  final String champ;
  final String valeur;
  final String emoji;

  const AttributeCard({
    required this.id,
    required this.champ,
    required this.valeur,
    required this.emoji,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'champ': champ, 'valeur': valeur, 'emoji': emoji,
  };

  factory AttributeCard.fromJson(Map<String, dynamic> j) => AttributeCard(
    id:     j['id']     as String,
    champ:  j['champ']  as String,
    valeur: j['valeur'] as String,
    emoji:  j['emoji']  as String,
  );

  @override
  List<Object?> get props => [id];
}

// ─────────────────────────────────────────────────────────────
// DÉFINITIONS DES SLOTS DE LA PLAQUETTE
// ─────────────────────────────────────────────────────────────

class SlotDef {
  final String champ;
  final String label;
  final String emoji;
  const SlotDef({required this.champ, required this.label, required this.emoji});
}

const List<SlotDef> fichePersoSlots = [
  SlotDef(champ: 'nom',               label: 'Nom',          emoji: '📛'),
  SlotDef(champ: 'localisation',      label: 'Localisation', emoji: '📍'),
  SlotDef(champ: 'role',              label: 'Rôle',         emoji: '👑'),
  SlotDef(champ: 'periodeHistorique', label: 'Période',      emoji: '📅'),
  SlotDef(champ: 'relation1',         label: 'Relation 1',   emoji: '🤝'),
  SlotDef(champ: 'relation2',         label: 'Relation 2',   emoji: '🤝'),
  SlotDef(champ: 'livreBible',        label: 'Livre',        emoji: '📖'),
  SlotDef(champ: 'symbole',           label: 'Symbole',      emoji: '🔷'),
  SlotDef(champ: 'evenementMarquant', label: 'Événement',    emoji: '⭐'),
];

// ─────────────────────────────────────────────────────────────
// RÉSULTAT DE VALIDATION
// ─────────────────────────────────────────────────────────────

class ValidationResult {
  final bool isCorrect;
  final Set<String> wrongSlots;
  const ValidationResult({required this.isCorrect, required this.wrongSlots});
}

// ─────────────────────────────────────────────────────────────
// CONFIG COMPLÈTE (chargée depuis le JSON source)
// ─────────────────────────────────────────────────────────────

class FichePersoGameConfig {
  final String langue;
  final String version;
  final int duplicateCardsPerField;
  final int reviewTimeSeconds;
  final List<FichePersoPersonnage> personnages;

  const FichePersoGameConfig({
    required this.langue,
    required this.version,
    required this.duplicateCardsPerField,
    required this.reviewTimeSeconds,
    required this.personnages,
  });

  factory FichePersoGameConfig.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    final lib  = FichePersoLibrary.fromJson(
        json['library'] as Map<String, dynamic>);

    return FichePersoGameConfig(
      langue:                meta['language']              as String,
      version:               meta['version']               as String,
      duplicateCardsPerField:(meta['duplicateCardsPerField'] as num?)?.toInt() ?? 1,
      reviewTimeSeconds:     (meta['reviewTimeSeconds']      as num?)?.toInt() ?? 45,
      personnages: (json['characters'] as List)
          .map((c) => FichePersoPersonnage.fromIndexed(
              c as Map<String, dynamic>, lib))
          .toList(),
    );
  }

  FichePersoPersonnage? findById(String id) {
    try { return personnages.firstWhere((p) => p.id == id); } catch (_) { return null; }
  }

  /// Génère une pioche mélangée (liste d'IDs)
  List<String> generatePioche() {
    final ids = personnages.map((p) => p.id).toList()..shuffle();
    return ids;
  }
}