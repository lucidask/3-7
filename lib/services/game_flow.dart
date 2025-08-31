import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_mode.dart';
import '../models/bot_difficulty.dart';
import '../providers/game_controller.dart';
import '../services/game_save_service.dart';
import '../screens/game_screen.dart'; // <- ajuste le chemin si besoin

Future<void> launchNewLocalGame({
  required BuildContext context,
  required WidgetRef ref,
  required GameMode mode,
  required BotDifficulty difficulty,
  bool clearSaves = true,      // efface la sauvegarde disque
  bool cancelExisting = true,  // annule la partie en mémoire si existante
  bool replace = false,        // pushReplacement au lieu de push
}) async {
  if (clearSaves) {
    await GameSaveService().clear();
  }

  final ctrl = ref.read(gameControllerProvider.notifier);
  if (cancelExisting) {
    ctrl.cancelCurrentGame();
  }

  ctrl.setBotDifficulty(difficulty);
  ctrl.startLocalGame(mode: mode);

  if (!context.mounted) return;

  final route = MaterialPageRoute(
    builder: (_) => GameScreen(mode: mode, difficulty: difficulty),
  );

  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}
