import '../models/card_model.dart';

int calculatePoints(List<CardModel> wonCards, {bool lastTrickWinner = false}) {
  int points = 0;

  // 1) As = 1 point chacun
  final aces = wonCards.where((c) => c.rank == Rank.ace).length;
  points += aces;

  // 2) Trios formés uniquement avec {9, 10, J, Q, K}
  isTrioEligible(Rank r) =>
  r == Rank.nine ||
      r == Rank.ten ||
      r == Rank.jack ||
      r == Rank.queen ||
      r == Rank.king;

  final eligibleCount = wonCards.where((c) => isTrioEligible(c.rank)).length;
  points += eligibleCount ~/ 3; // 1 point par groupe de 3

  // 3) Bonus dernier pli
  if (lastTrickWinner) points += 1;

  return points;
}
