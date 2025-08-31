import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_seven/providers/settings_provider.dart';
import '../models/bot_difficulty.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/game_mode.dart';
import '../models/card_model.dart';
import '../utils/deck_utils.dart';
import '../utils/rules.dart';
import '../utils/scoring.dart';

import '../services/game_save_service.dart';
import '../utils/game_state_codec.dart';

const List<Rank> kRankOrderAsc = <Rank>[
  Rank.seven,
  Rank.eight,
  Rank.jack,
  Rank.queen,
  Rank.king,
  Rank.ace,
  Rank.nine,
  Rank.ten,
];

@pragma('vm:prefer-inline')
int rankStrengthOfRank(Rank r) => kRankOrderAsc.indexOf(r) + 1;
@pragma('vm:prefer-inline')
int rankStrength(CardModel c) => rankStrengthOfRank(c.rank);

final gameControllerProvider =
StateNotifierProvider<GameController, GameState?>((ref) => GameController(ref));

class GameController extends StateNotifier<GameState?> {
  final Ref ref;
  GameController(this.ref) : super(null);
  /// Replace the current game state (used when resuming a saved game).
  void restore(GameState restored) {
    state = restored;
    _resetVoidsByPlayer(); // purge les caches volatils du bot si tu en as
  }

  /// Cancel any ongoing game and clear in-memory state.
  void cancelCurrentGame() {
    state = null;
    _voidsByPlayer.clear(); // idem, on repart propre
  }

  // === Auto-save helper ===
  Future<void> _saveAuto({bool force = false}) async {
    final st = state;
    if (st == null) return;
    try {
      final snapshot = GameStateCodec.toSnapshot(st);
      await GameSaveService().save(snapshot, force: force);
    } catch (_) {
      // If codec not ready, ignore silently; we never block gameplay.
    }
  }
// ====== CONFIG Expert ======
  static const int expertSamples = 384; // nombre d'échantillons Monte-Carlo (ULTRA-DUR)
  static const int expertDepth = 3;    // profondeur en plis (bot->opp) — ULTRA-DUR
  static const bool expertAdversarial = true; // l'IA suppose un adversaire qui répond au mieux

  int _nextStarterIndex = -1;
  BotDifficulty _difficulty = BotDifficulty.normal;

  final Map<String, Set<Suit>> _voidsByPlayer = {};
  void _resetVoidsByPlayer() {
    _voidsByPlayer.clear();
    final st = state;
    if (st == null) return;
    for (final p in st.players) {
      _voidsByPlayer[p.id] = <Suit>{};
    }
  }

  void setBotDifficulty(BotDifficulty d) {
    _difficulty = d;
    final st = state;
    if (st != null) state = st.copyWith(botDifficulty: d);
  }

  Future<void> startLocalGame({GameMode mode = GameMode.mixed}) async {
    _botPaused = true;
    cancelBotTurnTimer();
    const p1 = PlayerModel(id: 'p1', nickname: 'You', type: PlayerType.human);
    const p2 = PlayerModel(id: 'p2', nickname: 'Bot', type: PlayerType.bot);

    final deck = buildDeck32();
    shuffleDeck(deck);
    final dealt = dealTwoHands(deck);

    final startingIndex = _decideStartingIndex([p1, p2]);

    final scores = {p1.id: 0, p2.id: 0};
    final streaks = {p1.id: 0, p2.id: 0};

    final initialSeen = {for (final s in Suit.values) s: <Rank>{}};

    state = GameState(
      players: [p1, p2],
      scores: scores,
      deck: dealt.drawPile,
      hands: {
        p1.id: List<CardModel>.from(dealt.p1),
        p2.id: List<CardModel>.from(dealt.p2),
      },
      currentTrick: const [],
      currentTrickOwners: const [],
      drawPileAvailable: true,
      currentTurnIndex: startingIndex,
      mode: mode,
      startingPlayerIndex: startingIndex,
      infoMessage: '',
      roundNo: 1,
      lastTrick: const [],
      lastTrickWinnerIndex: null,
      wonCards: {p1.id: <CardModel>[], p2.id: <CardModel>[]},
      lastRoundWonCards: const {},
      consecutiveWins: streaks,
      matchOver: false,
      winnerId: null,
      findJustHappened: false,
      findPlayerId: null,
      findSuit: null,
      findIsStrong: null,
      botDifficulty: _difficulty,
      seenCards: initialSeen,
    );

    _resetVoidsByPlayer();
      await _saveAuto();
  }

  void _resetRoundWithStarter(int starterIndex, {bool increment = false}) {
    _botPaused = true;
    cancelBotTurnTimer();
    final st = state;
    if (st == null) return;

    final deck = buildDeck32();
    shuffleDeck(deck);
    final dealt = dealTwoHands(deck);

    state = st.copyWith(
      deck: dealt.drawPile,
      hands: {
        st.players[0].id: List<CardModel>.from(dealt.p1),
        st.players[1].id: List<CardModel>.from(dealt.p2),
      },
      currentTrick: const [],
      currentTrickOwners: const [],
      drawPileAvailable: true,
      currentTurnIndex: starterIndex,
      startingPlayerIndex: starterIndex,
      lastTrick: const [],
      lastTrickWinnerIndex: null,
      wonCards: {for (final p in st.players) p.id: <CardModel>[]},
      lastRoundWonCards: const {},
      findJustHappened: false,
      findPlayerId: null,
      findSuit: null,
      findIsStrong: null,
      infoMessage: '',
      roundNo: increment ? (st.roundNo + 1) : st.roundNo,
    );

    _resetVoidsByPlayer();
    _saveAuto();
  }

// Remplace l’ancienne implémentation par un simple appel à la routine commune.
  void startNextRound() {
    final st = state;
    if (st == null) return;
    if (st.matchOver) return;
    final nextStarter = st.lastTrickWinnerIndex ?? st.startingPlayerIndex;
    _resetRoundWithStarter(nextStarter, increment: true);
  }

// Nouvelle API : relance la manche actuelle (conserve le starter initial de la manche).
  void restartCurrentRound() {
    final st = state;
    if (st == null) return;
    _resetRoundWithStarter(st.startingPlayerIndex, increment: false);
  }

  List<CardModel> handOf(String playerId) => state?.hands[playerId] ?? const [];

  bool validateMove(CardModel toPlay) {
    final st = state;
    if (st == null || st.matchOver) return false;

    final currentPlayer = st.players[st.currentTurnIndex];
    final hand = st.hands[currentPlayer.id] ?? const [];

    CardModel? led;
    if (st.currentTrick.isNotEmpty) led = st.currentTrick.first;

    return isLegalMove(playerHand: hand, toPlay: toPlay, led: led);
  }

  Future<void> playCard(CardModel toPlay) async {
    final st = state;
    if (st == null || st.matchOver) return;
    if (!validateMove(toPlay)) return;

    _markCardSeen(toPlay);

    final currentPlayer = st.players[st.currentTurnIndex];

    // retirer la carte de la main du joueur courant
    final hands = {...st.hands};
    final my = List<CardModel>.from(hands[currentPlayer.id] ?? const []);
    final idx = my.indexWhere((c) => c.id == toPlay.id);
    if (idx >= 0) {
      my.removeAt(idx);
      hands[currentPlayer.id] = my;
    }

    final newTrick = List<CardModel>.from(st.currentTrick)..add(toPlay);
    final completedOwners = List<String>.from(st.currentTrickOwners)..add(currentPlayer.id);
    assert(completedOwners.length == newTrick.length);

    // 1ère carte → passer la main et publier
    if (newTrick.length == 1) {
      final newOwners = List<String>.from(st.currentTrickOwners)..add(currentPlayer.id);
      state = st.copyWith(
        hands: hands,
        currentTrick: newTrick,
        currentTrickOwners: newOwners,
        currentTurnIndex: (st.currentTurnIndex + 1) % st.players.length,
      );
      maybeScheduleBotTurn();
      return;
    }

    // =========================
    // 2 cartes → publier d'abord l'état pour afficher la 2e carte,
    //           puis résoudre le pli après un léger délai.
    // =========================

    // 1) Publier l'état avec les 2 cartes posées (sans changer le tour)
    state = st.copyWith(
      hands: hands,
      currentTrick: newTrick,
      currentTrickOwners: completedOwners,
      // currentTurnIndex inchangé ici
    );
    await _saveAuto();
    await Future.delayed(const Duration(milliseconds: 2000));

    // Sécurité minimale après le délai (partie annulée/finie entre-temps)
    final sNow = state;
    if (sNow == null || sNow.matchOver) return;

    final players = st.players;
    final winnerIndex = _determineTrickWinner(players, newTrick, st.startingPlayerIndex);
    final loserIndex = 1 - winnerIndex;
    final winnerId = players[winnerIndex].id;
    final loserId = players[loserIndex].id;

    // Ajouter le pli au gagnant
    final won = {
      for (final p in players) p.id: List<CardModel>.from(st.wonCards[p.id] ?? const [])
    };
    won[winnerId] = List<CardModel>.from(won[winnerId] ?? const [])..addAll(newTrick);

    // Suivi void : si le perdant n'a pas suivi la couleur menée
    final led = newTrick.first;
    final second = newTrick.last;
    final loserCard = (winnerIndex == st.startingPlayerIndex) ? second : led;
    final bool loserFollowed = loserCard.suit == led.suit;
    if (!loserFollowed) {
      (_voidsByPlayer[loserId] ??= <Suit>{}).add(led.suit);
    }

    // Pioche gagnant → perdant
    final deck = List<CardModel>.from(st.deck);
    if (deck.isNotEmpty) {
      final winDraw = deck.removeAt(0);
      hands[winnerId] = List<CardModel>.from(hands[winnerId] ?? const [])..add(winDraw);
    }

    // === TROUVER (définition stricte) ==========================
    String? findPlayerId;
    Suit? findSuit;

    if (deck.isNotEmpty) {
      final drawn = deck.removeAt(0);
      hands[loserId] = List<CardModel>.from(hands[loserId] ?? const [])..add(drawn);

      final firstPlayerIndex = st.startingPlayerIndex;
      final secondPlayerIndex = 1 - firstPlayerIndex;

      // Carte gagnante/perdante du pli
      final CardModel winningCard = (winnerIndex == firstPlayerIndex) ? led : second;
      final CardModel losingCard  = (winnerIndex == firstPlayerIndex) ? second : led;
      final bool loserFollowed2 = (losingCard.suit == led.suit);

      // Seul le 2e joueur peut "trouver"
      if (loserIndex == secondPlayerIndex && drawn.suit == winningCard.suit) {
        final bool found = !loserFollowed2
            || rankStrengthOfRank(drawn.rank) > rankStrengthOfRank(winningCard.rank);
        if (found) {
          findPlayerId = players[loserIndex].id;
          findSuit = drawn.suit;
        }
      }
    }
    // ===========================================================

    // Définir fin de manche : pioche vide ET mains vides
    bool bothHandsEmpty() {
      final h0 = hands[players[0].id] ?? const <CardModel>[];
      final h1 = hands[players[1].id] ?? const <CardModel>[];
      return h0.isEmpty && h1.isEmpty;
    }
    final finishedRound = deck.isEmpty && bothHandsEmpty();

    // Fin de manche ?
    if (finishedRound) {
      // --- Points de la manche ---
      final p1Id = players[0].id;
      final p2Id = players[1].id;

      final p1Round = calculatePoints(
        won[p1Id] ?? const <CardModel>[],
        lastTrickWinner: winnerId == p1Id,
      );
      final p2Round = calculatePoints(
        won[p2Id] ?? const <CardModel>[],
        lastTrickWinner: winnerId == p2Id,
      );

      final perRoundPoints = <String, int>{p1Id: p1Round, p2Id: p2Round};

      // --- Scores cumulés ---
      final newScores = {...st.scores};
      perRoundPoints.forEach((pid, pts) {
        newScores[pid] = (newScores[pid] ?? 0) + pts;
      });

      // --- Gagnant de la manche ---
      final String? roundWinnerId = (p1Round == p2Round)
          ? null
          : (p1Round > p2Round ? p1Id : p2Id);

      // --- Séries ---
      final streaks = {...st.consecutiveWins};
      if (roundWinnerId != null) {
        final loseId = roundWinnerId == p1Id ? p2Id : p1Id;
        streaks[roundWinnerId] = (streaks[roundWinnerId] ?? 0) + 1;
        streaks[loseId] = 0;
      }

      // --- Règles spéciales de fin de MATCH ---
      bool hasFourAces(List<CardModel> list) =>
          list.where((c) => c.rank == Rank.ace).length == 4;

      final bool rule11 = (p1Round == 0 || p2Round == 0);
      final bool rule4As =
          hasFourAces(won[p1Id] ?? const []) || hasFourAces(won[p2Id] ?? const []);

      // --- Seuils depuis Paramètres ---
      final int tgtScore  = ref.read(settingsProvider).scoreTarget;
      final int tgtStreak = ref.read(settingsProvider).sequencesTarget;

      // --- Conditions atteintes selon le mode ---
      final bool scoreModeActive    = (st.mode == GameMode.score || st.mode == GameMode.mixed);
      final bool sequenceModeActive = (st.mode == GameMode.sequence || st.mode == GameMode.mixed);

      final bool reachScore = scoreModeActive &&
          (((newScores[p1Id] ?? 0) >= tgtScore) || ((newScores[p2Id] ?? 0) >= tgtScore));

      final bool reachStreak = sequenceModeActive &&
          (((streaks[p1Id] ?? 0) >= tgtStreak) || ((streaks[p2Id] ?? 0) >= tgtStreak));

      // --- Qui gagne le MATCH ?
      String? matchWinnerId;
      if (rule11) {
        matchWinnerId = (p1Round == 0) ? p2Id : p1Id;
      } else if (rule4As) {
        matchWinnerId = hasFourAces(won[p1Id] ?? const []) ? p1Id : p2Id;
      } else if (reachScore) {
        matchWinnerId = (newScores[p1Id]! >= tgtScore) ? p1Id : p2Id;
      } else if (reachStreak && roundWinnerId != null) {
        matchWinnerId = roundWinnerId;
      }

      // --- Snapshot des cartes gagnées pour l’UI ---
      final snapshotWon = {
        for (final p in players) p.id: List<CardModel>.from(won[p.id] ?? const []),
      };

      state = st.copyWith(
        lastRoundWonCards: snapshotWon,
        lastRoundPoints: perRoundPoints,
        lastRoundWinnerId: roundWinnerId,
        scores: newScores,
        consecutiveWins: streaks,

        hands: {for (final p in players) p.id: <CardModel>[]},
        deck: const <CardModel>[],
        currentTrick: const <CardModel>[],
        currentTrickOwners: const <String>[],
        wonCards: {for (final p in players) p.id: <CardModel>[]},
        drawPileAvailable: false,
        infoMessage: '',

        lastTrick: newTrick,
        lastTrickWinnerIndex: winnerIndex,
        startingPlayerIndex: winnerIndex,

        findJustHappened: findPlayerId != null,
        findPlayerId: findPlayerId,
        findSuit: findSuit,
        findIsStrong: null,

        matchOver: matchWinnerId != null,
        winnerId: matchWinnerId,
      );
      await _saveAuto(force: true);
      return;
    }

    // Continuer la manche : le gagnant mène le prochain pli
    state = st.copyWith(
      hands: hands,
      deck: deck,
      currentTrick: const <CardModel>[],
      currentTrickOwners: const <String>[],
      currentTurnIndex: winnerIndex,
      startingPlayerIndex: winnerIndex,
      lastTrick: newTrick,
      lastTrickWinnerIndex: winnerIndex,
      wonCards: won,
      drawPileAvailable: deck.isNotEmpty,
      findJustHappened: findPlayerId != null,
      findPlayerId: findPlayerId,
      findSuit: findSuit,
      findIsStrong: null,
      infoMessage: '',
    );

    await _saveAuto();
    maybeScheduleBotTurn();
  }

  int _determineTrickWinner(List<PlayerModel> players, List<CardModel> trick, int startingPlayerIndex) {
    assert(trick.length == 2);
    final lead = trick[0];
    final follow = trick[1];
    final leadWins = follow.suit != lead.suit || rankStrength(lead) >= rankStrength(follow);
    return leadWins ? startingPlayerIndex : 1 - startingPlayerIndex;
  }

  int _decideStartingIndex(List<PlayerModel> players) {
    _nextStarterIndex = (_nextStarterIndex + 1) % players.length;
    return _nextStarterIndex;
  }

  void showTemporaryMessage(String message, {Duration duration = const Duration(seconds: 2)}) {
    state = state?.copyWith(infoMessage: message);
    Future.delayed(duration, () {
      final st = state;
      if (st != null && st.infoMessage == message) {
        state = st.copyWith(infoMessage: '');
      }
    });
  }

  CardModel _chooseBotCard(String botId) {
    final s = state!;
    final hand = List<CardModel>.from(s.hands[botId] ?? const []);
    assert(hand.isNotEmpty);

    final trick = s.currentTrick;
    final leadSuit = trick.isEmpty ? null : trick.first.suit;

    bool canFollow(CardModel c) => leadSuit == null || c.suit == leadSuit;
    bool isAce(CardModel c) => c.rank == Rank.ace;

    // Groupes par couleur
    final bySuit = {for (final su in Suit.values) su: <CardModel>[]};
    for (final c in hand) { bySuit[c.suit]!.add(c); }
    final myCount = {for (final su in Suit.values) su: bySuit[su]!.length};

    // Infos adversaire
    final botIndex = s.players.indexWhere((p) => p.id == botId);
    final oppIndex = 1 - botIndex;
    final oppId = s.players[oppIndex].id;

    // Helper : adversaire sec ?
    bool opponentVoidLikely(Suit suit) => _voidsByPlayer[oppId]?.contains(suit) ?? false;

    // Fin de partie (pression 11) : pioche vide et ≤3 cartes par main
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

    // Objectif "4 As"
    final myAces = hand.where((c) => c.rank == Rank.ace).length;
    final aimingFourAces = myAces >= 2;

    final followables = hand.where(canFollow).toList(growable: false);
    final offSuit = hand.where((c) => !canFollow(c)).toList(growable: false);

    // Outils sélection (noms sans underscore pour éviter warnings)
    CardModel minSel(Iterable<CardModel> cards) {
      CardModel pick = cards.first; var best = rankStrength(pick);
      for (final c in cards) { final s0 = rankStrength(c); if (s0 < best) { best = s0; pick = c; } }
      return pick;
    }
    CardModel maxSel(Iterable<CardModel> cards) {
      CardModel pick = cards.first; var best = rankStrength(pick);
      for (final c in cards) { final s0 = rankStrength(c); if (s0 > best) { best = s0; pick = c; } }
      return pick;
    }
    CardModel? firstWinningOver(CardModel target, Iterable<CardModel> inSuit) {
      final t = rankStrength(target);
      CardModel? pick; int? above;
      for (final c in inSuit) {
        if (c.suit != target.suit) continue;
        final s0 = rankStrength(c);
        if (s0 > t && (above == null || s0 < above)) { above = s0; pick = c; }
      }
      return pick;
    }

    // === NORMAL ===
    if (s.botDifficulty == BotDifficulty.normal) {
      if (followables.isNotEmpty) {
        if (trick.isEmpty) return minSel(followables);
        final win = firstWinningOver(trick.first, followables);
        return win ?? minSel(followables);
      } else {
        final safe = offSuit.where((c) => !isAce(c));
        return safe.isNotEmpty ? minSel(safe) : minSel(offSuit);
      }
    }

    // === HARD — Heuristiques fortes
    if (s.botDifficulty == BotDifficulty.hard) {
      if (followables.isNotEmpty) {
        if (trick.isEmpty) {
          // Exploiter un void adverse sinon couleur longue (non-As si possible)
          for (final su in Suit.values) {
            if ((myCount[su] ?? 0) > 0 && opponentVoidLikely(su)) {
              final inS = bySuit[su]!;
              final low = inS.where((c) => !isAce(c)).toList();
              return low.isNotEmpty ? minSel(low) : minSel(inS);
            }
          }
          Suit? best; var cnt = -1;
          for (final su in Suit.values) { final c = myCount[su] ?? 0; if (c > cnt) { best = su; cnt = c; } }
          final inBest = bySuit[best]!;
          final nonA = inBest.where((c) => !isAce(c)).toList();
          return nonA.isNotEmpty ? minSel(nonA) : minSel(inBest);
        } else {
          final win = firstWinningOver(trick.first, followables);
          if (win != null) {
            if (isAce(win)) {
              final alts = followables.where((c) => c.suit == trick.first.suit && rankStrength(c) > rankStrength(trick.first) && !isAce(c));
              if (alts.isNotEmpty) return minSel(alts);
            }
            return win;
          }
          if (pressureFor11) {
            final aces = followables.where((c) => c.suit == trick.first.suit && isAce(c) && rankStrength(c) > rankStrength(trick.first));
            if (aces.isNotEmpty) return minSel(aces);
          }
          return minSel(followables);
        }
      } else {
        final notVoid = offSuit.where((c) => !( _voidsByPlayer[oppId]?.contains(c.suit) ?? false)).toList();
        final pool = notVoid.isNotEmpty ? notVoid : offSuit;
        return pressureFor11 ? maxSel(pool) : minSel(pool);
      }
    }

    // === EXTREME — Mode EXPERT (Monte-Carlo Lookahead)
    // Fallback vers heuristiques si l'espace de recherche est minuscule (ex: 1 carte)
    if (s.botDifficulty == BotDifficulty.extreme) {
      // Si on a 1 seule carte légale, inutile de simuler
      final legal = followables.isNotEmpty ? followables : offSuit;
      if (legal.length <= 1) return legal.first;

      // Petite évaluation instantanée (si performance contrainte)
      double evalHeuristicAfterPlay(CardModel play) {
        // Favoriser: prendre 10/9/As, garder ses As si aimingFourAces, éviter de donner un pli gratuit
        double score = 0;
        if (trick.isNotEmpty && (leadSuit != null)) {
          final lead = trick.first;
          if (play.suit == lead.suit && rankStrength(play) > rankStrength(lead)) {
            score += 2.0; // on gagne probablement le pli
            if (play.rank == Rank.ten || play.rank == Rank.nine || play.rank == Rank.ace) score += 0.4; // gagner cher
          } else if (play.suit != leadSuit) {
            // défausse: se débarrasser d'une grosse perdante
            score += (rankStrength(play) >= rankStrengthOfRank(Rank.ace)) ? 0.6 : 0.2;
          }
        } else {
          // lead: éviter de brûler un As si on vise 4 As
          if (aimingFourAces && play.rank == Rank.ace) score -= 0.8;
          // lead dans couleur où l'adversaire est sec
          if (opponentVoidLikely(play.suit)) score += 0.7;
        }
        if (pressureFor11) score += 0.5; // pression générale à favoriser les gains
        return score;
      }

      // Génère un échantillon plausible de la main adverse
      List<CardModel> sampleOpponentHand(Set<String> knownBotCardIds) {
        final allIds = <String>{};
        final allCards = <CardModel>[];
        // Cartes du deck restant + main adverse inconnue
        for (final c in s.deck) { allIds.add(c.id); allCards.add(c); }
        final oppHandNow = List<CardModel>.from(s.hands[oppId] ?? const []);
        for (final c in oppHandNow) { allIds.add(c.id); allCards.add(c); }
        // Retire les cartes connues chez le bot
        allCards.removeWhere((c) => knownBotCardIds.contains(c.id));
        // Filtrer avec infos de void: si on sait que l'adversaire est sec d'une couleur, on laisse quand même
        // quelques cartes mais on réduit la probabilité. Ici, simple échantillonnage uniforme (pas pondéré).
        // Nombre de cartes adverses à avoir: longueur de sa main actuelle
        final need = oppHandNow.length;
        if (allCards.length <= need) return List<CardModel>.from(allCards);
        final rnd = math.Random();
        final picked = <CardModel>[];
        final pool = List<CardModel>.from(allCards);
        for (int i = 0; i < need; i++) {
          final j = rnd.nextInt(pool.length);
          picked.add(pool.removeAt(j));
        }
        return picked;
      }

      // Politique de réponse adverse (greedy raisonnable)
      CardModel opponentResponse(CardModel oppLead, List<CardModel> oppHand) {
        final followable = oppHand.where((c) => c.suit == oppLead.suit).toList();
        if (followable.isNotEmpty) {
          // jouer la plus petite qui gagne sinon la plus petite
          final win = firstWinningOver(oppLead, followable);
          return win ?? minSel(followable);
        } else {
          // défausse: jeter la plus forte perdante
          return maxSel(oppHand);
        }
      }

      // Évaluation partielle d'une position (pas scoring complet, mais valeurs fortes)
      double evaluatePartial({required List<CardModel> wonBot, required List<CardModel> wonOpp, required bool lastTrickToBot}) {
        int value(CardModel c) {
          switch (c.rank) {
            case Rank.ten: return 10;
            case Rank.nine: return 9;
            case Rank.ace: return 6; // As un peu moins que 9/10 mais important
            case Rank.king: return 3;
            case Rank.queen: return 2;
            case Rank.jack: return 1;
            default: return 0;
          }
        }
        int sum(List<CardModel> cs) => cs.fold(0, (a, c) => a + value(c));
        final botScore = sum(wonBot) + (lastTrickToBot ? 2 : 0); // bonus léger dernier pli
        final oppScore = sum(wonOpp) + (!lastTrickToBot ? 2 : 0);
        return botScore - oppScore + (pressureFor11 ? 3.0 : 0.0);
      }

      // Monte-Carlo rollouts pour chaque coup légal
      final legalMoves = legal.toList();
      double bestScore = -1e9; CardModel? bestMove;
      final knownBotCardIds = hand.map((c) => c.id).toSet();

      for (final m in legalMoves) {
        double total = 0.0;
        // quick bias par heuristique instantanée
        total += evalHeuristicAfterPlay(m) * 1.0;

        for (int sIdx = 0; sIdx < expertSamples; sIdx++) {
          final sampleOpp = sampleOpponentHand(knownBotCardIds);

          // Simule uniquement le pli courant (profondeur 1) et la réponse adverse
          if (trick.isEmpty) {
            // bot mène: adversaire répond
            // Construire une main adverse simulée: utiliser sampleOpp
            final oppReply = opponentResponse(m, sampleOpp);
            // Qui gagne ce pli?
            final trickSim = [m, oppReply];
            final winIdx = _determineTrickWinner(state!.players, trickSim, state!.players.indexWhere((p)=>p.id==botId));
            final botWins = (state!.players[winIdx].id == botId);
            final wonBot = <CardModel>[]; final wonOpp = <CardModel>[];
            if (botWins) { wonBot.addAll(trickSim); } else { wonOpp.addAll(trickSim); }
            total += evaluatePartial(wonBot: wonBot, wonOpp: wonOpp, lastTrickToBot: botWins);
          } else {
            // adversaire a mené: notre carte m répond déjà
            final trickSim = [trick.first, m];
            final winIdx = _determineTrickWinner(state!.players, trickSim, state!.startingPlayerIndex);
            final botWins = (state!.players[winIdx].id == botId);
            final wonBot = <CardModel>[]; final wonOpp = <CardModel>[];
            if (botWins) { wonBot.addAll(trickSim); } else { wonOpp.addAll(trickSim); }
            total += evaluatePartial(wonBot: wonBot, wonOpp: wonOpp, lastTrickToBot: botWins);
          }
        }
        final avg = total / (expertSamples + 1); // +1 pour le bias heuristique
        if (avg > bestScore) { bestScore = avg; bestMove = m; }
      }

      if (bestMove != null) return bestMove;

      // Fallback heuristique extrême si pour une raison l'échantillonnage échoue
      if (followables.isNotEmpty) {
        if (trick.isEmpty) {
          // lead: éviter As si 4 As, exploiter void sinon couleur longue
          for (final su in Suit.values) {
            if ((myCount[su] ?? 0) > 0 && opponentVoidLikely(su)) {
              final inS = bySuit[su]!;
              final low = inS.where((c) => !isAce(c)).toList();
              return low.isNotEmpty ? minSel(low) : minSel(inS);
            }
          }
          Suit? best; var cnt = -1;
          for (final su in Suit.values) { final c = myCount[su] ?? 0; if (c > cnt) { best = su; cnt = c; } }
          final inBest = bySuit[best]!;
          final nonA = aimingFourAces ? inBest.where((c) => !isAce(c)).toList() : inBest;
          return minSel(nonA.isNotEmpty ? nonA : inBest);
        }
        final win = firstWinningOver(trick.first, followables);
        if (win != null) return win;
        if (pressureFor11) {
          final aces = followables.where((c) => c.suit == trick.first.suit && isAce(c) && rankStrength(c) > rankStrength(trick.first));
          if (aces.isNotEmpty) return minSel(aces);
        }
        return minSel(followables);
      } else {
        final notVoid = offSuit.where((c) => !( _voidsByPlayer[oppId]?.contains(c.suit) ?? false)).toList();
        final pool = notVoid.isNotEmpty ? notVoid : offSuit;
        return maxSel(pool); // agressif
      }
    }

    // fallback global
    return minSel(hand);
  }

  Timer? _botTimer;
  bool _botPaused = false;

  void setBotPaused(bool paused) {
    _botPaused = paused;
    if (paused) {
      cancelBotTurnTimer();
    }
  }

  bool get botPaused => _botPaused;

  void maybeScheduleBotTurn() {
    final s = state;
    if (_botPaused) return;
    if (s == null || s.matchOver) { _botTimer?.cancel(); _botTimer = null; return; }
    final current = s.players[s.currentTurnIndex];
    final isBot = current.type == PlayerType.bot;
    if (!isBot) { _botTimer?.cancel(); _botTimer = null; return; }

    _botTimer?.cancel();
    final delay = Duration(milliseconds: 2000 + math.Random().nextInt(1000));
    _botTimer = Timer(delay, () {
      _botTimer = null;
      final ss = state;
      if (_botPaused || ss == null || ss.matchOver) return;
      final cur = ss.players[ss.currentTurnIndex];
      if (cur.type != PlayerType.bot) return;

      final card = _chooseBotCard(cur.id);
      playCard(card);
    });
  }

  void cancelBotTurnTimer() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _markCardSeen(CardModel c) {
    final s = state;
    if (s == null) return;
    final newMap = {for (final e in s.seenCards.entries) e.key: {...e.value}};
    final current = newMap[c.suit] ?? <Rank>{};
    newMap[c.suit] = {...current, c.rank};
    state = s.copyWith(seenCards: newMap);
  }
}
