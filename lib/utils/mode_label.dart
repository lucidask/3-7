import '../models/game_mode.dart';

class ModeLabel {

  static String build(
      GameMode mode, {
        required int sequenceTargetWins,
        required int scoreTargetPoints,
      }) {
    switch (mode) {
      case GameMode.sequence:
        return 'Séquence ($sequenceTargetWins victoires)';
      case GameMode.score:
        return 'Score ($scoreTargetPoints pts)';
      case GameMode.mixed:
        return 'Mixte ($sequenceTargetWins victoires / $scoreTargetPoints pts)';
    }
  }
}
