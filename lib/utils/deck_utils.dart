import 'package:uuid/uuid.dart';
import '../models/card_model.dart';

final _uuid = const Uuid();

List<CardModel> buildDeck32() {
  final suits = [Suit.clubs, Suit.diamonds, Suit.hearts, Suit.spades];
  final ranks = [
    Rank.seven, Rank.eight, Rank.jack, Rank.queen,
    Rank.king, Rank.ace, Rank.nine, Rank.ten,
  ];
  final deck = <CardModel>[];
  for (final s in suits) {
    for (final r in ranks) {
      deck.add(CardModel(suit: s, rank: r, id: _uuid.v4()));
    }
  }
  return deck;
}

void shuffleDeck(List<CardModel> deck) {
  deck.shuffle();
}

/// Retourne deux mains de 8 cartes et la pioche restante (16 cartes restantes).
({List<CardModel> p1, List<CardModel> p2, List<CardModel> drawPile}) dealTwoHands(List<CardModel> deck) {
  final p1 = deck.sublist(0, 8);
  final p2 = deck.sublist(8, 16);
  final drawPile = deck.sublist(16); // 16 restantes
  return (p1: p1, p2: p2, drawPile: drawPile);
}
