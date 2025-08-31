import 'package:flutter/material.dart';

void main() => runApp(const GameScreenSandboxApp());

class GameScreenSandboxApp extends StatelessWidget {
  const GameScreenSandboxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3-7 Sandbox',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0E7A57), useMaterial3: true),
      home: const GameScreenSandbox(),
    );
  }
}

/// Maquette interactive pour valider la structure de l’écran de jeu:
/// - Mains sans scroll (chevauchement contrôlé) + effet éventail
/// - Table visible (feutrine, **pioche à gauche seulement**)
/// - Pli au centre avec **anim plus lentes** (pose + ramassage)
/// - Badge “Demande” en haut de la table
/// - Icône unique “Trouver” centré au-dessus du pli
class GameScreenSandbox extends StatefulWidget {
  const GameScreenSandbox({super.key});
  @override
  State<GameScreenSandbox> createState() => _GameScreenSandboxState();
}

class _GameScreenSandboxState extends State<GameScreenSandbox> {
  // --- ÉTAT SIMULÉ ---
  final List<_UiCard> _oppHand = List.generate(8, (i) => _UiCard('?', 'B')); // 'B' = dos
  final List<_UiCard> _myHand = [
    _UiCard('A', '♥'), _UiCard('K', '♠'), _UiCard('9', '♣'), _UiCard('3', '♦'),
    _UiCard('5', '♣'), _UiCard('8', '♦'), _UiCard('J', '♠'), _UiCard('7', '♥'),
  ];
  final List<_UiCard> _wonOpp = [];
  final List<_UiCard> _wonMe = [];

  _UiCard? _tableOpp;
  _UiCard? _tableMe;

  bool _isMyTurn = true;
  final List<String> _logs = [];

  int _round = 1, _trick = 1;
  bool _isRoundOver = false;

  String? _demandedSuit; // '♥' '♦' '♣' '♠'
  // Icône TROUVER — unique, au milieu de la table
  String? _foundSuit;   // '♥' '♦' '♣' '♠'
  String? _foundOwner;  // 'Joueur' | 'Adversaire'

  // Animation de ramassage du pli
  bool _collecting = false;

  // --- HELPERS ---
  void _log(String m) { if (_logs.isEmpty || _logs.last != m) _logs.add(m); }

  void _playMyCard(_UiCard c) async {
    if (!_isMyTurn || _tableMe != null || _isRoundOver) return;
    setState(() {
      _myHand.remove(c);
      _tableMe = c;
      _isMyTurn = false;
      _demandedSuit ??= (c.suit == 'B') ? null : c.suit;
      _log('Tu joues ${c.face}');
    });

    // Bot joue (plus lent)
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      if (_oppHand.isNotEmpty) _oppHand.removeAt(0);
      final suit = _demandedSuit ?? '♦';
      _tableOpp = _UiCard('10', suit);
      _log('Adversaire joue 10$suit');
    });

    // Petite pause avant de ramasser (plus lent)
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() { _collecting = true; });

    // Durée de ramassage rallongée
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      // Démo: tu gagnes le pli
      if (_tableMe != null) _wonMe.add(_tableMe!);
      if (_tableOpp != null) _wonMe.add(_tableOpp!);
      _tableMe = null; _tableOpp = null;
      _trick += 1;
      _demandedSuit = null;
      _log('Pli pour toi');
      _collecting = false;
      _isMyTurn = true;
    });

    // Fin de manche fictive
    if (_myHand.isEmpty && _oppHand.where((c) => c.suit == 'B').isEmpty) {
      setState(() { _isRoundOver = true; _log('Manche $_round terminée'); });
    }
  }

  void _toggleFoundMe() {
    const order = [null, '♥', '♦', '♣', '♠'];
    final i = order.indexOf(_foundSuit);
    setState(() { _foundSuit = order[(i + 1) % order.length]; _foundOwner = _foundSuit == null ? null : 'Joueur'; });
  }

  void _toggleFoundOpp() {
    const order = [null, '♥', '♦', '♣', '♠'];
    final i = order.indexOf(_foundSuit);
    setState(() { _foundSuit = order[(i + 1) % order.length]; _foundOwner = _foundSuit == null ? null : 'Adversaire'; });
  }

  void _nextRound() {
    if (!_isRoundOver) return;
    setState(() {
      _round++; _trick = 1; _isRoundOver = false;
      _wonMe.clear(); _wonOpp.clear(); _logs.clear();
      _tableMe = null; _tableOpp = null; _demandedSuit = null;
      _foundSuit = null; _foundOwner = null; _collecting = false;
      _oppHand
        ..clear()
        ..addAll(List.generate(8, (i) => _UiCard('?', 'B')));
      _myHand
        ..clear()
        ..addAll([
          _UiCard('Q','♥'), _UiCard('A','♣'), _UiCard('7','♠'), _UiCard('8','♦'),
          _UiCard('K','♦'), _UiCard('9','♠'), _UiCard('6','♣'), _UiCard('3','♥'),
        ]);
      _isMyTurn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockActive = !_isMyTurn || _isRoundOver;
    return Scaffold(
      backgroundColor: const Color(0xFF134D2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3D22),
        title: Row(children: [
          Text('Manche $_round'),
          const SizedBox(width: 16), const Text('•'),
          const SizedBox(width: 16), Text('Pli $_trick'),
        ]),
        actions: [
          IconButton(tooltip:'Trouver (Adversaire)', onPressed:_toggleFoundOpp, icon: const Icon(Icons.auto_awesome)),
          IconButton(tooltip:'Trouver (Joueur)', onPressed:_toggleFoundMe, icon: const Icon(Icons.flash_on)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ======== ZONE ADVERSAIRE ========
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WonPile(pile: _wonOpp, label: 'Gagnées ADV'),
                  const SizedBox(width: 12),
                  Expanded(child: _HandBackNoScroll(cards: _oppHand)), // fan léger
                  const SizedBox(width: 12),
                  _PlayerInfo(name: 'Adversaire', score: _wonOpp.length),
                ],
              ),
            ),

            // ======== TABLE (feutrine) / PIOCHE / PLI / TROUVER ========
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: _TableArea(
                  tableMe: _tableMe,
                  tableOpp: _tableOpp,
                  demandedSuit: _demandedSuit,
                  foundSuit: _foundSuit,
                  foundOwner: _foundOwner,
                  lockActive: lockActive,
                  collecting: _collecting, // <-- animation de ramassage
                ),
              ),
            ),

            // ======== LOG ========
            _LogBar(logs: _logs),

            // ======== ZONE JOUEUR ========
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _MyHandNoScroll(
                      cards: _myHand,
                      locked: !_isMyTurn || _isRoundOver,
                      onTap: _playMyCard,
                    ), // fan plus visible
                  ),
                  const SizedBox(width: 12),
                  _WonPile(pile: _wonMe, label: 'Gagnées TOI'),
                ],
              ),
            ),

            // ======== ACTIONS ========
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleFoundMe,
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Trouver'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _log('Conseil: jouer la couleur demandée'),
                      icon: const Icon(Icons.lightbulb),
                      label: const Text('Conseil'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRoundOver ? _nextRound : null,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Next Round'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _UiCard {
  final String rank; // A,K,Q,10,9… ou '?' (verso)
  final String suit; // ♥ ♦ ♣ ♠ ou 'B' (back)
  final String face; // "A♥"
  _UiCard(this.rank, this.suit) : face = '$rank$suit';
}

// ---------- Main ADVERSAIRE (dos) : sans scroll, fan léger ----------
class _HandBackNoScroll extends StatelessWidget {
  final List<_UiCard> cards;
  const _HandBackNoScroll({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = cards.length.clamp(0, 13);
      final maxW = c.maxWidth;

      const maxCardW = 64.0;
      const minCardW = 36.0;
      final cardW = (maxW / (n > 0 ? n : 1)).clamp(minCardW, maxCardW);
      final cardH = cardW * 1.45;

      // Pas horizontal calculé pour que la dernière carte reste visible
      final step = ((maxW - cardW) / (n > 1 ? (n - 1) : 1)).clamp(8.0, cardW);

      return SizedBox(
        width: maxW,
        height: cardH,
        child: Stack(
          clipBehavior: Clip.none,
          children: List.generate(n, (i) {
            final left = i * step;
            // éventail léger: -4° .. +4° et petit arc
            final t = n == 1 ? 0.0 : (i / (n - 1)) * 2 - 1; // [-1..1]
            final angle = 0.07 * t; // rad ~4°
            final lift = -(1 - t.abs()) * 6; // centre plus haut

            return Positioned(
              left: left,
              child: Transform.translate(
                offset: Offset(0, lift),
                child: Transform.rotate(
                  alignment: Alignment.bottomCenter,
                  angle: angle,
                  child: Container(
                    width: cardW,
                    height: cardH,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    });
  }
}

// ---------- Main JOUEUR (face) : sans scroll, fan visible ----------
class _MyHandNoScroll extends StatelessWidget {
  final List<_UiCard> cards;
  final bool locked;
  final void Function(_UiCard) onTap;
  const _MyHandNoScroll({required this.cards, required this.locked, required this.onTap});

  Color _suitColor(String s) => (s == '♥' || s == '♦') ? Colors.red.shade300 : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: LayoutBuilder(builder: (context, c) {
        final n = cards.length.clamp(1, 13);
        final maxW = c.maxWidth;

        const maxCardW = 70.0;
        const minCardW = 42.0;
        final cardW = (maxW / (n > 0 ? n : 1)).clamp(minCardW, maxCardW);
        final cardH = cardW * 1.45;

        final step = ((maxW - cardW) / (n > 1 ? (n - 1) : 1)).clamp(8.0, cardW);

        return SizedBox(
          width: maxW,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(n, (i) {
              final card = cards[i];
              final left = i * step;

              // éventail: -7° .. +7° et arc légèrement plus marqué
              final t = n == 1 ? 0.0 : (i / (n - 1)) * 2 - 1; // [-1..1]
              final angle = 0.12 * t; // rad ~7°
              final lift = -(1 - t.abs()) * 10;

              return Positioned(
                left: left,
                child: Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.rotate(
                    alignment: Alignment.bottomCenter,
                    angle: angle,
                    child: GestureDetector(
                      onTap: locked ? null : () => onTap(card),
                      child: Container(
                        width: cardW,
                        height: cardH,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2B2B).withOpacity(.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(card.rank,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                )),
                            const Spacer(),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                card.suit == 'B' ? '' : card.suit,
                                style: TextStyle(
                                  color: _suitColor(card.suit),
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ---------- Carte posée sur la table (contenu) ----------
class _TableCard extends StatelessWidget {
  final _UiCard? card;
  const _TableCard({required this.card});
  @override
  Widget build(BuildContext context) {
    if (card == null) return const SizedBox(width: 84, height: 116);
    final isRed = card!.suit == '♥' || card!.suit == '♦';
    return Container(
      width: 84, height: 116, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B).withOpacity(.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black38, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card!.rank, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(card!.suit, style: TextStyle(color: isRed ? Colors.red.shade300 : Colors.white, fontSize: 26)),
          ),
        ],
      ),
    );
  }
}

// ---------- Pile gagnée ----------
class _WonPile extends StatelessWidget {
  final List<_UiCard> pile; final String label;
  const _WonPile({required this.pile, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Stack(children: List.generate(pile.length.clamp(0, 3), (i) => Transform.translate(
        offset: Offset(i * 8, 0),
        child: Container(
          width: 40, height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
        ),
      ))),
      const SizedBox(height: 6),
      Text('$label (${pile.length})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

// ---------- Infos joueur ----------
class _PlayerInfo extends StatelessWidget {
  final String name; final int score;
  const _PlayerInfo({required this.name, required this.score});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.black.withOpacity(.28), borderRadius: BorderRadius.circular(8)),
          child: Text('$score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ---------- Badge Demande ----------
class _DemandedBadge extends StatelessWidget {
  final String suit;
  const _DemandedBadge({required this.suit});
  @override
  Widget build(BuildContext context) {
    final isRed = suit == '♥' || suit == '♦';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.flag, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text('Demande: $suit',
            style: TextStyle(color: isRed ? Colors.red.shade300 : Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ---------- Zone TABLE (feutrine + pioche + pli + trouver) ----------
class _TableArea extends StatelessWidget {
  final _UiCard? tableMe;
  final _UiCard? tableOpp;
  final String? demandedSuit;
  final String? foundSuit;   // ♥ ♦ ♣ ♠
  final String? foundOwner;  // Joueur / Adversaire
  final bool lockActive;
  final bool collecting;

  const _TableArea({
    required this.tableMe,
    required this.tableOpp,
    required this.demandedSuit,
    required this.foundSuit,
    required this.foundOwner,
    required this.lockActive,
    required this.collecting,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Container(
        width: double.infinity,
        height: c.maxHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF0F3A22),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(.25), width: 2),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38, offset: Offset(0, 6))],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pioche (gauche uniquement)
            const Positioned(right: 16, child: _DeckStackBack(count: 12)),

            // Badge Demande
            if (demandedSuit != null)
              Positioned(top: 16, child: _DemandedBadge(suit: demandedSuit!)),

            // Icône TROUVER — centrée au-dessus du pli
            if (foundSuit != null)
              Positioned(top: 58, child: _GlobalFoundChip(suit: foundSuit!, owner: foundOwner ?? '')),

            // Pli en cours — AnimatedAlign plus lente pour ramassage fluide
            AnimatedAlign(
              alignment: collecting ? const Alignment(0, 0.65) : const Alignment(0, -0.08),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: tableOpp == null ? const SizedBox(width: 84, height: 116)
                  : _PlayedCard(key: ValueKey('opp_${tableOpp!.face}_$collecting'), card: tableOpp!),
            ),
            AnimatedAlign(
              alignment: collecting ? const Alignment(0, 0.65) : const Alignment(0, 0.12),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: tableMe == null ? const SizedBox(width: 84, height: 116)
                  : _PlayedCard(key: ValueKey('me_${tableMe!.face}_$collecting'), card: tableMe!),
            ),

            // Lock visuel
            if (lockActive)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ---------- Carte jouée avec animation d’apparition (plus lente) ----------
class _PlayedCard extends StatelessWidget {
  final _UiCard card;
  const _PlayedCard({super.key, required this.card});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: _TableCard(card: card),
    );
  }
}

// ---------- Tas de pioche (dos) ----------
class _DeckStackBack extends StatelessWidget {
  final int count;
  const _DeckStackBack({required this.count});
  @override
  Widget build(BuildContext context) {
    const w = 58.0, h = 84.0, dx = 6.0;
    final n = count.clamp(0, 6);
    return SizedBox(
      width: w + (n - 1) * dx, height: h,
      child: Stack(children: List.generate(n, (i) => Positioned(
        left: i * dx,
        child: Container(
          width: w, height: h,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
        ),
      ))),
    );
  }
}

// ---------- Badge TROUVER global (animé) ----------
class _GlobalFoundChip extends StatefulWidget {
  final String suit;   // ♥ ♦ ♣ ♠
  final String owner;  // Joueur / Adversaire
  const _GlobalFoundChip({required this.suit, required this.owner});
  @override
  State<_GlobalFoundChip> createState() => _GlobalFoundChipState();
}
class _GlobalFoundChipState extends State<_GlobalFoundChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isRed = widget.suit == '♥' || widget.suit == '♦';
    return ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.06).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.32),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black54, offset: Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.suit,
              style: TextStyle(fontSize: 26, color: isRed ? Colors.red.shade300 : Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text('Trouver • ${widget.owner}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ---------- Log horizontal ----------
class _LogBar extends StatelessWidget {
  final List<String> logs;
  const _LogBar({required this.logs});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Center(child: Text(logs[i], style: const TextStyle(color: Colors.white))),
      ),
    );
  }
}
