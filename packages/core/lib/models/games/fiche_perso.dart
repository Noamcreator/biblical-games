import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────
// MODÈLE PERSONNAGE
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
  final String? qualite;
  final String? defaut;

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
    this.qualite,
    this.defaut,
  });

  factory FichePersoPersonnage.fromJson(Map<String, dynamic> json) {
    return FichePersoPersonnage(
      id: json['id'] as String,
      nom: json['nom'] as String,
      photoUrl: json['photoUrl'] as String?,
      localisation: json['localisation'] as String,
      role: json['role'] as String,
      periodeHistorique: json['periodeHistorique'] as String,
      relations: List<String>.from(json['relations'] as List),
      livreBible: json['livreBible'] as String,
      symbole: json['symbole'] as String,
      evenementMarquant: json['evenementMarquant'] as String,
      qualite: json['qualite'] as String?,
      defaut: json['defaut'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'photoUrl': photoUrl,
        'localisation': localisation,
        'role': role,
        'periodeHistorique': periodeHistorique,
        'relations': relations,
        'livreBible': livreBible,
        'symbole': symbole,
        'evenementMarquant': evenementMarquant,
        'qualite': qualite,
        'defaut': defaut,
      };

  /// Génère les cartes attributs mélangées pour ce personnage avec duplication optionnelle
  List<AttributeCard> generateCards({int duplicateFactor = 1}) {
    final cardsList = <AttributeCard>[];
    
    final baseCards = <AttributeCard>[
      AttributeCard(id: '${id}_nom_0', champ: 'nom', valeur: nom, emoji: '📛'),
      AttributeCard(id: '${id}_loc_0', champ: 'localisation', valeur: localisation, emoji: '📍'),
      AttributeCard(id: '${id}_role_0', champ: 'role', valeur: role, emoji: '👑'),
      AttributeCard(id: '${id}_per_0', champ: 'periodeHistorique', valeur: periodeHistorique, emoji: '📅'),
      if (relations.isNotEmpty)
        AttributeCard(id: '${id}_r1_0', champ: 'relation1', valeur: relations[0], emoji: '🤝'),
      if (relations.length > 1)
        AttributeCard(id: '${id}_r2_0', champ: 'relation2', valeur: relations[1], emoji: '🤝'),
      AttributeCard(id: '${id}_lv_0', champ: 'livreBible', valeur: livreBible, emoji: '📖'),
      AttributeCard(id: '${id}_sy_0', champ: 'symbole', valeur: symbole, emoji: '🔷'),
      AttributeCard(id: '${id}_ev_0', champ: 'evenementMarquant', valeur: evenementMarquant, emoji: '⭐'),
      if (qualite != null)
        AttributeCard(id: '${id}_ql_0', champ: 'qualite', valeur: qualite!, emoji: '😇'),
      if (defaut != null)
        AttributeCard(id: '${id}_df_0', champ: 'defaut', valeur: defaut!, emoji: '😈'),
    ];
    
    // Ajouter les cartes avec duplication
    for (int i = 0; i < duplicateFactor; i++) {
      for (final card in baseCards) {
        cardsList.add(AttributeCard(
          id: '${card.id.replaceFirst('_0', '')}_$i',
          champ: card.champ,
          valeur: card.valeur,
          emoji: card.emoji,
        ));
      }
    }
    
    cardsList.shuffle();
    return cardsList;
  }

  /// Valide toute la plaquette et retourne les erreurs
  ValidationResult validateBoard(Map<String, String> placements) {
    final wrong = <String>{};

    // Relations : les deux slots doivent contenir les deux relations (ordre libre)
    final rel1 = placements['relation1'] ?? '';
    final rel2 = placements['relation2'] ?? '';
    final expectedRels = Set<String>.from(relations.take(2));
    final placedRels = <String>{if (rel1.isNotEmpty) rel1, if (rel2.isNotEmpty) rel2};
    if (placedRels != expectedRels) {
      if (!expectedRels.contains(rel1)) wrong.add('relation1');
      if (!expectedRels.contains(rel2) || rel2 == rel1) wrong.add('relation2');
    }

    // Champs simples
    void check(String champ, String? expected) {
      if (expected == null) return;
      if ((placements[champ] ?? '') != expected) wrong.add(champ);
    }

    check('nom', nom);
    check('localisation', localisation);
    check('role', role);
    check('periodeHistorique', periodeHistorique);
    check('livreBible', livreBible);
    check('symbole', symbole);
    check('evenementMarquant', evenementMarquant);
    check('qualite', qualite);
    check('defaut', defaut);

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
        id: j['id'] as String,
        champ: j['champ'] as String,
        valeur: j['valeur'] as String,
        emoji: j['emoji'] as String,
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
  final bool isBonus;
  const SlotDef({required this.champ, required this.label, required this.emoji, this.isBonus = false});
}

const List<SlotDef> fichePersoSlots = [
  SlotDef(champ: 'nom',               label: 'Nom',             emoji: '📛'),
  SlotDef(champ: 'localisation',      label: 'Localisation',    emoji: '📍'),
  SlotDef(champ: 'role',              label: 'Rôle',            emoji: '👑'),
  SlotDef(champ: 'periodeHistorique', label: 'Période',         emoji: '📅'),
  SlotDef(champ: 'relation1',         label: 'Relation 1',      emoji: '🤝'),
  SlotDef(champ: 'relation2',         label: 'Relation 2',      emoji: '🤝'),
  SlotDef(champ: 'livreBible',        label: 'Livre',           emoji: '📖'),
  SlotDef(champ: 'symbole',           label: 'Symbole',         emoji: '🔷'),
  SlotDef(champ: 'evenementMarquant', label: 'Événement',       emoji: '⭐'),
  SlotDef(champ: 'qualite',           label: 'Qualité (bonus)', emoji: '😇', isBonus: true),
  SlotDef(champ: 'defaut',            label: 'Défaut (bonus)',  emoji: '😈', isBonus: true),
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
// CONFIG COMPLÈTE (chargée depuis JSON)
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
    return FichePersoGameConfig(
      langue: meta['langue'] as String,
      version: meta['version'] as String,
      duplicateCardsPerField: (meta['duplicateCardsPerField'] as num?)?.toInt() ?? 1,
      reviewTimeSeconds: (meta['reviewTimeSeconds'] as num?)?.toInt() ?? 45,
      personnages: (json['personnages'] as List)
          .map((p) => FichePersoPersonnage.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  FichePersoPersonnage? findById(String id) {
    try { return personnages.firstWhere((p) => p.id == id); } catch (_) { return null; }
  }

  /// Génère une pioche mélangée (liste d'IDs des personnages)
  List<String> generatePioche() {
    final ids = personnages.map((p) => p.id).toList()..shuffle();
    return ids;
  }
}