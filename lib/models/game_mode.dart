enum GameMode {
  sequence, // 4 consecutive wins
  score,    // 21 points or more
  mixed,    // either condition
}

String gameModeLabel(GameMode m) {
  switch (m) {
    case GameMode.sequence:
      return 'Sequence';
    case GameMode.score:
      return 'Score';
    case GameMode.mixed:
      return 'Mixed';
  }
}
