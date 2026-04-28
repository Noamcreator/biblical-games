// ─────────────────────────────────────────────────────────────
// ÉCRAN : FICHE PERSONNAGE
// ─────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core/core.dart';
import '_base_game_screen.dart';

class FichePersoScreen extends StatelessWidget {
  final String sessionCode;
  const FichePersoScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '👤 Fiche Personnage',
      questionBuilder: (data) => _FichePersoGame(
        data: data,
        sessionCode: sessionCode,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// JEU PRINCIPAL
// ─────────────────────────────────────────────────────────────

class _FichePersoGame extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sessionCode;

  const _FichePersoGame({
    required this.data,
    required this.sessionCode,
  });

  @override
  State<_FichePersoGame> createState() => _FichePersoGameState();
}

enum GamePhase { playing, review, transition }

class _FichePersoGameState extends State<_FichePersoGame>
    with TickerProviderStateMixin {
  final Map<String, AttributeCard> _placedCards = {};
  bool _isSubmitting = false;
  GamePhase _phase = GamePhase.playing;
  Timer? _autoTransitionTimer;
  late AnimationController _fadeController;
  int _reviewCountdown = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _autoTransitionTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _placeCard(String champ, AttributeCard card) {
    setState(() {
      _placedCards.removeWhere((_, placed) => placed.id == card.id);
      _placedCards[champ] = card;
    });
  }

  void _removeCard(String champ) {
    setState(() {
      _placedCards.remove(champ);
    });
  }

  Future<void> _submit(FichePersoQuestion question) async {
    setState(() => _isSubmitting = true);

    final placements = <String, String>{};
    for (final visible in question.champsVisibles) {
      placements[visible] = question.expectedValue(visible);
    }
    for (final card in question.cards) {
      placements[card.champ] = _placedCards[card.champ]?.valeur ?? '';
    }

    final result = question.fiche.validateBoard(placements);
    final service = SessionService();
    await service.submitFicheBoard(
      code: widget.sessionCode,
      playerId: service.currentUid ?? '',
      placements: placements,
      isCorrect: result.isCorrect,
    );

    setState(() => _isSubmitting = false);

    // Afficher mode review
    _startReviewPhase(question, result);
  }

  void _startReviewPhase(FichePersoQuestion question, ValidationResult result) {
    setState(() {
      _phase = GamePhase.review;
      _reviewCountdown = 15;
    });
    _fadeController.forward();

    // Auto-transition après le temps de révision
    _autoTransitionTimer?.cancel();
    _autoTransitionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _reviewCountdown--);
      }
      if (_reviewCountdown <= 0) {
        timer.cancel();
        _nextRound();
      }
    });
  }

  void _nextRound() {
    final service = SessionService();
    service.drawNextPersonnage(widget.sessionCode);
  }

  @override
  Widget build(BuildContext context) {
    final question = FichePersoQuestion.fromMap(widget.data);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_phase == GamePhase.playing) {
      return _buildPlayingPhase(context, question, isMobile);
    } else {
      return _buildReviewPhase(context, question, isMobile);
    }
  }

  Widget _buildPlayingPhase(
    BuildContext context,
    FichePersoQuestion question,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre et infos
            _buildHeaderSection(context, question),
            const SizedBox(height: 24),

            // Plaquette (board)
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FichePersoBoard(
                        question: question,
                        placedCards: _placedCards,
                        onRemoveCard: _removeCard,
                        onPlaceCard: _placeCard,
                      ),
                      const SizedBox(height: 24),
                      _buildCardsPanel(
                        context,
                        question,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _FichePersoBoard(
                          question: question,
                          placedCards: _placedCards,
                          onRemoveCard: _removeCard,
                          onPlaceCard: _placeCard,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: _buildCardsPanel(context, question),
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // Bouton soumettre
            if (!_isSubmitting)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _allFieldsFilled(question)
                      ? () => _submit(question)
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Valider la plaquette'),
                ),
              )
            else
              const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewPhase(
    BuildContext context,
    FichePersoQuestion question,
    bool isMobile,
  ) {
    return FadeTransition(
      opacity: _fadeController,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre et infos
              _buildHeaderSection(context, question),
              const SizedBox(height: 24),

              // Afficher la plaquette avec les réponses
              _FichePersoReviewBoard(
                question: question,
                placedCards: _placedCards,
              ),

              const SizedBox(height: 24),

              // Message de révision
              Center(
                child: Column(
                  children: [
                    Text(
                      'Passage à la suite dans $_reviewCountdown s.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: 1 - (_reviewCountdown / 15),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, FichePersoQuestion question) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.fiche.nom,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (question.champsVisibles.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Indices visibles',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: question.champsVisibles.map((field) {
                      return Chip(
                        label: Text(
                          '${question.labelForChamp(field)}: ${question.expectedValue(field)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsPanel(
    BuildContext context,
    FichePersoQuestion question,
  ) {
    final placedIds = _placedCards.values.map((card) => card.id).toSet();
    final availableCards = question.cards
        .where((card) => !placedIds.contains(card.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cartes à placer',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (availableCards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('Toutes les cartes sont placées !',
                      textAlign: TextAlign.center),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableCards.map((card) {
                  return Draggable<AttributeCard>(
                    data: card,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _CardTile(card: card, isDragging: true),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: _CardTile(card: card),
                    ),
                    child: _CardTile(card: card),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  bool _allFieldsFilled(FichePersoQuestion question) {
    for (final card in question.cards) {
      if (!_placedCards.containsKey(card.champ)) {
        return false;
      }
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────
// PLAQUETTE POUR LE PLAYING
// ─────────────────────────────────────────────────────────────

class _FichePersoBoard extends StatelessWidget {
  final FichePersoQuestion question;
  final Map<String, AttributeCard> placedCards;
  final Function(String) onRemoveCard;
  final Function(String, AttributeCard) onPlaceCard;

  const _FichePersoBoard({
    required this.question,
    required this.placedCards,
    required this.onRemoveCard,
    required this.onPlaceCard,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complète la plaquette',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: fichePersoSlots
                  .where((slot) =>
                      question.champsVisibles.contains(slot.champ) ||
                      question.cards.any((card) => card.champ == slot.champ))
                  .map((slot) {
                final isVisible = question.champsVisibles.contains(slot.champ);
                final placedCard = placedCards[slot.champ];
                final value = question.expectedValue(slot.champ);

                return _SlotWidget(
                  slot: slot,
                  isVisible: isVisible,
                  placedCard: placedCard,
                  value: value,
                  onRemoveCard: onRemoveCard,
                  onPlaceCard: onPlaceCard,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SLOT INDIVIDUEL
// ─────────────────────────────────────────────────────────────

class _SlotWidget extends StatelessWidget {
  final SlotDef slot;
  final bool isVisible;
  final AttributeCard? placedCard;
  final String value;
  final Function(String) onRemoveCard;
  final Function(String, AttributeCard) onPlaceCard;

  const _SlotWidget({
    required this.slot,
    required this.isVisible,
    required this.placedCard,
    required this.value,
    required this.onRemoveCard,
    required this.onPlaceCard,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${slot.emoji} ${slot.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (isVisible)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const Spacer(),
                      const Chip(label: Text('Visible'), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ],
                  ),
                )
              else
                Expanded(
                  child: DragTarget<AttributeCard>(
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        decoration: BoxDecoration(
                          color: placedCard != null
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: candidateData.isNotEmpty
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: candidateData.isNotEmpty ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: placedCard != null
                            ? Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      placedCard!.valeur,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: GestureDetector(
                                      onTap: () => onRemoveCard(slot.champ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: Text(
                                  'Dépose\nune carte',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      );
                    },
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (details) =>
                        onPlaceCard(slot.champ, details.data),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PLAQUETTE POUR LA RÉVISION
// ─────────────────────────────────────────────────────────────

class _FichePersoReviewBoard extends StatelessWidget {
  final FichePersoQuestion question;
  final Map<String, AttributeCard> placedCards;

  const _FichePersoReviewBoard({
    required this.question,
    required this.placedCards,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Correction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: fichePersoSlots
                  .where((slot) =>
                      question.champsVisibles.contains(slot.champ) ||
                      question.cards.any((card) => card.champ == slot.champ))
                  .map((slot) {
                final isVisible = question.champsVisibles.contains(slot.champ);
                final placedCard = placedCards[slot.champ];
                final expected = question.expectedValue(slot.champ);
                final isCorrect = placedCard?.valeur == expected || isVisible;

                return _ReviewSlotWidget(
                  slot: slot,
                  isVisible: isVisible,
                  placedCard: placedCard,
                  expected: expected,
                  isCorrect: isCorrect,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SLOT RÉVISION
// ─────────────────────────────────────────────────────────────

class _ReviewSlotWidget extends StatelessWidget {
  final SlotDef slot;
  final bool isVisible;
  final AttributeCard? placedCard;
  final String expected;
  final bool isCorrect;

  const _ReviewSlotWidget({
    required this.slot,
    required this.isVisible,
    required this.placedCard,
    required this.expected,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    slot.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      slot.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Réponse : $expected',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              if (placedCard != null && !isVisible)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Tu as : ${placedCard!.valeur}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TUILE DE CARTE
// ─────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final AttributeCard card;
  final bool isDragging;

  const _CardTile({
    required this.card,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDragging ? Colors.blue.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDragging ? Colors.blue : Colors.grey.shade300,
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? const [BoxShadow(color: Colors.black12, blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(card.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            card.valeur,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODÈLES ET HELPERS
// ─────────────────────────────────────────────────────────────

class FichePersoQuestion {
  final FichePersoPersonnage fiche;
  final List<String> champsVisibles;
  final List<AttributeCard> cards;
  final int pointsMax;

  FichePersoQuestion({
    required this.fiche,
    required this.champsVisibles,
    required this.cards,
    required this.pointsMax,
  });

  factory FichePersoQuestion.fromMap(Map<String, dynamic> map) {
    final ficheData = map['fiche'] as Map<String, dynamic>?;
    final fiche = ficheData != null
        ? FichePersoPersonnage.fromJson(ficheData)
        : const FichePersoPersonnage(
            id: '',
            nom: 'Personnage inconnu',
            localisation: 'Inconnu',
            role: 'Inconnu',
            periodeHistorique: 'Inconnu',
            relations: [],
            livreBible: 'Inconnu',
            symbole: 'Inconnu',
            evenementMarquant: 'Inconnu',
          );

    return FichePersoQuestion(
      fiche: fiche,
      champsVisibles: List<String>.from(map['champsVisibles'] as List? ?? []),
      cards: (map['cards'] as List? ?? [])
          .map((item) => AttributeCard.fromJson(
              Map<String, dynamic>.from(item as Map<String, dynamic>)))
          .toList(),
      pointsMax: (map['pointsMax'] as num?)?.toInt() ?? 100,
    );
  }

  String expectedValue(String champ) {
    return switch (champ) {
      'nom' => fiche.nom,
      'localisation' => fiche.localisation,
      'role' => fiche.role,
      'periodeHistorique' => fiche.periodeHistorique,
      'livreBible' => fiche.livreBible,
      'symbole' => fiche.symbole,
      'evenementMarquant' => fiche.evenementMarquant,
      'qualite' => fiche.qualite ?? '',
      'defaut' => fiche.defaut ?? '',
      'relation1' => fiche.relations.isNotEmpty ? fiche.relations[0] : '',
      'relation2' => fiche.relations.length > 1 ? fiche.relations[1] : '',
      _ => '',
    };
  }

  String labelForChamp(String champ) {
    return switch (champ) {
      'nom' => 'Nom',
      'localisation' => 'Lieu',
      'role' => 'Rôle',
      'periodeHistorique' => 'Période',
      'livreBible' => 'Livre',
      'symbole' => 'Symbole',
      'evenementMarquant' => 'Événement',
      'qualite' => 'Qualité',
      'defaut' => 'Défaut',
      'relation1' => 'Relation 1',
      'relation2' => 'Relation 2',
      _ => champ,
    };
  }
}

