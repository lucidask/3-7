import '../models/card_model.dart';

String suitSymbol(Suit s) {
  switch (s) {
    case Suit.clubs: return '♣';
    case Suit.diamonds: return '♦';
    case Suit.hearts: return '♥';
    case Suit.spades: return '♠';
  }
}

String rankLabel(Rank r) {
  switch (r) {
    case Rank.seven: return '7';
    case Rank.eight: return '8';
    case Rank.jack: return 'J';
    case Rank.queen: return 'Q';
    case Rank.king: return 'K';
    case Rank.ace: return 'A';
    case Rank.nine: return '9';
    case Rank.ten: return '10';
  }
}

String cardLabel(CardModel c) => '${rankLabel(c.rank)}${suitSymbol(c.suit)}';
