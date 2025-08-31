import 'package:hive/hive.dart';

part 'card_model.manual.dart'; // Adapters manuels

@HiveType(typeId: 1)
enum Suit {
  @HiveField(0) clubs,
  @HiveField(1) diamonds,
  @HiveField(2) hearts,
  @HiveField(3) spades,
}

@HiveType(typeId: 2)
enum Rank {
  @HiveField(0) seven,
  @HiveField(1) eight,
  @HiveField(2) jack,
  @HiveField(3) queen,
  @HiveField(4) king,
  @HiveField(5) ace,
  @HiveField(6) nine,
  @HiveField(7) ten,
}

/// Hiérarchie 3-7 : 7 < 8 < J < Q < K < As < 9 < 10
int rankStrength(Rank r) {
  switch (r) {
    case Rank.seven: return 0;
    case Rank.eight: return 1;
    case Rank.jack: return 2;
    case Rank.queen: return 3;
    case Rank.king: return 4;
    case Rank.ace: return 5;
    case Rank.nine: return 6;
    case Rank.ten: return 7;
  }
}

@HiveType(typeId: 3)
class CardModel {
  @HiveField(0)
  final Suit suit;
  @HiveField(1)
  final Rank rank;
  @HiveField(2)
  final String id;

  const CardModel({required this.suit, required this.rank, required this.id});

  @override
  String toString() => 'Card($suit, $rank)';
}
