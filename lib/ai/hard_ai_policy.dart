import '../models/card_model.dart';
import '../models/game_state.dart';

typedef RankStrengthFn = int Function(CardModel c);
typedef RankStrengthOfRankFn = int Function(Rank r);
typedef FoundNextTrickHeuristicFn = double Function({
required GameState s,
required String botId,
required CardModel play,
});

class HardAiConfig {
  final RankStrengthFn rankStrength;
  final RankStrengthOfRankFn rankStrengthOfRank;
  final FoundNextTrickHeuristicFn foundNextTrickHeuristic;

  const HardAiConfig({
    required this.rankStrength,
    required this.rankStrengthOfRank,
    required this.foundNextTrickHeuristic,
  });
}

class HardAiPolicy {
  static const double _W_FOUND       = 1.0;
  static const double _W_DRAW        = 0.6;

  final HardAiConfig cfg;

  HardAiPolicy(this.cfg);

  CardModel chooseBotCard({
    required GameState s,
    required String botId,
    required Map<String, Set<Suit>> voidsByPlayer,
  }) {
    final hand = List<CardModel>.from(s.hands[botId] ?? const []);
    final trick = s.currentTrick;
    final leadSuit = trick.isEmpty ? null : trick.first.suit;

    bool isAce(CardModel c) => c.rank == Rank.ace;
    bool canFollow(CardModel c) => leadSuit == null || c.suit == leadSuit;

    // Groupes
    final bySuit = {for (final su in Suit.values) su: <CardModel>[]};
    for (final c in hand) { bySuit[c.suit]!.add(c); }
    final myCount = {for (final su in Suit.values) su: bySuit[su]!.length};

    final followables = hand.where(canFollow).toList(growable: false);
    final offSuit     = hand.where((c) => !canFollow(c)).toList(growable: false);

    // Adversaire
    final botIdx = s.players.indexWhere((p) => p.id == botId);
    final oppIdx = 1 - botIdx;
    final oppId  = s.players[oppIdx].id;
    bool opponentVoidLikely(Suit suit) => (voidsByPlayer[oppId]?.contains(suit) ?? false);

    // Contexte fin de manche (pression 11) et “4 As”
    bool endgamePressure() {
      final h0 = s.hands[s.players[0].id]?.length ?? 0;
      final h1 = s.hands[s.players[1].id]?.length ?? 0;
      return s.deck.isEmpty && (h0 <= 3 && h1 <= 3);
    }
    bool oppAtZeroSoFar() {
      final wonOpp = s.wonCards[oppId] ?? const <CardModel>[];
      return !wonOpp.any((c) => c.rank == Rank.ten || c.rank == Rank.nine || c.rank == Rank.ace);
    }
    final pressureFor11 = endgamePressure() && oppAtZeroSoFar();
    final aimingFourAces = hand.where((c)=>c.rank==Rank.ace).length >= 2;

    // Helpers
    CardModel? firstWinningOver(CardModel target, Iterable<CardModel> inSuit) {
      final t = cfg.rankStrength(target);
      CardModel? pick; int? above;
      for (final c in inSuit) {
        if (c.suit != target.suit) continue;
        final s0 = cfg.rankStrength(c);
        if (s0 > t && (above == null || s0 < above)) { above = s0; pick = c; }
      }
      return pick;
    }

    double foundBias(CardModel c) {
      try {
        return _W_FOUND * cfg.foundNextTrickHeuristic(s: s, botId: botId, play: c);
      } catch (_) { return 0.0; }
    }

    // Deck-aware : si on gagne et deck[0] est “bon”, bonus ; si on perd et deck[1] “bon”, petit malus
    double drawBias(CardModel play, {required bool assumeWinIfLead}) {
      if (s.deck.isEmpty) return 0.0;
      if (trick.isEmpty && assumeWinIfLead) {
        final top = s.deck.first;
        return _W_DRAW * ((cfg.rankStrength(top) * 0.03) + ((top.rank==Rank.ace)?0.3:0.0));
      }
      return 0.0;
    }

    // === HARD boosté ===
    if (followables.isNotEmpty) {
      if (trick.isEmpty) {
        // 1) Exploiter un void adverse si possible (lead bas, éviter As)
        for (final su in Suit.values) {
          if ((myCount[su] ?? 0) > 0 && opponentVoidLikely(su)) {
            final inS = bySuit[su]!;
            final low = inS.where((c) => !isAce(c)).toList();
            final pool = low.isNotEmpty ? low : inS;
            pool.sort((a,b)=>cfg.rankStrength(a).compareTo(cfg.rankStrength(b)));
            return _pickWithBias(pool, extra:(c)=>foundBias(c)+drawBias(c, assumeWinIfLead:true));
          }
        }
        // 2) Sinon, couleur la plus longue (évite de cramer As si 4As en vue)
        Suit? best; var cnt = -1;
        for (final su in Suit.values) { final c = myCount[su] ?? 0; if (c > cnt) { best = su; cnt = c; } }
        final inBest = bySuit[best]!;
        final nonA = aimingFourAces ? inBest.where((c) => !isAce(c)).toList() : <CardModel>[];
        final pool = (aimingFourAces && nonA.isNotEmpty) ? nonA : inBest;
        // lead plutôt bas, mais pas la toute plus basse si on veut garder un « juste au-dessus »
        pool.sort((a,b)=>cfg.rankStrength(a).compareTo(cfg.rankStrength(b)));
        final pick = _pickWithBias(pool, extra:(c)=>foundBias(c)+drawBias(c, assumeWinIfLead:true));
        return pick;
      } else {
        // Second : gagner « juste au-dessus », sinon sous-jouer
        final win = firstWinningOver(trick.first, followables);
        if (win != null) {
          // préférer un non-As si possible
          if (isAce(win)) {
            final alts = followables.where((c) =>
            c.suit == trick.first.suit && cfg.rankStrength(c) > cfg.rankStrength(trick.first) && !isAce(c));
            if (alts.isNotEmpty) return _pickWithBias(alts, extra: foundBias);
            // pression 11 : autoriser As pour bloquer des points
            if (pressureFor11) return win;
          }
          return win;
        }
        // impossible de gagner
        // pression 11 : éviter de jeter 10/9/As si l’adversaire prend des points
        final losing = followables.toList();
        if (pressureFor11) {
          losing.sort((a,b){
            int pa = _pointish(a); int pb = _pointish(b);
            if (pa!=pb) return pa.compareTo(pb); // jette d'abord non-points
            return cfg.rankStrength(a).compareTo(cfg.rankStrength(b));
          });
          return _pickWithBias(losing, extra: foundBias);
        }
        // sinon, la plus petite
        losing.sort((a,b)=>cfg.rankStrength(a).compareTo(cfg.rankStrength(b)));
        return _pickWithBias(losing, extra: foundBias);
      }
    } else {
      // Défausse
      final notVoid = offSuit.where((c) => !opponentVoidLikely(c.suit)).toList();
      var pool = notVoid.isNotEmpty ? notVoid : offSuit;

      if (pressureFor11) {
        // jette d'abord cartes sans points, puis plus petites
        pool.sort((a,b){
          int pa = _pointish(a), pb = _pointish(b);
          if (pa!=pb) return pa.compareTo(pb);
          return cfg.rankStrength(a).compareTo(cfg.rankStrength(b));
        });
        return _pickWithBias(pool, extra: foundBias);
      }

      // Sinon : décide si on veut garder les grosses ou s’en débarrasser
      // Ici on préfère s’alléger des grosses perdantes (sans points) d’abord
      pool.sort((a,b){
        int pa = _pointish(a), pb = _pointish(b);
        if (pa!=pb) return pa.compareTo(pb); // non-points avant points
        // parmi non-points, jeter la plus haute
        return cfg.rankStrength(b).compareTo(cfg.rankStrength(a));
      });
      return _pickWithBias(pool, extra: foundBias);
    }
  }

  // ---- utils ----
  int _pointish(CardModel c) {
    if (c.rank == Rank.ten) return 3;
    if (c.rank == Rank.nine) return 2;
    if (c.rank == Rank.ace) return 4;
    return 0;
  }

  CardModel _pickWithBias(Iterable<CardModel> cards, {double Function(CardModel)? base, double Function(CardModel)? extra}) {
    CardModel best = cards.first; double bestScore = -1e9;
    for (final c in cards) {
      final b = base!=null ? base(c) : 0.0;
      final e = extra!=null ? extra(c) : 0.0;
      final sc = b + e;
      if (sc > bestScore) { bestScore = sc; best = c; }
    }
    return best;
  }
}
