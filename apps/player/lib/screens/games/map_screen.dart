// ─────────────────────────────────────────────────────────────
// CARTE BIBLIQUE (VERSION FINALE CORRIGÉE FLUTTER WEB)
// ─────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:core/core.dart';
import '_base_game_screen.dart';

class MapScreen extends StatelessWidget {
  final String sessionCode;

  const MapScreen({
    super.key,
    required this.sessionCode,
  });

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '🗺️ Carte Biblique',
      questionBuilder: (data) => _MapGame(
        data: data,
        sessionCode: sessionCode,
      ),
    );
  }
}

enum _Phase {
  playing,
  review,
}

class _MapGame extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sessionCode;

  const _MapGame({
    required this.data,
    required this.sessionCode,
  });

  @override
  State<_MapGame> createState() => _MapGameState();
}

class _MapGameState extends State<_MapGame>
    with TickerProviderStateMixin {
  // ── État ────────────────────────────────────────────────
  LatLng? _selectedPosition;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  _Phase _phase = _Phase.playing;

  // ── Timers ──────────────────────────────────────────────
  int _roundSeconds = 0;
  int _reviewSeconds = 0;
  Timer? _roundTimer;
  Timer? _reviewTimer;

  // ── Animation minimale sécurisée ────────────────────────
  late AnimationController _timerCtrl;

  // ── Question ────────────────────────────────────────────
  late MapQuestion _question;

  // ── Couleurs ────────────────────────────────────────────
  static const _primaryBlue = Color(0xFF3949AB);
  static const _accentCyan = Color(0xFF26C6DA);

  @override
  void initState() {
    super.initState();

    _timerCtrl = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _question = _parseQuestion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startRound();
    });
  }

  @override
  void didUpdateWidget(covariant _MapGame oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldRoundId = oldWidget.data['currentQuestionId'] as String?;
    final newRoundId = widget.data['currentQuestionId'] as String?;

    final oldRoundNumber =
        (oldWidget.data['roundNumber'] as num?)?.toInt() ?? 0;
    final newRoundNumber =
        (widget.data['roundNumber'] as num?)?.toInt() ?? 0;

    final oldRoundState =
        oldWidget.data['roundState'] as String? ?? 'idle';
    final newRoundState =
        widget.data['roundState'] as String? ?? 'idle';

    if (oldRoundId != newRoundId ||
        oldRoundNumber != newRoundNumber) {
      _question = _parseQuestion();
      _resetRound();
      return;
    }

    if (oldRoundState != newRoundState) {
      if (newRoundState == 'roundEnd' &&
          _phase == _Phase.playing) {
        _roundTimer?.cancel();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _hasSubmitted = true;
          });
          _enterReview();
        });
      }

      if (newRoundState == 'playing' &&
          _phase == _Phase.review) {
        _question = _parseQuestion();
        _resetRound();
      }
    }
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _reviewTimer?.cancel();
    _timerCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // PARSING
  // ─────────────────────────────────────────────────────────

  MapQuestion _parseQuestion() {
    final questionData =
        widget.data['question'] as Map<String, dynamic>?;

    if (questionData == null) {
      throw Exception('Question data missing');
    }

    return MapQuestion.fromMap(questionData);
  }

  // ─────────────────────────────────────────────────────────
  // ROUND MANAGEMENT
  // ─────────────────────────────────────────────────────────

  void _startRound() {
    final secs = widget.data['roundTimeSeconds'] as int? ?? 45;

    if (!mounted) return;

    setState(() {
      _roundSeconds = secs;
      _phase = _Phase.playing;
      _hasSubmitted = false;
      _isSubmitting = false;
      _selectedPosition = null;
    });

    _timerCtrl.duration = Duration(seconds: secs);
    _timerCtrl.forward(from: 0);

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (_roundSeconds > 0) {
            setState(() {
              _roundSeconds--;
            });
          }

          if (_roundSeconds <= 0) {
            timer.cancel();
            _autoSubmit();
          }
        });
      },
    );
  }

  void _resetRound() {
    _roundTimer?.cancel();
    _reviewTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startRound();
    });
  }

  void _autoSubmit() async {
    if (_hasSubmitted || _phase != _Phase.playing) return;

    _roundTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hasSubmitted = true;
      });
    });

    await _doSubmit();
  }

  Future<void> _submit() async {
    if (_hasSubmitted || _phase != _Phase.playing) return;

    _roundTimer?.cancel();
    _timerCtrl.stop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hasSubmitted = true;
        _isSubmitting = true;
      });
    });

    await _doSubmit();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    });
  }

  Future<void> _doSubmit() async {
    final points = _calculatePoints();
    final service = SessionService();
    final uid = service.currentUid ?? '';

    if (uid.isNotEmpty) {
      await service.submitAnswer(
        sessionCode: widget.sessionCode,
        playerId: uid,
        answer: _selectedPosition != null
            ? {
                'lat': _selectedPosition!.latitude,
                'lng': _selectedPosition!.longitude,
              }
            : null,
        points: points,
      );
    }

    _enterReview();
  }

  int _calculatePoints() {
    if (_selectedPosition == null) return 0;

    final distance = const Distance().as(
      LengthUnit.Kilometer,
      _selectedPosition!,
      LatLng(
        _question.lieu.latitude,
        _question.lieu.longitude,
      ),
    );

    if (distance <= _question.rayonToleranceKm) {
      final proximityRatio =
          1 - (distance / _question.rayonToleranceKm);

      return (proximityRatio * _question.pointsMax).round();
    }

    return 0;
  }

  void _enterReview() {
    _roundTimer?.cancel();

    final secs =
        widget.data['reviewTimeSeconds'] as int? ?? 15;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _phase = _Phase.review;
        _reviewSeconds = secs;
      });

      _reviewTimer?.cancel();
      _reviewTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted) return;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (_reviewSeconds > 0) {
              setState(() {
                _reviewSeconds--;
              });
            }

            if (_reviewSeconds <= 0) {
              timer.cancel();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                SessionService().drawNextQuestion(
                  widget.sessionCode,
                );
              });
            }
          });
        },
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // INTERACTION
  // ─────────────────────────────────────────────────────────

  void _onMapTap(
    TapPosition tapPosition,
    LatLng point,
  ) {
    if (_hasSubmitted || _phase != _Phase.playing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedPosition = point;
      });
    });
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _phase == _Phase.review
        ? _buildReview()
        : _buildPlaying();
  }

  // ── PLAYING ─────────────────────────────────────────────

  Widget _buildPlaying() {
    final total =
        widget.data['roundTimeSeconds'] as int? ?? 45;

    final ratio = total > 0
        ? _roundSeconds / total
        : 0.0;

    final isLow = _roundSeconds <= 10;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0, 1),
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
          _roundSeconds > 0
              ? '⏱️ $_roundSeconds s'
              : '⏱️ Temps écoulé !',
          style: TextStyle(
            color: isLow ? Colors.red : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _question.question,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(32.0, 35.0),
                initialZoom: 7.0,
                maxZoom: 12.0,
                minZoom: 5.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.example.biblical_games',
                ),
                if (_selectedPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPosition!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _selectedPosition != null
                ? 'Position sélectionnée : '
                    '${_selectedPosition!.latitude.toStringAsFixed(4)}, '
                    '${_selectedPosition!.longitude.toStringAsFixed(4)}'
                : 'Cliquez sur la carte pour placer un marqueur',
            textAlign: TextAlign.center,
          ),
        ),
        if (!_hasSubmitted && !_isSubmitting)
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── REVIEW ──────────────────────────────────────────────

  Widget _buildReview() {
    final correctPosition = LatLng(
      _question.lieu.latitude,
      _question.lieu.longitude,
    );

    final distance = _selectedPosition != null
        ? const Distance().as(
            LengthUnit.Kilometer,
            _selectedPosition!,
            correctPosition,
          )
        : double.infinity;

    final proximityPercent =
        distance <= _question.rayonToleranceKm
            ? ((1 - distance /
                        _question.rayonToleranceKm) *
                    100)
                .round()
            : 0;

    final points = _calculatePoints();

    final total =
        widget.data['reviewTimeSeconds'] as int? ?? 15;

    final ratio = total > 0
        ? _reviewSeconds / total
        : 0.0;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0, 1),
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _question.question,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: IgnorePointer(
            ignoring: true,
            child: Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: correctPosition,
                  initialZoom: 8.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.biblical_games',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: correctPosition,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPosition!,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Lieu correct : ${_question.lieu.nom}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_selectedPosition != null) ...[
                Text(
                  'Distance : ${distance.toStringAsFixed(1)} km',
                ),
                Text(
                  'Précision : $proximityPercent%',
                ),
                Text(
                  'Points : $points / ${_question.pointsMax}',
                ),
              ] else ...[
                const Text(
                  'Aucune position sélectionnée',
                  style: TextStyle(color: Colors.red),
                ),
              ],
              if (_question.lieu.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _question.lieu.description,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}