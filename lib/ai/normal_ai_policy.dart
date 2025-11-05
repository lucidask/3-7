import '../models/card_model.dart';
import '../models/game_state.dart';

typedef RankStrengthFn = int Function(CardModel c);
typedef RankStrengthOfRankFn = int Function(Rank r);
typedef FoundNextTrickHeuristicFn = double Function({
required GameState s,
required String botId,
required CardModel play,
});

class NormalAiConfig {
  final RankStrengthFn rankStrength;
  final RankStrengthOfRankFn rankStrengthOfRank;
  final FoundNextTrickHeuristicFn foundNextTrickHeuristic;

  const NormalAiConfig({
    required this.rankStrength,
    required this.rankStrengthOfRank,
    required this.foundNextTrickHeuristic,
  });
}

class NormalAiPolicy {
  // Poids soft
  static const double _W_FOUND     = 0.8;
  static const double _W_DRAW_SOFT = 0.35; // petit biais pioche

  final NormalAiConfig cfg;

  NormalAiPolicy(this.cfg);

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
    final followables = hand.where(canFollow).toList(growable: false);
    final offSuit     = hand.where((c) => !canFollow(c)).toList(growable: false);

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

    // Biais "trouver"
    double foundBias(CardModel c) {
      try {
        return _W_FOUND * cfg.foundNextTrickHeuristic(s: s, botId: botId, play: c);
      } catch (_) { return 0.0; }
    }

    // Petit biais pioche (sans lookahead) : si on gagne ce pli et deck[0] a l'air bon
    double drawBiasIfWinningLead(CardModel play) {
      if (trick.isNotEmpty || s.deck.isEmpty) return 0.0;
      // bonus si on mène une carte qui a une proba décente de gagner (haute dans sa couleur)
      final myStr = cfg.rankStrength(play);
      final likelyWins = bySuit[play.suit]!.every((c) => cfg.rankStrength(c) <= myStr);
      if (!likelyWins) return 0.0;
      final top = s.deck.first;
      final val = (cfg.rankStrength(top) * 0.03) + ((top.rank == Rank.ace) ? 0.25 : 0.0);
      return _W_DRAW_SOFT * val;
    }

    // --- NORMAL boosté ---
    if (followables.isNotEmpty) {
      if (trick.isEmpty) {
        // Lead : éviter de brûler un As si possible, et profiter d’un void adverse si connu
        // 1) couleur où l’adversaire est (probablement) sec
        for (final su in Suit.values) {
          final inS = bySuit[su]!;
          if (inS.isEmpty) continue;
          final oppVoid = (voidsByPlayer[s.players[1 - s.players.indexWhere((p) => p.id == botId)].id] ?? const {}).contains(su);
          if (oppVoid) {
            final nonA = inS.where((c) => !isAce(c)).toList();
            final pool = nonA.isNotEmpty ? nonA : inS;
            pool.sort((a,b)=>cfg.rankStrength(a).compareTo(cfg.rankStrength(b))); // low lead
            return _pickWithBias(pool, extra:(c)=>foundBias(c)+drawBiasIfWinningLead(c));
          }
        }
        // 2) sinon, mener sa couleur la plus fournie (non-As d'abord)
        Suit? best; var cnt = -1;
        for (final su in Suit.values) { final c = bySuit[su]!.length; if (c > cnt) { best = su; cnt = c; } }
        final inBest = bySuit[best]!;
        final nonA = inBest.where((c) => !isAce(c)).toList();
        final pool = nonA.isNotEmpty ? nonA : inBest;
        return _pickWithBias(pool, extra:(c)=>foundBias(c)+drawBiasIfWinningLead(c));
      } else {
        // Second à jouer : gagner « juste au-dessus » sinon sous-jouer
        final win = firstWinningOver(trick.first, followables);
        if (win != null && win.rank != Rank.ace) return win;
        if (win != null && win.rank == Rank.ace) {
          // si As obligatoire, ok, sinon essayer une alternative un poil au-dessus sans être As
          final alts = followables.where((c) =>
          c.suit == trick.first.suit &&
              cfg.rankStrength(c) > cfg.rankStrength(trick.first) &&
              c.rank != Rank.ace
          );
          if (alts.isNotEmpty) return _pickWithBias(alts, extra: foundBias);
          return win;
        }
        // pas possible de gagner : jouer la plus petite
        return _pickWithBias(followables, extra: foundBias, base:(c)=>-cfg.rankStrength(c).toDouble());
      }
    } else {
      // Défausse : éviter de jeter 10/9/As sans raison
      final safe = offSuit.where((c) => c.rank != Rank.ten && c.rank != Rank.nine && c.rank != Rank.ace).toList();
      final pool = safe.isNotEmpty ? safe : offSuit;
      return _pickWithBias(pool, extra: foundBias, base:(c)=>-cfg.rankStrength(c).toDouble());
    }
  }

  // ---- utils ----
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
