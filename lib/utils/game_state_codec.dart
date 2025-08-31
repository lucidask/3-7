import '../models/card_model.dart';
import '../models/game_state.dart';
import '../models/game_mode.dart';
import '../models/player_model.dart';
import '../models/bot_difficulty.dart';

// ------ Card helpers ------
Map<String, dynamic> _encCard(CardModel c) => {
  'rank': c.rank.index,
  'suit': c.suit.index,
  'id': c.id,
};

CardModel _decCard(Map<String, dynamic> m) => CardModel(
  suit: Suit.values[m['suit'] as int],
  rank: Rank.values[m['rank'] as int],
  id: (m['id'] as String?) ?? '${m['suit']}_${m['rank']}',
);

// ------ Maps/List helpers ------
List<Map<String, dynamic>> _encCardList(Iterable<CardModel> list) =>
    list.map(_encCard).toList();

List<CardModel> _decCardList(List src) =>
    src.map((e) => _decCard(Map<String, dynamic>.from(e as Map))).toList();

Map<String, List<Map<String, dynamic>>> _encHands(Map<String, List<CardModel>> hands) =>
    { for (final e in hands.entries) e.key : _encCardList(e.value) };

Map<String, List<CardModel>> _decHands(Map src) =>
    { for (final e in src.entries) e.key as String : _decCardList(List.from(e.value)) };

Map<String, List<Map<String, dynamic>>> _encWon(Map<String, List<CardModel>> won) =>
    { for (final e in won.entries) e.key : _encCardList(e.value) };

Map<String, List<CardModel>> _decWon(Map src) =>
    { for (final e in src.entries) e.key as String : _decCardList(List.from(e.value)) };

// seenCards: Map<Suit, Set<Rank>>  ->  { "suitIndex": [rankIndex, ...] }
Map<String, List<int>> _encSeen(Map<Suit, Set<Rank>> m) =>
    { for (final e in m.entries) e.key.index.toString() : e.value.map((r)=>r.index).toList() };

Map<Suit, Set<Rank>> _decSeen(Map src) {
  final out = <Suit, Set<Rank>>{};
  for (final e in src.entries) {
    final suitIdx = int.parse(e.key as String);
    final ranks = (e.value as List).cast<int>().map((i) => Rank.values[i]).toSet();
    out[Suit.values[suitIdx]] = ranks;
  }
  return out;
}

// Players
Map<String, dynamic> _encPlayer(PlayerModel p) => {
  'id': p.id,
  'nickname': p.nickname,
  'type': p.type.index,
};

PlayerModel _decPlayer(Map<String, dynamic> m) => PlayerModel(
  id: m['id'] as String,
  nickname: m['nickname'] as String,
  type: PlayerType.values[(m['type'] as int?) ?? 0],
);

// ------------------------------------------------------------

class GameStateCodec {
  static const int schemaVersion = 1;

  static Map<String, dynamic> toSnapshot(GameState s) {
    return {
      '_meta': {
        'schemaVersion': schemaVersion,
      },
      'players' : s.players.map(_encPlayer).toList(),
      'scores'  : { for (final e in s.scores.entries) e.key : e.value },
      'deck'    : _encCardList(s.deck),
      'hands'   : _encHands(s.hands),
      'currentTrick': _encCardList(s.currentTrick),
      // 👇 NEW: sérialise les owners du pli courant
      'currentTrickOwners': List<String>.from(s.currentTrickOwners),
      'drawPileAvailable': s.drawPileAvailable,
      'currentTurnIndex' : s.currentTurnIndex,
      'mode'    : s.mode.index,
      'startingPlayerIndex': s.startingPlayerIndex,
      'infoMessage': s.infoMessage,
      'lastTrick': _encCardList(s.lastTrick),
      'lastTrickWinnerIndex': s.lastTrickWinnerIndex,
      'wonCards': _encWon(s.wonCards),
      'lastRoundWonCards': _encWon(s.lastRoundWonCards),
      'lastRoundPoints': { for (final e in s.lastRoundPoints.entries) e.key : e.value },
      'lastRoundWinnerId': s.lastRoundWinnerId,
      'consecutiveWins': { for (final e in s.consecutiveWins.entries) e.key : e.value },
      'matchOver': s.matchOver,
      'winnerId' : s.winnerId,
      'findJustHappened': s.findJustHappened,
      'findPlayerId': s.findPlayerId,
      'findSuit': s.findSuit?.index,
      'findIsStrong': s.findIsStrong,
      'botDifficulty': s.botDifficulty.index,
      'seenCards': _encSeen(s.seenCards),
    };
  }

  static GameState fromSnapshot(Map<String, dynamic> s) {
    // Soft reads with fallbacks for forward/backward compatibility
    Map<String, dynamic> m = Map<String, dynamic>.from(s);

    final players = (m['players'] as List?)?.map((e) => _decPlayer(Map<String, dynamic>.from(e))).toList()
        ?? const <PlayerModel>[];
    final scores  = (m['scores'] as Map?) != null
        ? { for (final e in (m['scores'] as Map).entries) e.key as String : (e.value as num).toInt() }
        : { for (final p in players) p.id : 0 };

    final deck    = (m['deck'] as List?) != null ? _decCardList(List.from(m['deck'])) : const <CardModel>[];
    final hands   = (m['hands'] as Map?) != null ? _decHands(Map<String, dynamic>.from(m['hands'])) : <String, List<CardModel>>{};
    final currentTrick = (m['currentTrick'] as List?) != null ? _decCardList(List.from(m['currentTrick'])) : const <CardModel>[];
    // 👇 NEW: désérialise owners (fallback vide si absent dans anciens snapshots)
    final currentTrickOwners = (m['currentTrickOwners'] as List?)?.cast<String>() ?? <String>[];

    final drawPileAvailable = (m['drawPileAvailable'] as bool?) ?? (deck.isNotEmpty);
    final currentTurnIndex  = (m['currentTurnIndex'] as int?) ?? 0;

    final modeIdx = (m['mode'] as int?) ?? GameMode.mixed.index;
    final mode = GameMode.values[modeIdx];

    final startingPlayerIndex = (m['startingPlayerIndex'] as int?) ?? 0;
    final infoMessage = (m['infoMessage'] as String?) ?? '';

    final lastTrick = (m['lastTrick'] as List?) != null ? _decCardList(List.from(m['lastTrick'])) : const <CardModel>[];
    final lastTrickWinnerIndex = (m['lastTrickWinnerIndex'] as int?);

    final wonCards = (m['wonCards'] as Map?) != null ? _decWon(Map<String, dynamic>.from(m['wonCards'])) : <String, List<CardModel>>{};
    final lastRoundWonCards = (m['lastRoundWonCards'] as Map?) != null ? _decWon(Map<String, dynamic>.from(m['lastRoundWonCards'])) : <String, List<CardModel>>{};

    final lastRoundPoints = (m['lastRoundPoints'] as Map?) != null
        ? { for (final e in (m['lastRoundPoints'] as Map).entries) e.key as String : (e.value as num).toInt() }
        : <String, int>{};

    final lastRoundWinnerId = (m['lastRoundWinnerId'] as String?);

    final consecutiveWins = (m['consecutiveWins'] as Map?) != null
        ? { for (final e in (m['consecutiveWins'] as Map).entries) e.key as String : (e.value as num).toInt() }
        : <String, int>{};

    final matchOver = (m['matchOver'] as bool?) ?? false;
    final winnerId  = (m['winnerId'] as String?);

    final findJustHappened = (m['findJustHappened'] as bool?) ?? false;
    final findPlayerId = (m['findPlayerId'] as String?);
    final findSuit = (m['findSuit'] as int?) != null ? Suit.values[m['findSuit'] as int] : null;
    final findIsStrong = (m['findIsStrong'] as bool?);

    final botDifficulty = BotDifficulty.values[(m['botDifficulty'] as int?) ?? BotDifficulty.normal.index];

    final seenCards = (m['seenCards'] as Map?) != null
        ? _decSeen(Map<String, dynamic>.from(m['seenCards']))
        : <Suit, Set<Rank>>{};

    return GameState(
      players: players,
      scores: scores,
      deck: deck,
      hands: hands,
      currentTrick: currentTrick,
      currentTrickOwners: currentTrickOwners, // ← NEW
      drawPileAvailable: drawPileAvailable,
      currentTurnIndex: currentTurnIndex,
      mode: mode,
      startingPlayerIndex: startingPlayerIndex,
      infoMessage: infoMessage,
      lastTrick: lastTrick,
      lastTrickWinnerIndex: lastTrickWinnerIndex,
      wonCards: wonCards,
      lastRoundWonCards: lastRoundWonCards,
      lastRoundPoints: lastRoundPoints,
      lastRoundWinnerId: lastRoundWinnerId,
      consecutiveWins: consecutiveWins,
      matchOver: matchOver,
      winnerId: winnerId,
      findJustHappened: findJustHappened,
      findPlayerId: findPlayerId,
      findSuit: findSuit,
      findIsStrong: findIsStrong,
      botDifficulty: botDifficulty,
      seenCards: seenCards,
    );
  }
}
