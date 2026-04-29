// ─────────────────────────────────────────────────────────────
// ÉCRAN : FICHE PERSONNAGE — Redesign complet
// • Affiche centrale avec tous les slots
// • Cartes groupées par catégorie (N par catégorie selon param)
// • Drag & drop + tap-to-place
// • Timer visuel + auto-submit
// • Design Indigo/Bleu, mobile-first, glassmorphism
// ─────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:core/core.dart';
import '_base_game_screen.dart';

// ─────────────────────────────────────────────────────────────
// CONSTANTE : Nombre de cartes PAR CATÉGORIE (dont 1 correcte)
// ─────────────────────────────────────────────────────────────
const int kCardsPerCategory = 4;

// ─────────────────────────────────────────────────────────────
// ENTRÉE DE L'ÉCRAN
// ─────────────────────────────────────────────────────────────

class FichePersoScreen extends StatelessWidget {
  final String sessionCode;
  const FichePersoScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode:     sessionCode,
      gameTitle:       '👤 Fiche Personnage',
      questionBuilder: (data) => _FichePersoGame(
        data:        data,
        sessionCode: sessionCode,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// JEU PRINCIPAL
// ─────────────────────────────────────────────────────────────

enum _Phase { playing, review }

class _FichePersoGame extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sessionCode;
  const _FichePersoGame({required this.data, required this.sessionCode});

  @override
  State<_FichePersoGame> createState() => _FichePersoGameState();
}

class _FichePersoGameState extends State<_FichePersoGame>
    with TickerProviderStateMixin {

  // ── État ────────────────────────────────────────────────
  final Map<String, String> _placed = {}; // champ → valeur placée
  String? _selectedCategory;              // catégorie active dans le panneau
  bool    _hasSubmitted = false;
  bool    _isSubmitting = false;
  _Phase  _phase        = _Phase.playing;

  // ── Timers ──────────────────────────────────────────────
  int    _roundSeconds  = 0;
  int    _reviewSeconds = 0;
  Timer? _roundTimer;
  Timer? _reviewTimer;

  // ── Animations ──────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _timerCtrl;

  // ── Question parsée ─────────────────────────────────────
  late FichePersoQuestion _question;

  // ── Couleurs ────────────────────────────────────────────
  static const _primaryBlue   = Color(0xFF3949AB); // indigo700
  static const _secondaryBlue = Color(0xFF1E88E5); // blue600
  static const _accentCyan    = Color(0xFF26C6DA); // cyan400

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _timerCtrl = AnimationController(duration: const Duration(seconds: 1),        vsync: this);
    _question  = _parseQuestion();
    _startRound();
  }

  @override
  void didUpdateWidget(covariant _FichePersoGame old) {
    super.didUpdateWidget(old);

    final oldRoundId = old.data['currentPersonnageId'] as String?;
    final newRoundId = widget.data['currentPersonnageId'] as String?;
    final oldRoundNumber = (old.data['roundNumber'] as num?)?.toInt() ?? 0;
    final newRoundNumber = (widget.data['roundNumber'] as num?)?.toInt() ?? 0;
    final oldRoundState = old.data['roundState'] as String? ?? 'idle';
    final newRoundState = widget.data['roundState'] as String? ?? 'idle';

    if (oldRoundId != newRoundId || oldRoundNumber != newRoundNumber) {
      _question = _parseQuestion();
      _resetRound();
      return;
    }

    if (oldRoundState != newRoundState) {
      if (newRoundState == 'roundEnd' && _phase == _Phase.playing) {
        _roundTimer?.cancel();
        setState(() {
          _hasSubmitted = true;
        });
        _enterReview(_question.fiche.validateBoard(_buildPlacements()));
      }
      if (newRoundState == 'playing' && _phase == _Phase.review) {
        _question = _parseQuestion();
        _resetRound();
      }
    }
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _reviewTimer?.cancel();
    _fadeCtrl.dispose();
    _timerCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // PARSING — génère les cartes par catégorie depuis le JSON
  // ─────────────────────────────────────────────────────────

  FichePersoQuestion _parseQuestion() {
    return FichePersoQuestion.fromMap(
      widget.data,
      playerId: SessionService().currentUid,
      cardsPerCategory: kCardsPerCategory,
    );
  }

  // ─────────────────────────────────────────────────────────
  // GESTION DU ROUND
  // ─────────────────────────────────────────────────────────

  void _startRound() {
    final secs = _question.roundTimeSeconds;
    setState(() {
      _roundSeconds = secs;
      _phase        = _Phase.playing;
      _hasSubmitted = false;
      _placed.clear();
      _selectedCategory = _question.categoryGroups.isNotEmpty
          ? _question.categoryGroups.keys.first
          : null;
    });
    _timerCtrl.duration = Duration(seconds: secs);
    _timerCtrl.forward(from: 0);

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _roundSeconds--);
      if (_roundSeconds <= 0) {
        t.cancel();
        _autoSubmit();
      }
    });
  }

  void _resetRound() {
    _roundTimer?.cancel();
    _reviewTimer?.cancel();
    _fadeCtrl.reset();
    _startRound();
  }

  void _autoSubmit() async {
    if (_hasSubmitted || _phase != _Phase.playing) return;
    _roundTimer?.cancel();
    setState(() { _hasSubmitted = true; });
    await _doSubmit();
  }

  Future<void> _submit() async {
    if (_hasSubmitted) return;
    _roundTimer?.cancel();
    _timerCtrl.stop();
    setState(() { _hasSubmitted = true; _isSubmitting = true; });
    await _doSubmit();
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _doSubmit() async {
    final placements = _buildPlacements();
    final result     = _question.fiche.validateBoard(placements);
    final points     = _computePoints(result);
    final service    = SessionService();
    final uid        = service.currentUid ?? '';
    if (uid.isNotEmpty) {
      await service.submitFicheBoard(
        code:       widget.sessionCode,
        playerId:   uid,
        placements: placements,
        isCorrect:  result.isCorrect,
        points:     points,
      );
    }
    _enterReview(result);
  }

  int _computePoints(ValidationResult result) {
    final activeSlots = fichePersoSlots
        .where((slot) => _question.isActiveSlot(slot.champ) && !_question.champsVisibles.contains(slot.champ))
        .length;
    final correctCount = activeSlots - result.wrongSlots.length;
    final basePoints = correctCount * 10;
    final bonus = result.isCorrect ? 20 : 0;
    final timeBonus = (_roundSeconds > 0 ? _roundSeconds : 0).clamp(0, 20);
    return basePoints + bonus + timeBonus;
  }

  Map<String, String> _buildPlacements() {
    final m = <String, String>{};
    for (final vis in _question.champsVisibles) {
      m[vis] = _question.expectedValue(vis);
    }
    for (final slot in fichePersoSlots) {
      if (!_question.champsVisibles.contains(slot.champ)) {
        m[slot.champ] = _placed[slot.champ] ?? '';
      }
    }
    return m;
  }

  void _enterReview(ValidationResult result) {
    _roundTimer?.cancel();
    final secs = _question.reviewTimeSeconds;
    setState(() {
      _phase        = _Phase.review;
      _reviewSeconds = secs;
    });
    _fadeCtrl.forward(from: 0);
    _reviewTimer?.cancel();
    _reviewTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _reviewSeconds--);
      if (_reviewSeconds <= 0) {
        t.cancel();
        SessionService().drawNextPersonnage(widget.sessionCode);
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // INTERACTION CARTES
  // ─────────────────────────────────────────────────────────

  void _placeCard(String champ, String valeur) {
    setState(() {
      // Enlever cette valeur d'un autre slot si déjà placée
      _placed.removeWhere((_, v) => v == valeur);
      _placed[champ] = valeur;
    });
  }

  void _removeCard(String champ) => setState(() => _placed.remove(champ));

  bool _isPlaced(String valeur) => _placed.values.contains(valeur);

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.review) return _buildReview();
    return _buildPlaying();
  }

  // ── Phase JEU ───────────────────────────────────────────

  Widget _buildPlaying() {
    final total = _question.roundTimeSeconds;
    final ratio = total > 0 ? _roundSeconds / total : 0.0;
    final isLow = _roundSeconds <= 10;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = constraints.maxWidth > 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Timer ──────────────────────────────────────────
            _TimerBar(seconds: _roundSeconds, ratio: ratio.clamp(0, 1), isLow: isLow),

            const SizedBox(height: 10),

            if (useSplitLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _CharacterSummary(
                      question: _question,
                      placed: _placed,
                      onRemove: _removeCard,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _CategoryAccordion(
                      question: _question,
                      selectedCategory: _selectedCategory,
                      onCategoryChange: (cat) => setState(() => _selectedCategory = cat),
                      isPlaced: _isPlaced,
                      onPlace: (valeur) {
                        final champ = _question.categoryToChamp(_selectedCategory ?? '');
                        if (champ != null) _placeCard(champ, valeur);
                      },
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CharacterSummary(
                    question: _question,
                    placed: _placed,
                    onRemove: _removeCard,
                  ),
                  const SizedBox(height: 16),
                  _CategoryAccordion(
                    question: _question,
                    selectedCategory: _selectedCategory,
                    onCategoryChange: (cat) => setState(() => _selectedCategory = cat),
                    isPlaced: _isPlaced,
                    onPlace: (valeur) {
                      final champ = _question.categoryToChamp(_selectedCategory ?? '');
                      if (champ != null) _placeCard(champ, valeur);
                    },
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // ── Bouton valider ─────────────────────────────────
            _SubmitButton(
              allFilled: _allFilled(),
              isSubmitting: _isSubmitting,
              hasSubmitted: _hasSubmitted,
              onTap: _submit,
            ),

            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  bool _allFilled() {
    for (final slot in fichePersoSlots) {
      if (!_question.champsVisibles.contains(slot.champ) &&
          _question.isActiveSlot(slot.champ) &&
          !_placed.containsKey(slot.champ)) return false;
    }
    return true;
  }

  // ── Phase RÉVISION ──────────────────────────────────────

  Widget _buildReview() {
    final ratio = _question.reviewTimeSeconds > 0
        ? _reviewSeconds / _question.reviewTimeSeconds
        : 0.0;

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timer révision
          _TimerBar(
            seconds: _reviewSeconds,
            ratio:   ratio.clamp(0, 1),
            isLow:   false,
            label:   'Correction dans',
            color:   Colors.green,
          ),
          const SizedBox(height: 10),

          // Affiche correction
          _ReviewBoard(question: _question, placed: _placed),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Prochaine manche dans $_reviewSeconds s.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TIMER BAR
// ─────────────────────────────────────────────────────────────

class _TimerBar extends StatelessWidget {
  final int    seconds;
  final double ratio;
  final bool   isLow;
  final String label;
  final Color? color;

  const _TimerBar({
    required this.seconds,
    required this.ratio,
    required this.isLow,
    this.label       = 'Temps restant',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? (isLow ? Colors.redAccent : Colors.white);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(
                isLow ? Icons.timer_off_rounded : Icons.timer_rounded,
                color: barColor, size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11, fontWeight: FontWeight.w600,
                        )),
                        Text(
                          '$seconds s',
                          style: TextStyle(
                            color: barColor, fontSize: 13, fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           ratio,
                        minHeight:       5,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:      AlwaysStoppedAnimation(barColor),
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
}

// ─────────────────────────────────────────────────────────────
// AFFICHE CENTRALE (phase jeu)
// ─────────────────────────────────────────────────────────────

class _CharacterBoard extends StatelessWidget {
  final FichePersoQuestion          question;
  final Map<String, String>         placed;
  final void Function(String, String) onPlace;
  final void Function(String)       onRemove;

  const _CharacterBoard({
    required this.question,
    required this.placed,
    required this.onPlace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.15),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre personnage (toujours visible)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        const Color(0xFF3949AB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF3949AB), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fiche Personnage', style: TextStyle(
                          fontSize: 11, color: Color(0xFF7986CB), fontWeight: FontWeight.w600,
                        )),
                        Text(
                          question.fiche.nom,
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF283593),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Difficulté
                  _DifficultyBadge(difficulte: question.fiche.difficulte),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Grille des slots
              Wrap(
                spacing:    10,
                runSpacing: 10,
                children: fichePersoSlots
                    .where((s) => question.isActiveSlot(s.champ))
                    .map((slot) => _BoardSlot(
                          slot:        slot,
                          isVisible:   question.champsVisibles.contains(slot.champ),
                          visibleVal:  question.expectedValue(slot.champ),
                          placedVal:   placed[slot.champ],
                          onRemove:    () => onRemove(slot.champ),
                          onDrop:      (val) => onPlace(slot.champ, val),
                          category:    question.champToCategory(slot.champ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SLOT DE L'AFFICHE
// ─────────────────────────────────────────────────────────────

class _BoardSlot extends StatelessWidget {
  final SlotDef   slot;
  final bool      isVisible;
  final String    visibleVal;
  final String?   placedVal;
  final String    category;
  final VoidCallback        onRemove;
  final void Function(String) onDrop;

  const _BoardSlot({
    required this.slot,
    required this.isVisible,
    required this.visibleVal,
    required this.placedVal,
    required this.category,
    required this.onRemove,
    required this.onDrop,
  });

  Color get _catColor {
    final colors = {
      'nom':               const Color(0xFF1565C0),
      'localisation':      const Color(0xFF2E7D32),
      'role':              const Color(0xFF6A1B9A),
      'periodeHistorique': const Color(0xFF00695C),
      'livreBible':        const Color(0xFFE65100),
      'symbole':           const Color(0xFF558B2F),
      'evenementMarquant': const Color(0xFFC62828),
      'relation1':         const Color(0xFF4527A0),
      'relation2':         const Color(0xFF4527A0),
    };
    return colors[slot.champ] ?? const Color(0xFF3949AB);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final slotW   = (screenW - 16 * 2 - 16 * 2 - 10) / 2; // 2 colonnes

    return SizedBox(
      width: slotW,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (_) => !isVisible,
        onAcceptWithDetails:     (d) => onDrop(d.data),
        builder: (_, candidates, __) {
          final isHovered = candidates.isNotEmpty;
          final filled    = isVisible || placedVal != null;

          return GestureDetector(
            onTap: placedVal != null ? onRemove : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isVisible
                    ? _catColor.withOpacity(0.08)
                    : isHovered
                        ? _catColor.withOpacity(0.12)
                        : placedVal != null
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isVisible
                      ? _catColor.withOpacity(0.3)
                      : isHovered
                          ? _catColor
                          : placedVal != null
                              ? Colors.green.shade300
                              : Colors.grey.shade200,
                  width: isHovered ? 2 : 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  Row(children: [
                    Text(slot.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(slot.label, style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700,
                        color: _catColor,
                      ), overflow: TextOverflow.ellipsis),
                    ),
                    if (placedVal != null && !isVisible)
                      GestureDetector(
                        onTap: onRemove,
                        child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade400),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  // Valeur
                  Text(
                    isVisible
                        ? visibleVal
                        : placedVal ?? (isHovered ? 'Déposer ici' : '— vide —'),
                    style: TextStyle(
                      fontSize:   12,
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
                      color:      filled
                          ? (isVisible ? _catColor : Colors.green.shade700)
                          : Colors.grey.shade400,
                      fontStyle: (!filled && !isHovered) ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isVisible)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        _catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Indice', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: _catColor,
                        )),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ONGLETS CATÉGORIES
// ─────────────────────────────────────────────────────────────

class _CategoryTabs extends StatelessWidget {
  final List<String>            categories;
  final String?                 selected;
  final void Function(String)   onSelect;
  final Map<String, CategoryMeta> categoryMeta;

  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.categoryMeta,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:       categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat      = categories[i];
          final meta     = categoryMeta[cat];
          final isActive = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        isActive ? Colors.white : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(22),
                border:       Border.all(
                  color: isActive ? Colors.transparent : Colors.white.withOpacity(0.25),
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(meta?.emoji ?? '📌', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    meta?.label ?? cat,
                    style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      isActive ? const Color(0xFF3949AB) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RANGÉE DE CARTES (catégorie sélectionnée)
// ─────────────────────────────────────────────────────────────

class _CardsRow extends StatelessWidget {
  final List<CardOption>          cards;
  final bool Function(String)     isPlaced;
  final void Function(String)     onPlace;

  const _CardsRow({
    required this.cards,
    required this.isPlaced,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:       cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final card    = cards[i];
          final placed  = isPlaced(card.valeur);
          return Draggable<String>(
            data:              card.valeur,
            feedback:          Material(
              color: Colors.transparent,
              child: _CardChip(card: card, isPlaced: false, isDragging: true),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: _CardChip(card: card, isPlaced: placed)),
            child: GestureDetector(
              onTap: placed ? null : () => onPlace(card.valeur),
              child: _CardChip(card: card, isPlaced: placed),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryAccordion extends StatelessWidget {
  final FichePersoQuestion question;
  final String? selectedCategory;
  final void Function(String) onCategoryChange;
  final bool Function(String) isPlaced;
  final void Function(String) onPlace;

  const _CategoryAccordion({
    required this.question,
    required this.selectedCategory,
    required this.onCategoryChange,
    required this.isPlaced,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    final entries = question.categoryGroups.entries.toList();
    return ExpansionPanelList.radio(
      elevation: 0,
      expandedHeaderPadding: EdgeInsets.zero,
      initialOpenPanelValue: selectedCategory,
      children: entries.map((entry) {
        final category = entry.key;
        final cards = entry.value;
        final meta = question.categoryMeta[category];
        return ExpansionPanelRadio(
          value: category,
          headerBuilder: (context, isExpanded) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: Text(meta?.emoji ?? '📌', style: const TextStyle(fontSize: 20)),
              title: Text(meta?.label ?? category, style: const TextStyle(fontWeight: FontWeight.w700)),
            );
          },
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cards.map((card) {
                return GestureDetector(
                  onTap: isPlaced(card.valeur) ? null : () => onPlace(card.valeur),
                  child: _CardChip(card: card, isPlaced: isPlaced(card.valeur)),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
      expansionCallback: (index, isExpanded) {
        onCategoryChange(entries[index].key);
      },
    );
  }
}

class _CharacterSummary extends StatelessWidget {
  final FichePersoQuestion      question;
  final Map<String, String>     placed;
  final void Function(String)   onRemove;

  const _CharacterSummary({
    required this.question,
    required this.placed,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3949AB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF3949AB), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question.fiche.nom,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF283593)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'Lieu', value: question.fiche.localisation),
              _InfoRow(label: 'Rôle', value: question.fiche.role),
              _InfoRow(label: 'Période', value: question.fiche.periodeHistorique),
              const SizedBox(height: 16),
              Text('Réponses placées', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fichePersoSlots
                    .where((slot) => !question.champsVisibles.contains(slot.champ) && question.isActiveSlot(slot.champ))
                    .map((slot) {
                  final value = placed[slot.champ];
                  return Chip(
                    label: Text(value ?? slot.label, overflow: TextOverflow.ellipsis),
                    backgroundColor: value != null ? Colors.green.shade50 : Colors.grey.shade100,
                    deleteIcon: value != null ? const Icon(Icons.close, size: 16) : null,
                    onDeleted: value != null ? () => onRemove(slot.champ) : null,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  final CardOption card;
  final bool       isPlaced;
  final bool       isDragging;

  const _CardChip({required this.card, required this.isPlaced, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isPlaced
            ? Colors.grey.shade200
            : isDragging
                ? Colors.white
                : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isPlaced
              ? Colors.grey.shade300
              : isDragging
                  ? const Color(0xFF3949AB)
                  : const Color(0xFF3949AB).withOpacity(0.4),
          width: isDragging ? 2.5 : 1.5,
        ),
        boxShadow: isDragging
            ? [const BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(card.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            card.valeur,
            style: TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w700,
              color: isPlaced
                  ? Colors.grey.shade400
                  : const Color(0xFF283593),
              decoration: isPlaced ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOUTON VALIDER
// ─────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool       allFilled;
  final bool       isSubmitting;
  final bool       hasSubmitted;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.allFilled,
    required this.isSubmitting,
    required this.hasSubmitted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: allFilled && !hasSubmitted
              ? const LinearGradient(colors: [Color(0xFF283593), Color(0xFF1E88E5)])
              : null,
          color: allFilled && !hasSubmitted ? null : Colors.white.withOpacity(0.3),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (allFilled && !hasSubmitted && !isSubmitting) ? onTap : null,
            child: Center(
              child: isSubmitting
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : hasSubmitted
                      ? const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Réponse envoyée !', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15,
                          )),
                        ])
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.send_rounded,
                              color: allFilled ? Colors.white : Colors.white60, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            allFilled ? 'VALIDER MA FICHE' : 'Remplis tous les champs',
                            style: TextStyle(
                              color: allFilled ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5,
                            ),
                          ),
                        ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AFFICHE RÉVISION
// ─────────────────────────────────────────────────────────────

class _ReviewBoard extends StatelessWidget {
  final FichePersoQuestion  question;
  final Map<String, String> placed;

  const _ReviewBoard({required this.question, required this.placed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.fact_check_rounded, color: Color(0xFF3949AB), size: 22),
                const SizedBox(width: 8),
                Text(question.fiche.nom, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF283593),
                )),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: fichePersoSlots
                    .where((s) => question.isActiveSlot(s.champ))
                    .map((slot) {
                  final expected  = question.expectedValue(slot.champ);
                  final isVisible = question.champsVisibles.contains(slot.champ);
                  final playerVal = isVisible ? expected : (placed[slot.champ] ?? '');
                  final isOk      = isVisible || playerVal == expected;

                  final screenW = MediaQuery.of(context).size.width;
                  final slotW   = (screenW - 16 * 2 - 16 * 2 - 10) / 2;

                  return SizedBox(
                    width: slotW,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color:        isOk ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOk ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(slot.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(slot.label, style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: isOk ? Colors.green.shade700 : Colors.red.shade700,
                            ), overflow: TextOverflow.ellipsis)),
                            Icon(
                              isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              size: 14,
                              color: isOk ? Colors.green : Colors.red,
                            ),
                          ]),
                          const SizedBox(height: 3),
                          Text(expected, style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                          ), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (!isVisible && playerVal.isNotEmpty && !isOk)
                            Text('Tu : $playerVal', style: TextStyle(
                              fontSize: 10, color: Colors.red.shade600, fontStyle: FontStyle.italic,
                            ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BADGE DIFFICULTÉ
// ─────────────────────────────────────────────────────────────

class _DifficultyBadge extends StatelessWidget {
  final String difficulte;
  const _DifficultyBadge({required this.difficulte});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg;
    switch (difficulte.toLowerCase()) {
      case 'facile':
        bg = Colors.green.shade100; fg = Colors.green.shade800;
      case 'difficile':
        bg = Colors.red.shade100;   fg = Colors.red.shade800;
      default:
        bg = Colors.orange.shade100; fg = Colors.orange.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(difficulte, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODÈLES ÉTENDUS
// ─────────────────────────────────────────────────────────────

/// Représente une option de carte dans une catégorie
class CardOption {
  final String valeur;
  final String emoji;
  const CardOption({required this.valeur, required this.emoji});
}

/// Métadonnée d'une catégorie (pour les onglets)
class CategoryMeta {
  final String label;
  final String emoji;
  const CategoryMeta({required this.label, required this.emoji});
}

// ─────────────────────────────────────────────────────────────
// QUESTION ÉTENDUE avec groupes par catégorie
// ─────────────────────────────────────────────────────────────

/// Extension de FichePersoQuestion qui gère les cartes par catégorie.
/// Chaque catégorie a [cardsPerCategory] cartes dont 1 correcte + N-1 leurres.
class FichePersoQuestion {
  final FichePersoPersonnage      fiche;
  final List<String>              champsVisibles;
  final List<AttributeCard>       cards;       // compatibilité ancienne
  final int                       pointsMax;
  final int                       roundTimeSeconds;
  final int                       reviewTimeSeconds;

  // Nouveaux : groupes par catégorie
  final Map<String, List<CardOption>> categoryGroups;
  final Map<String, CategoryMeta>     categoryMeta;

  FichePersoQuestion({
    required this.fiche,
    required this.champsVisibles,
    required this.cards,
    required this.pointsMax,
    required this.roundTimeSeconds,
    required this.reviewTimeSeconds,
    required this.categoryGroups,
    required this.categoryMeta,
  });

  // ── Catégories ──────────────────────────────────────────

  /// Catégories actives (slots non visibles avec des cartes)
  static const Map<String, CategoryMeta> _defaultMeta = {
    'localisation':      CategoryMeta(label: 'Lieu',      emoji: '📍'),
    'role':              CategoryMeta(label: 'Rôle',      emoji: '👑'),
    'periodeHistorique': CategoryMeta(label: 'Période',   emoji: '📅'),
    'relation1':         CategoryMeta(label: 'Relation 1',emoji: '🤝'),
    'relation2':         CategoryMeta(label: 'Relation 2',emoji: '🤝'),
    'livreBible':        CategoryMeta(label: 'Livre',     emoji: '📖'),
    'symbole':           CategoryMeta(label: 'Symbole',   emoji: '🔷'),
    'evenementMarquant': CategoryMeta(label: 'Événement', emoji: '⭐'),
  };

  String champToCategory(String champ) => champ;

  String? categoryToChamp(String category) => category;

  bool isActiveSlot(String champ) {
    if (champsVisibles.contains(champ)) return true;
    return categoryGroups.containsKey(champ) ||
        champ == 'nom' ||
        fiche.relations.length > 1 && champ == 'relation2' ||
        fiche.relations.isNotEmpty && champ == 'relation1';
  }

  String expectedValue(String champ) => switch (champ) {
    'nom'               => fiche.nom,
    'localisation'      => fiche.localisation,
    'role'              => fiche.role,
    'periodeHistorique' => fiche.periodeHistorique,
    'livreBible'        => fiche.livreBible,
    'symbole'           => fiche.symbole,
    'evenementMarquant' => fiche.evenementMarquant,
    'relation1'         => fiche.relations.isNotEmpty ? fiche.relations[0] : '',
    'relation2'         => fiche.relations.length > 1  ? fiche.relations[1] : '',
    _                   => '',
  };

  String labelForChamp(String champ) => _defaultMeta[champ]?.label ?? champ;

  // ─────────────────────────────────────────────────────────
  // FACTORY — parse depuis Firestore + génère les leurres
  // ─────────────────────────────────────────────────────────

  factory FichePersoQuestion.fromMap(
    Map<String, dynamic> map, {
    String? playerId,
    int cardsPerCategory = 4,
  }) {
    final source   = _extractPlayerQuestion(map, playerId);
    final ficheData = source['fiche'] as Map<String, dynamic>?;
    final fiche    = ficheData != null
        ? FichePersoPersonnage.fromJson(ficheData)
        : const FichePersoPersonnage(
            id: 'unknown', nom: 'Personnage inconnu',
            localisation: '?', role: '?', periodeHistorique: '?',
            relations: [], livreBible: '?', symbole: '?',
            evenementMarquant: '?', difficulte: '?',
          );

    final champsVisibles = List<String>.from(source['champsVisibles'] as List? ?? []);
    final roundTime      = (map['roundTimeSeconds']  as num?)?.toInt() ?? 60;
    final reviewTime     = (map['reviewTimeSeconds'] as num?)?.toInt() ?? 45;

    // Récupérer le pool de tous les personnages pour les leurres
    final personnages = <FichePersoPersonnage>[];
    final pool = map['personnages'] as Map<String, dynamic>?;
    if (pool != null) {
      for (final v in pool.values) {
        try {
          personnages.add(FichePersoPersonnage.fromJson(
              Map<String, dynamic>.from(v as Map)));
        } catch (_) {}
      }
    }

    // Construire les groupes de cartes par catégorie
    final groups = <String, List<CardOption>>{};
    final meta   = <String, CategoryMeta>{};

    // Champs à générer (tous sauf nom qui est toujours visible, et champsVisibles)
    const champDefs = [
      ('localisation',      '📍', 'Lieu'),
      ('role',              '👑', 'Rôle'),
      ('periodeHistorique', '📅', 'Période'),
      ('relation1',         '🤝', 'Relation 1'),
      ('relation2',         '🤝', 'Relation 2'),
      ('livreBible',        '📖', 'Livre'),
      ('symbole',           '🔷', 'Symbole'),
      ('evenementMarquant', '⭐', 'Événement'),
    ];

    for (final (champ, emoji, label) in champDefs) {
      if (champsVisibles.contains(champ)) continue;

      final correct = _correctValue(fiche, champ);
      if (correct.isEmpty) continue;

      // Générer des leurres à partir des autres personnages
      final decoys = _generateDecoys(
        champ:      champ,
        correct:    correct,
        personnages: personnages,
        count:      cardsPerCategory - 1,
      );

      final options = [CardOption(valeur: correct, emoji: emoji), ...decoys]
        ..shuffle();

      groups[champ] = options;
      meta[champ]   = CategoryMeta(label: label, emoji: emoji);
    }

    return FichePersoQuestion(
      fiche:            fiche,
      champsVisibles:   champsVisibles,
      cards:            [],
      pointsMax:        100,
      roundTimeSeconds: roundTime,
      reviewTimeSeconds: reviewTime,
      categoryGroups:   groups,
      categoryMeta:     meta,
    );
  }

  static String _correctValue(FichePersoPersonnage f, String champ) => switch (champ) {
    'localisation'      => f.localisation,
    'role'              => f.role,
    'periodeHistorique' => f.periodeHistorique,
    'livreBible'        => f.livreBible,
    'symbole'           => f.symbole,
    'evenementMarquant' => f.evenementMarquant,
    'relation1'         => f.relations.isNotEmpty ? f.relations[0] : '',
    'relation2'         => f.relations.length > 1  ? f.relations[1] : '',
    _                   => '',
  };

  /// Génère des leurres depuis le pool de personnages
  static List<CardOption> _generateDecoys({
    required String champ,
    required String correct,
    required List<FichePersoPersonnage> personnages,
    required int count,
    String emoji = '📌',
  }) {
    // Récupérer les emojis corrects
    final emojiMap = const {
      'localisation':      '📍',
      'role':              '👑',
      'periodeHistorique': '📅',
      'livreBible':        '📖',
      'symbole':           '🔷',
      'evenementMarquant': '⭐',
      'relation1':         '🤝',
      'relation2':         '🤝',
    };
    final e = emojiMap[champ] ?? emoji;

    final candidates = <String>{};
    for (final p in personnages) {
      final val = _correctValue(p, champ);
      if (val.isNotEmpty && val != correct) candidates.add(val);
    }

    final list = candidates.toList()..shuffle();
    final selected = list.take(count).toList();

    // Si pas assez de leurres du pool, utiliser des valeurs génériques
    while (selected.length < count) {
      selected.add('—');
    }

    return selected.map((v) => CardOption(valeur: v, emoji: e)).toList();
  }

  static Map<String, dynamic> _extractPlayerQuestion(
    Map<String, dynamic> map,
    String? playerId,
  ) {
    if (playerId != null && map['playerQuestions'] is Map<String, dynamic>) {
      final playerMap =
          (map['playerQuestions'] as Map<String, dynamic>)[playerId];
      if (playerMap is Map<String, dynamic>) return playerMap;
    }
    return map;
  }
}