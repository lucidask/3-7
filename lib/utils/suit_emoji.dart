import '../models/card_model.dart';

/// Retourne l’emoji correspondant à une couleur de carte.
String suitEmoji(Suit? suit) {
  switch (suit) {
    case Suit.hearts:
      return '♥️';
    case Suit.diamonds:
      return '♦️';
    case Suit.clubs:
      return '♣️';
    case Suit.spades:
      return '♠️';
    default:
      return '';
  }
}
