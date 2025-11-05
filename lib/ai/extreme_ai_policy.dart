
import '../models/card_model.dart';
import '../models/game_mode.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';

typedef RankStrengthFn = int Function(CardModel c);
typedef RankStrengthOfRankFn = int Function(Rank r);
typedef DetermineTrickWinnerFn = int Function(
    List<PlayerModel> players,
    List<CardModel> twoCards,
    int startingPlayerIndex,
    );
typedef FoundNextTrickHeuristicFn = double Function({
required GameState s,
required String botId,
required CardModel play,
});

class ExtremeAiConfig {
  final RankStrengthFn rankStrength;
  final RankStrengthOfRankFn rankStrengthOfRank;
  final DetermineTrickWinnerFn determineTrickWinner;
  final FoundNextTrickHeuristicFn foundNextTrickHeuristic;

  const ExtremeAiConfig({
    required this.rankStrength,
    required this.rankStrengthOfRank,
    required this.determineTrickWinner,
    required this.foundNextTrickHeuristic,
  });
}

class ExtremeAiPolicy {
  // Poids de base (modulés par contexte ensuite)
  static const double _W_TRICK_TEN   = 2.0;
  static const double _W_TRICK_NINE  = 1.6;
  static const double _W_TRICK_ACE   = 2.8;
  static const double _W_TEMPO       = 0.9;
  static const double _W_DRAW        = 0.7;
  static const double _W_FOUND_BIAS  = 1.0;
  static const double _W_RULE_11     = 2.0;
  static const double _W_KEEP_ACE    = 0.7;
  static const double _W_PARITY      = 0.8;

  final ExtremeAiConfig cfg;

  ExtremeAiPolicy(this.cfg);

  // ================= API principale =================
  CardModel chooseBotCard({
    required GameState s,
    required String botId,
    required Map<String, Set<Suit>> voidsByPlayer,
  }) {
    final hand = List<CardModel>.from(s.hands[botId] ?? const []);
    assert(hand.isNotEmpty);

    final trick = s.currentTrick;
    final leadSuit = trick.isEmpty ? null : trick.first.suit;
    bool canFollow(CardModel c) => leadSuit == null || c.suit == leadSuit;

    final followables = hand.where(canFollow).toList(growable: false);
    final offSuit = hand.where((c) => !canFollow(c)).toList(growable: false);
    final legal = followables.isNotEmpty ? followables : offSuit;
    if (legal.length == 1) return legal.first;

    final botIdx = s.players.indexWhere((p) => p.id == botId);
    final oppIdx = 1 - botIdx;
    final oppId = s.players[oppIdx].id;

    final scalers = _scalersForContext(s, botId, oppId);
    final int depth = _suggestDepth(s);

    // ordering initial : gagner "juste au-dessus" d'abord
    final ordered = List<CardModel>.from(legal);
    ordered.sort((a, b) {
      if (trick.isNotEmpty && leadSuit != null) {
        final lead = trick.first;
        final winA = (a.suit == lead.suit) && (cfg.rankStrength(a) > cfg.rankStrength(lead));
        final winB = (b.suit == lead.suit) && (cfg.rankStrength(b) > cfg.rankStrength(lead));
        if (winA != winB) return winB ? 1 : -1;
      }
      return cfg.rankStrength(b).compareTo(cfg.rankStrength(a));
    });

    // beam pruning
    final int beam = depth >= 3 ? 5 : 8;
    final beamMoves = ordered.length > beam ? ordered.sublist(0, beam) : ordered;

    CardModel? best;
    double bestScore = -1e9;

    for (final m in beamMoves) {
      final scMove = _evaluateMoveWithLookahead(
        s: s,
        botId: botId,
        voidsByPlayer: voidsByPlayer,
        move: m,
        depth: depth,
        scalers: scalers,
      );
      if (scMove > bestScore) {
        bestScore = scMove;
        best = m;
      }
    }

    return best ?? ordered.first;
  }

  // ================= Évaluation avec lookahead =================
  double _evaluateMoveWithLookahead({
    required GameState s,
    required String botId,
    required Map<String, Set<Suit>> voidsByPlayer,
    required CardModel move,
    required int depth,
    required _Scalers scalers,
  }) {
    // biais "trouver" au nœud racine
    double foundBias = 0.0;
    try {
      foundBias = cfg.foundNextTrickHeuristic(s: s, botId: botId, play: move) * _W_FOUND_BIAS * scalers.found;
    } catch (_) {}

    // lite state pour simuler
    final lite = _Lite.fromGameState(
      s,
      detWinner: cfg.determineTrickWinner,
      rankStrength: cfg.rankStrength,
    );

    final botIdx = lite.botIndexFor(botId);
    final oppIdx = 1 - botIdx;
    final oppId = lite.players[oppIdx].id;

    final bool pressure11 = _endgamePressureFor11(s, oppId);
    final bool aiming4As =
    _aimingFourAcesNow(lite.hands[botId] ?? const <CardModel>[]);

    final score = _scoreMoveRecursive(
      lite: lite,
      botId: botId,
      move: move,
      depth: depth,
      alpha: -1e9,
      beta: 1e9,
      scalers: scalers,
      pressure11: pressure11,
      aiming4As: aiming4As,
      voidsByPlayer: voidsByPlayer,
      rootState: s,
    );

    return score + foundBias;
  }

  double _scoreMoveRecursive({
    required _Lite lite,
    required String botId,
    required CardModel move,
    required int depth,
    required double alpha,
    required double beta,
    required _Scalers scalers,
    required bool pressure11,
    required bool aiming4As,
    required Map<String, Set<Suit>> voidsByPlayer,
    required GameState rootState,
  }) {
    final current = lite.currentPlayerId();
    final legals = lite.legalMovesFor(current);
    if (!legals.any((c) => c.id == move.id)) return -9999.0;

    final next = lite.clone();
    next.playCard(current, move);

    double scoreImmediate = 0.0;

    if (next.currentTrick.length == 2 || next.justResolved) {
      final trickVal = _trickPointishValue(next.lastResolvedTrick, scalers);
      final botWins = next.lastWinnerIndex == next.botIndexFor(botId);

      scoreImmediate += (botWins ? trickVal : -trickVal) * scalers.points;

      if (next.lastDeckDrawWinner != null) {
        final CardModel? botGets = botWins ? next.lastDrawWinnerCard : next.lastDrawLoserCard;
        final CardModel? oppGets = botWins ? next.lastDrawLoserCard : next.lastDrawWinnerCard;
        if (botGets != null) scoreImmediate += _W_DRAW * scalers.draw * _drawCardUtility(botGets, aiming4As);
        if (oppGets != null) scoreImmediate -= _W_DRAW * 0.65 * scalers.draw * _drawCardUtility(oppGets, false);
        if (botWins && botGets != null) scoreImmediate += _W_TEMPO * scalers.tempo;
      }

      if (pressure11 && !botWins && trickVal > 0) {
        scoreImmediate -= _W_RULE_11 * scalers.rule11 * trickVal;
      }
      if (aiming4As && move.rank == Rank.ace && trickVal < _W_TRICK_TEN) {
        scoreImmediate -= _W_KEEP_ACE * scalers.keepAce;
      }

      if (lite.isRoot && _givesForcedOpponentFound(rootState, botId, move)) {
        scoreImmediate -= 2.2 * scalers.found;
      }

      if (next.deck.isEmpty) {
        final totalRest = next.hands.values.fold<int>(0, (a, b) => a + b.length);
        if (totalRest <= 6 && botWins) scoreImmediate += _W_PARITY * scalers.parity;
      }
    }

    if (depth <= 1 || next.isTerminal()) return scoreImmediate;

    final turnId = next.currentPlayerId();
    List<CardModel> moves = next.legalMovesFor(turnId);

    final leadSuit = next.currentTrick.isEmpty ? null : next.currentTrick.first.suit;
    moves.sort((a, b) {
      if (leadSuit != null) {
        final winA = a.suit == leadSuit && lite.rankStrength(a) > lite.rankStrength(next.currentTrick.first);
        final winB = b.suit == leadSuit && lite.rankStrength(b) > lite.rankStrength(next.currentTrick.first);
        if (winA != winB) return winB ? 1 : -1;
      } else {
        final oppId = next.opponentIdOf(turnId);
        final voidOpp = voidsByPlayer[oppId] ?? const {};
        final aVoid = voidOpp.contains(a.suit);
        final bVoid = voidOpp.contains(b.suit);
        if (aVoid != bVoid) return aVoid ? -1 : 1;
      }
      return lite.rankStrength(b).compareTo(lite.rankStrength(a));
    });

    final int beam = depth >= 3 ? 5 : 8;
    if (moves.length > beam) moves = moves.sublist(0, beam);

    final isBotTurn = turnId == botId;
    double best = isBotTurn ? -1e9 : 1e9;

    for (final m in moves) {
      final val = _scoreMoveRecursive(
        lite: next,
        botId: botId,
        move: m,
        depth: depth - 1,
        alpha: alpha,
        beta: beta,
        scalers: scalers,
        pressure11: pressure11,
        aiming4As: aiming4As,
        voidsByPlayer: voidsByPlayer,
        rootState: rootState,
      );

      final cand = scoreImmediate + val;
      if (isBotTurn) {
        if (cand > best) best = cand;
        if (best > alpha) alpha = best;
        if (beta <= alpha) break;
      } else {
        if (cand < best) best = cand;
        if (best < beta) beta = best;
        if (beta <= alpha) break;
      }
    }

    return best;
  }

  // ================= Heuristiques & utilitaires =================
  bool _endgamePressureFor11(GameState s, String oppId) {
    final h0 = s.hands[s.players[0].id]?.length ?? 0;
    final h1 = s.hands[s.players[1].id]?.length ?? 0;
    final endgame = s.deck.isEmpty && (h0 <= 3 && h1 <= 3);
    final wonOpp = s.wonCards[oppId] ?? const <CardModel>[];
    final oppHasPoints = wonOpp.any((c) => c.rank == Rank.ten || c.rank == Rank.nine || c.rank == Rank.ace);
    return endgame && !oppHasPoints;
  }

  bool _aimingFourAcesNow(List<CardModel> myHand) {
    final aces = myHand.where((c) => c.rank == Rank.ace).length;
    return aces >= 2;
  }

  bool _givesForcedOpponentFound(GameState s, String botId, CardModel move) {
    try {
      final oppIndex = 1 - s.players.indexWhere((p) => p.id == botId);
      final oppId = s.players[oppIndex].id;
      final biasForOpp = cfg.foundNextTrickHeuristic(s: s, botId: oppId, play: move);
      return biasForOpp > 0.75;
    } catch (_) {
      return false;
    }
  }

  double _cardPointishValue(CardModel c) {
    if (c.rank == Rank.ten)  return _W_TRICK_TEN;
    if (c.rank == Rank.nine) return _W_TRICK_NINE;
    if (c.rank == Rank.ace)  return _W_TRICK_ACE;
    return 0.0;
  }

  double _drawCardUtility(CardModel c, bool aimingFourAces) {
    double u = 0.0;
    u += cfg.rankStrength(c) * 0.08;
    u += _cardPointishValue(c);
    if (aimingFourAces && c.rank == Rank.ace) u += _W_KEEP_ACE;
    return u;
  }

  double _trickPointishValue(List<CardModel> trick, _Scalers sc) {
    double v = 0.0;
    for (final c in trick) {
      v += _cardPointishValue(c);
    }
    return v * sc.points;
  }

  int _suggestDepth(GameState s) {
    final h0 = s.hands[s.players[0].id]?.length ?? 0;
    final h1 = s.hands[s.players[1].id]?.length ?? 0;
    if (s.deck.isEmpty && (h0 <= 3 && h1 <= 3)) return 3;
    if (s.deck.isEmpty) return 2;
    return 2;
  }

  _Scalers _scalersForContext(GameState s, String botId, String oppId) {
    final int myScore = s.scores[botId] ?? 0;
    final int oppScore = s.scores[oppId] ?? 0;
    final int diff = myScore - oppScore;

    double points = 1.0, tempo = 1.0, draw = 1.0, found = 1.0, rule11 = 1.0, keepAce = 1.0, parity = 1.0;

    final bool scoreMode    = (s.mode == GameMode.score || s.mode == GameMode.mixed);
    final bool sequenceMode = (s.mode == GameMode.sequence || s.mode == GameMode.mixed);

    if (scoreMode) {
      if (diff > 0) {
        found *= 0.85; tempo *= 0.95; draw *= 0.95; points *= 1.1;
      } else if (diff < 0) {
        found *= 1.15; tempo *= 1.05; draw *= 1.05;
      }
    }
    if (sequenceMode) {
      tempo *= 1.1; parity *= 1.1;
    }

    return _Scalers(points: points, tempo: tempo, draw: draw, found: found, rule11: rule11, keepAce: keepAce, parity: parity);
  }
}

// ================= Structures internes de simulation =================
class _Lite {
  final List<PlayerModel> players;
  final Map<String, List<CardModel>> hands;
  final List<CardModel> deck;
  int startingPlayerIndex;
  List<CardModel> currentTrick;

  // callbacks
  final DetermineTrickWinnerFn detWinner;
  final RankStrengthFn rankStrength;

  // mémos pli résolu
  List<CardModel> lastResolvedTrick = const [];
  int? lastWinnerIndex;
  String? lastDeckDrawWinner;
  CardModel? lastDrawWinnerCard;
  CardModel? lastDrawLoserCard;
  bool justResolved = false;

  bool isRoot = true;

  _Lite({
    required this.players,
    required this.hands,
    required this.deck,
    required this.startingPlayerIndex,
    required this.currentTrick,
    required this.detWinner,
    required this.rankStrength,
  });

  factory _Lite.fromGameState(
      GameState s, {
        required DetermineTrickWinnerFn detWinner,
        required RankStrengthFn rankStrength,
      }) {
    return _Lite(
      players: List<PlayerModel>.from(s.players),
      hands: {for (final p in s.players) p.id: List<CardModel>.from(s.hands[p.id] ?? const [])},
      deck: List<CardModel>.from(s.deck),
      startingPlayerIndex: s.currentTurnIndex,
      currentTrick: List<CardModel>.from(s.currentTrick),
      detWinner: detWinner,
      rankStrength: rankStrength,
    );
  }

  _Lite clone() {
    final c = _Lite(
      players: players,
      hands: {for (final e in hands.entries) e.key: List<CardModel>.from(e.value)},
      deck: List<CardModel>.from(deck),
      startingPlayerIndex: startingPlayerIndex,
      currentTrick: List<CardModel>.from(currentTrick),
      detWinner: detWinner,
      rankStrength: rankStrength,
    );
    c.isRoot = false;
    return c;
  }

  int botIndexFor(String botId) => players.indexWhere((p) => p.id == botId);
  String currentPlayerId() => players[_turnIndex()].id;
  String opponentIdOf(String pid) {
    final idx = players.indexWhere((p) => p.id == pid);
    return players[1 - idx].id;
  }

  int _turnIndex() {
    if (currentTrick.isEmpty) return startingPlayerIndex;
    return 1 - startingPlayerIndex;
  }

  bool isTerminal() {
    final a = hands[players[0].id]?.isEmpty ?? true;
    final b = hands[players[1].id]?.isEmpty ?? true;
    return deck.isEmpty && a && b && currentTrick.isEmpty;
  }

  List<CardModel> legalMovesFor(String playerId) {
    final hand = hands[playerId] ?? const <CardModel>[];
    if (hand.isEmpty) return const <CardModel>[];
    if (currentTrick.isEmpty) return List<CardModel>.from(hand);
    final leadSuit = currentTrick.first.suit;
    final follow = hand.where((c) => c.suit == leadSuit).toList(growable: false);
    return follow.isNotEmpty ? follow : List<CardModel>.from(hand);
  }

  void playCard(String playerId, CardModel card) {
    final hand = hands[playerId]!;
    final idx = hand.indexWhere((c) => c.id == card.id);
    if (idx >= 0) hand.removeAt(idx);
    currentTrick.add(card);
    justResolved = false;

    if (currentTrick.length == 2) {
      resolveTrickIfComplete();
    }
  }

  void resolveTrickIfComplete() {
    if (currentTrick.length != 2) return;

    final winIdx = detWinner(players, currentTrick, startingPlayerIndex);
    lastWinnerIndex = winIdx;
    lastResolvedTrick = List<CardModel>.from(currentTrick);
    justResolved = true;

    lastDeckDrawWinner = players[winIdx].id;
    if (deck.isNotEmpty) {
      lastDrawWinnerCard = deck.removeAt(0);
      hands[lastDeckDrawWinner]!.add(lastDrawWinnerCard!);
    } else {
      lastDrawWinnerCard = null;
    }
    final loserIdx = 1 - winIdx;
    final loserId = players[loserIdx].id;
    if (deck.isNotEmpty) {
      lastDrawLoserCard = deck.removeAt(0);
      hands[loserId]!.add(lastDrawLoserCard!);
    } else {
      lastDrawLoserCard = null;
    }

    startingPlayerIndex = winIdx;
    currentTrick.clear();
  }
}

class _Scalers {
  final double points, tempo, draw, found, rule11, keepAce, parity;
  const _Scalers({
    required this.points,
    required this.tempo,
    required this.draw,
    required this.found,
    required this.rule11,
    required this.keepAce,
    required this.parity,
  });
}
