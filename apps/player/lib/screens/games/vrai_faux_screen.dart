// ✅ FIX : imports dédupliqués (il y avait deux blocs identiques)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core/core.dart';
import '_base_game_screen.dart';

// ─────────────────────────────────────────────────────────────
// VRAI OU FAUX
// ─────────────────────────────────────────────────────────────

class VraiFauxScreen extends StatelessWidget {
  final String sessionCode;
  const VraiFauxScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '✅ Vrai ou Faux',
      questionBuilder: (data) => _VraiFauxGame(
        data: data,
        sessionCode: sessionCode,
      ),
    );
  }
}

enum _Phase { playing, review }

class _VraiFauxGame extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sessionCode;
  const _VraiFauxGame({required this.data, required this.sessionCode});

  @override
  State<_VraiFauxGame> createState() => _VraiFauxGameState();
}

class _VraiFauxGameState extends State<_VraiFauxGame>
    with TickerProviderStateMixin {

  // ── État ────────────────────────────────────────────────
  bool? _selected;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  _Phase _phase = _Phase.playing;

  // ── Timers ──────────────────────────────────────────────
  int _roundSeconds = 0;
  int _reviewSeconds = 0;
  Timer? _roundTimer;
  Timer? _reviewTimer;

  // ── Animations ──────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _timerCtrl;

  // ── Question parsée ─────────────────────────────────────
  late VraiFauxQuestion _question;

  // ── Couleurs ────────────────────────────────────────────
  static const _primaryBlue  = Color(0xFF3949AB);
  static const _accentCyan   = Color(0xFF26C6DA);

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _timerCtrl = AnimationController(
        duration: const Duration(seconds: 1), vsync: this);
    _question  = _parseQuestion();
    _startRound();
  }

  @override
  void didUpdateWidget(covariant _VraiFauxGame old) {
    super.didUpdateWidget(old);

    final oldRoundId     = old.data['currentQuestionId'] as String?;
    final newRoundId     = widget.data['currentQuestionId'] as String?;
    final oldRoundNumber = (old.data['roundNumber'] as num?)?.toInt() ?? 0;
    final newRoundNumber = (widget.data['roundNumber'] as num?)?.toInt() ?? 0;
    final oldRoundState  = old.data['roundState'] as String? ?? 'idle';
    final newRoundState  = widget.data['roundState'] as String? ?? 'idle';

    if (oldRoundId != newRoundId || oldRoundNumber != newRoundNumber) {
      _question = _parseQuestion();
      _resetRound();
      return;
    }

    if (oldRoundState != newRoundState) {
      if (newRoundState == 'roundEnd' && _phase == _Phase.playing) {
        _roundTimer?.cancel();

        if (!_hasSubmitted) {
          setState(() => _hasSubmitted = true);
          _doSubmit();
        } else {
          _enterReview();
        }
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
  // PARSING
  // ─────────────────────────────────────────────────────────

  VraiFauxQuestion _parseQuestion() {
    final questionData = widget.data['question'] as Map<String, dynamic>?;
    if (questionData == null) throw Exception('Question data missing');
    return VraiFauxQuestion.fromMap(questionData);
  }

  // ─────────────────────────────────────────────────────────
  // GESTION DU ROUND
  // ─────────────────────────────────────────────────────────

  void _startRound() {
    final secs = widget.data['roundTimeSeconds'] as int? ?? 30;
    setState(() {
      _roundSeconds = secs;
      _phase        = _Phase.playing;
      _hasSubmitted = false;
      _isSubmitting = false;
      _selected     = null;
    });
    _timerCtrl.duration = Duration(seconds: secs);
    _timerCtrl.forward(from: 0);

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _roundSeconds--);
      if (_roundSeconds <= 0) {
        t.cancel();

        final service = SessionService();
        await service.forceEndRound(widget.sessionCode);

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

  /// Soumission automatique quand le timer expire
  void _autoSubmit() async {
    if (_hasSubmitted || _phase != _Phase.playing) return;
    _roundTimer?.cancel();
    setState(() => _hasSubmitted = true);
    await _doSubmit();
  }

  /// Soumission manuelle via le bouton "Valider"
  Future<void> _submit() async {
    if (_hasSubmitted || _selected == null) return; // ✅ FIX : guard sur _selected
    _roundTimer?.cancel();
    _timerCtrl.stop();
    setState(() {
      _hasSubmitted = true;
      _isSubmitting = true;
    });
    await _doSubmit();
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _doSubmit() async {
    final correct = _selected != null && (_selected == _question.answer);
    final points  = correct ? _question.pointsMax : 0;

    final service = SessionService();
    final uid     = service.currentUid ?? '';

    if (uid.isNotEmpty) {
      await service.submitAnswer(
        sessionCode: widget.sessionCode,
        playerId: uid,
        answer: _selected,
        points: points,
      );
    }

    final session = await service.db
      .collection('sessions')
      .doc(widget.sessionCode)
      .get();

    final state = session.data()?['state'];

    if (state == SessionState.reviewing.name) {
      _enterReview();
    }
  }

  void _enterReview() {
    if (_phase == _Phase.review) return;

    _roundTimer?.cancel();

    const secs = 10;

    setState(() {
      _phase = _Phase.review;
      _reviewSeconds = secs;
    });

    _fadeCtrl.forward(from: 0);

    _reviewTimer?.cancel();
    _reviewTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;

      setState(() => _reviewSeconds--);

      if (_reviewSeconds <= 0) {
        t.cancel();

        final service = SessionService();
        await service.autoAdvanceAfterReview(widget.sessionCode);
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // INTERACTION
  // ─────────────────────────────────────────────────────────

  void _answer(bool value) {
    if (_hasSubmitted) return;
    setState(() => _selected = value);
  }

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
    final total = widget.data['roundTimeSeconds'] as int? ?? 30;
    final ratio = total > 0 ? _roundSeconds / total : 0.0;
    final isLow = _roundSeconds <= 10;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Timer ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: isLow ? Colors.red : _accentCyan,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _roundSeconds > 0 ? '⏱️ $_roundSeconds s' : '⏱️ Temps écoulé !',
          style: TextStyle(
            color: isLow ? Colors.red : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 32),

        // ── Énoncé ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _question.statement,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (_question.reference != null) ...[
          const SizedBox(height: 8),
          Text(_question.reference!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 40),

        // ── Boutons VRAI / FAUX ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BoolButton(
              label:    '✅ VRAI',
              color:    Colors.green,
              selected: _selected == true,
              answered: _hasSubmitted,
              correct:  _hasSubmitted &&
                  _selected == true &&
                  _question.answer == true,
              onTap: () => _answer(true),
            ),
            _BoolButton(
              label:    '❌ FAUX',
              color:    Colors.red,
              selected: _selected == false,
              answered: _hasSubmitted,
              correct:  _hasSubmitted &&
                  _selected == false &&
                  _question.answer == false,
              onTap: () => _answer(false),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ✅ FIX : le bouton s'affiche quand une réponse est sélectionnée
        //         mais pas encore soumise — et disparaît pendant la soumission.
        if (_selected != null && !_hasSubmitted && !_isSubmitting)
          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),

        if (_isSubmitting)
          const CircularProgressIndicator(),

        // Message d'attente après soumission manuelle (avant review)
        if (_hasSubmitted && !_isSubmitting && _phase == _Phase.playing)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Réponse envoyée… En attente de la correction.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }

  // ── Phase RÉVISION ──────────────────────────────────────

  Widget _buildReview() {
    // ✅ FIX : si _selected est null, on affiche "Sans réponse"
    final answered   = _selected != null;
    final isCorrect  = answered && (_selected == _question.answer);
    final total      = widget.data['reviewTimeSeconds'] as int? ?? 12;
    final ratio      = total > 0 ? _reviewSeconds / total : 0.0;

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Timer ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _accentCyan,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '🔄 Prochaine question dans $_reviewSeconds s',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // ── Énoncé ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _question.statement,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_question.reference != null) ...[
            const SizedBox(height: 8),
            Text(_question.reference!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 24),

          // ── Résultat ──
          Card(
            color: !answered
                ? Colors.orange.shade50
                : isCorrect
                    ? Colors.green.shade50
                    : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    // ✅ FIX : cas "pas de réponse" géré
                    !answered
                        ? '⏰ Temps écoulé !'
                        : isCorrect
                            ? '🎉 Correct !'
                            : '❌ Raté !',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✔️ Bonne réponse : ${_question.answer ? "VRAI" : "FAUX"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(_question.explanation),
                  if (answered) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Votre réponse : ${_selected! ? "VRAI" : "FAUX"}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOUTON VRAI / FAUX
// ─────────────────────────────────────────────────────────────

class _BoolButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool answered;
  final bool correct;
  final VoidCallback onTap;

  const _BoolButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.answered,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (answered) {
      if (correct) {
        bgColor = Colors.green.shade200;
      } else if (selected) {
        bgColor = Colors.red.shade200;
      } else {
        bgColor = Colors.grey.shade200;
      }
    } else if (selected) {
      bgColor = color.withOpacity(0.3);
    } else {
      bgColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        height: 100,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}