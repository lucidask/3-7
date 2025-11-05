import 'bot_difficulty.dart';
import 'card_model.dart';
import 'player_model.dart';
import 'game_mode.dart';

class GameState {
  final List<PlayerModel> players;
  final Map<String, int> scores;
  final List<CardModel> deck;
  final Map<String, List<CardModel>> hands;
  final List<CardModel> currentTrick;
  final List<String> currentTrickOwners;
  final bool drawPileAvailable;
  final int currentTurnIndex;
  final GameMode mode;
  final int startingPlayerIndex;
  final String infoMessage;
  final int roundNo;
  final List<CardModel> lastTrick;
  final int? lastTrickWinnerIndex;
  final Map<String, List<CardModel>> wonCards;
  final Map<String, List<CardModel>> lastRoundWonCards;
  final Map<String, int> lastRoundPoints;
  final String? lastRoundWinnerId;
  final Map<String, int> consecutiveWins;
  final bool matchOver;
  final String? winnerId;
  final bool findJustHappened;
  final String? findPlayerId;
  final Suit? findSuit;
  final bool? findIsStrong;
  final BotDifficulty botDifficulty;
  final Map<Suit, Set<Rank>> seenCards;

  const GameState({
    required this.players,
    required this.scores,
    required this.deck,
    required this.hands,
    required this.currentTrick,
    required this.currentTrickOwners,
    required this.drawPileAvailable,
    required this.currentTurnIndex,
    required this.mode,
    required this.startingPlayerIndex,
    required this.infoMessage,
    this.roundNo = 1,
    this.lastTrick = const [],
    this.lastTrickWinnerIndex,
    required this.wonCards,
    this.lastRoundWonCards = const {},
    this.lastRoundPoints = const {},
    this.lastRoundWinnerId,
    this.consecutiveWins = const {},
    this.matchOver = false,
    this.winnerId,
    this.findJustHappened = false,
    this.findPlayerId,
    this.findSuit,
    this.findIsStrong,
    this.botDifficulty = BotDifficulty.normal,
    this.seenCards = const {},
  });

  GameState copyWith({
    List<PlayerModel>? players,
    Map<String, int>? scores,
    List<CardModel>? deck,
    Map<String, List<CardModel>>? hands,
    List<CardModel>? currentTrick,
    List<String>? currentTrickOwners,
    bool? drawPileAvailable,
    int? currentTurnIndex,
    GameMode? mode,
    int? startingPlayerIndex,
    String? infoMessage,
    int? roundNo,
    List<CardModel>? lastTrick,
    int? lastTrickWinnerIndex,
    Map<String, List<CardModel>>? wonCards,
    Map<String, List<CardModel>>? lastRoundWonCards,
    Map<String, int>? lastRoundPoints,
    String? lastRoundWinnerId,
    Map<String, int>? consecutiveWins,
    bool? matchOver,
    String? winnerId,
    bool? findJustHappened,
    String? findPlayerId,
    Suit? findSuit,
    bool? findIsStrong,
    BotDifficulty? botDifficulty,
    Map<Suit, Set<Rank>>? seenCards,
  }) {
    return GameState(
      players: players ?? this.players,
      scores: scores ?? this.scores,
      deck: deck ?? this.deck,
      hands: hands ?? this.hands,
      currentTrick: currentTrick ?? this.currentTrick,
      currentTrickOwners : currentTrickOwners ?? this.currentTrickOwners,
      drawPileAvailable: drawPileAvailable ?? this.drawPileAvailable,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      mode: mode ?? this.mode,
      startingPlayerIndex: startingPlayerIndex ?? this.startingPlayerIndex,
      infoMessage: infoMessage ?? this.infoMessage,
      roundNo: roundNo ?? this.roundNo,
      lastTrick: lastTrick ?? this.lastTrick,
      lastTrickWinnerIndex: lastTrickWinnerIndex ?? this.lastTrickWinnerIndex,
      wonCards: wonCards ?? this.wonCards,
      lastRoundWonCards: lastRoundWonCards ?? this.lastRoundWonCards,
      lastRoundPoints: lastRoundPoints ?? this.lastRoundPoints,
      lastRoundWinnerId: lastRoundWinnerId ?? this.lastRoundWinnerId,
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
      matchOver: matchOver ?? this.matchOver,
      winnerId: winnerId ?? this.winnerId,
      findJustHappened: findJustHappened ?? this.findJustHappened,
      findPlayerId: findPlayerId ?? this.findPlayerId,
      findSuit: findSuit ?? this.findSuit,
      findIsStrong: findIsStrong ?? this.findIsStrong,
      botDifficulty: botDifficulty ?? this.botDifficulty,
      seenCards: seenCards ?? this.seenCards,
    );
  }
}
