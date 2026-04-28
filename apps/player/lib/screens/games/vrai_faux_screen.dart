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
      questionBuilder: (data) => _VraiFauxWidget(
          question: VraiFauxQuestion.fromMap(data),
          sessionCode: sessionCode),
    );
  }
}

class _VraiFauxWidget extends StatefulWidget {
  final VraiFauxQuestion question;
  final String sessionCode;
  const _VraiFauxWidget({required this.question, required this.sessionCode});

  @override
  State<_VraiFauxWidget> createState() => _VraiFauxWidgetState();
}

class _VraiFauxWidgetState extends State<_VraiFauxWidget> {
  bool? _selected;
  bool _answered = false;

  void _answer(bool value) {
    if (_answered) return;
    setState(() { _selected = value; _answered = true; });
    final correct = value == widget.question.reponse;
    SessionService().submitAnswer(
      sessionCode: widget.sessionCode,
      playerId: SessionService().currentUid ?? '',
      answer: value,
      points: correct ? widget.question.pointsMax : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.question.affirmation,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (widget.question.reference != null) ...[
          const SizedBox(height: 8),
          Text(widget.question.reference!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BoolButton(
              label: '✅ VRAI',
              color: Colors.green,
              selected: _selected == true,
              answered: _answered,
              correct: _answered && widget.question.reponse == true,
              onTap: () => _answer(true),
            ),
            _BoolButton(
              label: '❌ FAUX',
              color: Colors.red,
              selected: _selected == false,
              answered: _answered,
              correct: _answered && widget.question.reponse == false,
              onTap: () => _answer(false),
            ),
          ],
        ),
        if (_answered) ...[
          const SizedBox(height: 24),
          Card(
            color: _selected == widget.question.reponse
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _selected == widget.question.reponse ? '🎉 Correct !' : '❌ Raté !',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(widget.question.explication),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BoolButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool answered;
  final bool correct;
  final VoidCallback onTap;

  const _BoolButton({
    required this.label, required this.color, required this.selected,
    required this.answered, required this.correct, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        height: 100,
        decoration: BoxDecoration(
          color: answered
              ? (correct ? Colors.green.shade200 : selected ? Colors.red.shade200 : Colors.grey.shade200)
              : selected ? color.withOpacity(0.3) : Colors.transparent,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FRISE CHRONOLOGIQUE
// ─────────────────────────────────────────────────────────────

class FriseScreen extends StatelessWidget {
  final String sessionCode;
  const FriseScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '📅 Frise Chronologique',
      questionBuilder: (data) => _FriseWidget(
          question: FriseQuestion.fromMap(data),
          sessionCode: sessionCode),
    );
  }
}

class _FriseWidget extends StatefulWidget {
  final FriseQuestion question;
  final String sessionCode;
  const _FriseWidget({required this.question, required this.sessionCode});

  @override
  State<_FriseWidget> createState() => _FriseWidgetState();
}

class _FriseWidgetState extends State<_FriseWidget> {
  late List<EvenementBiblique> _ordre;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _ordre = List.from(widget.question.evenementsAOrdonner)..shuffle();
  }

  void _submit() {
    if (_submitted) return;
    setState(() => _submitted = true);
    final pts = widget.question.calculerPoints(_ordre.map((e) => e.id).toList());
    SessionService().submitAnswer(
      sessionCode: widget.sessionCode,
      playerId: SessionService().currentUid ?? '',
      answer: _ordre.map((e) => e.id).toList(),
      points: pts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Glisse pour remettre dans l\'ordre chronologique',
              textAlign: TextAlign.center),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: _submitted ? (_, __) {} : (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _ordre.removeAt(oldIndex);
              _ordre.insert(newIndex, item);
            });
          },
          children: _ordre.map((e) => ListTile(
            key: ValueKey(e.id),
            leading: const Icon(Icons.drag_handle),
            title: Text(e.titre),
            subtitle: Text(e.description),
            trailing: _submitted
                ? Text(e.anneeLabel,
                style: const TextStyle(fontSize: 12))
                : null,
          )).toList(),
        ),
        const SizedBox(height: 16),
        if (!_submitted)
          FilledButton(
            onPressed: _submit,
            child: const Text('Valider mon ordre'),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIVINE TON VERSET
// ─────────────────────────────────────────────────────────────

class DevineVersetScreen extends StatelessWidget {
  final String sessionCode;
  const DevineVersetScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '📖 Divine ton Verset',
      questionBuilder: (data) => _DevineVersetWidget(
          question: DevineVersetQuestion.fromMap(data),
          sessionCode: sessionCode),
    );
  }
}

class _DevineVersetWidget extends StatefulWidget {
  final DevineVersetQuestion question;
  final String sessionCode;
  const _DevineVersetWidget({required this.question, required this.sessionCode});

  @override
  State<_DevineVersetWidget> createState() => _DevineVersetWidgetState();
}

class _DevineVersetWidgetState extends State<_DevineVersetWidget> {
  String? _selectedRef;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('📖', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  '"${widget.question.texteVerset}"',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('D\'où vient ce verset ?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...widget.question.choixReferences.map((ref) {
          final isSelected = _selectedRef == ref;
          final isCorrect = _answered && ref == widget.question.reference;
          final isWrong = _answered && isSelected && ref != widget.question.reference;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isCorrect
                      ? Colors.green.shade100
                      : isWrong
                      ? Colors.red.shade100
                      : null,
                ),
                onPressed: _answered ? null : () {
                  setState(() { _selectedRef = ref; _answered = true; });
                  final correct = ref == widget.question.reference;
                  SessionService().submitAnswer(
                    sessionCode: widget.sessionCode,
                    playerId: SessionService().currentUid ?? '',
                    answer: ref,
                    points: correct ? widget.question.pointsMax : 0,
                  );
                },
                child: Text(ref),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARTE (Map) — placeholder avec flutter_map
// ─────────────────────────────────────────────────────────────

class MapScreen extends StatelessWidget {
  final String sessionCode;
  const MapScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '🗺️ Carte Biblique',
      questionBuilder: (data) => _MapWidget(
          question: MapQuestion.fromMap(data),
          sessionCode: sessionCode),
    );
  }
}

class _MapWidget extends StatelessWidget {
  final MapQuestion question;
  final String sessionCode;
  const _MapWidget({required this.question, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    // TODO: intégrer flutter_map avec une carte du Moyen-Orient
    // Utiliser: FlutterMap + TileLayer (OpenStreetMap gratuit)
    // L'utilisateur tape sur la carte, on calcule la distance
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              question.question,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 350,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              '🗺️ Carte interactive\n(flutter_map + OpenStreetMap)',
              textAlign: TextAlign.center,
            ),
          ),
          // Remplacer par :
          // FlutterMap(
          //   options: MapOptions(
          //     center: LatLng(31.5, 35.0),
          //     zoom: 7,
          //     onTap: (tapPos, point) => _onMapTap(point),
          //   ),
          //   children: [
          //     TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
          //     MarkerLayer(markers: [...]),
          //   ],
          // ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RÉDACTION DE LA BIBLE
// ─────────────────────────────────────────────────────────────

class RedactionScreen extends StatelessWidget {
  final String sessionCode;
  const RedactionScreen({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      sessionCode: sessionCode,
      gameTitle: '✍️ Rédaction de la Bible',
      questionBuilder: (data) => _RedactionWidget(
          question: RedactionQuestion.fromMap(data),
          sessionCode: sessionCode),
    );
  }
}

class _RedactionWidget extends StatefulWidget {
  final RedactionQuestion question;
  final String sessionCode;
  const _RedactionWidget({required this.question, required this.sessionCode});

  @override
  State<_RedactionWidget> createState() => _RedactionWidgetState();
}

class _RedactionWidgetState extends State<_RedactionWidget> {
  String? _selectedId;
  bool _answered = false;
  final _labels = {
    'auteur': 'Auteur',
    'lieu': 'Lieu de rédaction',
    'anneeFinRedaction': 'Fin de rédaction',
    'periodeCouverte': 'Période couverte',
    'genre': 'Genre littéraire',
  };

  @override
  Widget build(BuildContext context) {
    final livre = widget.question.livre;
    final caches = widget.question.champsCaches;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(livre.nom,
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(livre.testament == 'AT'
                    ? 'Ancien Testament' : 'Nouveau Testament',
                    style: Theme.of(context).textTheme.bodySmall),
                const Divider(),
                if (!caches.contains('auteur'))
                  _InfoRow('✍️ Auteur', livre.auteur),
                if (!caches.contains('lieu'))
                  _InfoRow('📍 Lieu', livre.lieu),
                if (!caches.contains('anneeFinRedaction'))
                  _InfoRow('📅 Fin rédaction', livre.anneeLabel),
                if (!caches.contains('periodeCouverte'))
                  _InfoRow('🕐 Période', livre.periodeCouverte),
                if (!caches.contains('genre'))
                  _InfoRow('📚 Genre', livre.genre),
                if (caches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'À deviner : ${caches.map((c) => _labels[c] ?? c).join(', ')}',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Quel est le bon livre ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.question.choixPossibles.map((choix) {
          final isCorrect = _answered && choix.id == livre.id;
          final isWrong = _answered && _selectedId == choix.id && choix.id != livre.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isCorrect
                      ? Colors.green.shade100
                      : isWrong ? Colors.red.shade100 : null,
                ),
                onPressed: _answered ? null : () {
                  setState(() { _selectedId = choix.id; _answered = true; });
                  final correct = choix.id == livre.id;
                  SessionService().submitAnswer(
                    sessionCode: widget.sessionCode,
                    playerId: SessionService().currentUid ?? '',
                    answer: choix.id,
                    points: correct ? widget.question.pointsMax : 0,
                  );
                },
                child: Text(choix.nom),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}