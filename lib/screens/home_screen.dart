import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_controller.dart';
import '../models/game_mode.dart';
import '../models/bot_difficulty.dart'; // << ajouter
import '../providers/settings_provider.dart';
import '../services/game_flow.dart';
import '../services/game_save_service.dart';
import '../utils/game_state_codec.dart';
import '../widgets/app_button.dart';
import 'settings_screen.dart';
import 'game_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GameMode _mode = GameMode.mixed;
  BotDifficulty _difficulty = BotDifficulty.normal;

  Future<void> _startNewGame() {
    return launchNewLocalGame(
      context: context,
      ref: ref,
      mode: _mode,
      difficulty: _difficulty,
      clearSaves: true,
      cancelExisting: true,
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);// << pour set avant navigation

    return Scaffold(
      appBar: AppBar(title: const Text('3-7')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to 3-7',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Choisissez un mode et la difficulté, puis lancez “New Game”.'),
              const SizedBox(height: 16),

              // --- Mode + Difficulté ---
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  // Mode
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Mode :', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<GameMode>(
                        value: _mode,
                        items: [
                          DropdownMenuItem(
                            value: GameMode.sequence,
                            child: Text('Séquence (${settings.sequencesTarget} victoires)'),
                          ),
                          DropdownMenuItem(
                            value: GameMode.score,
                            child: Text('Score (${settings.scoreTarget} points)'),
                          ),
                          DropdownMenuItem(
                            value: GameMode.mixed,
                            child: Text('Mixte (${settings.sequencesTarget} victoires / ${settings.scoreTarget} pts)'),
                          ),
                        ],
                        onChanged: (m) => setState(() => _mode = m ?? GameMode.mixed),
                      ),
                    ],
                  ),

                  // Difficulté
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Difficulté :', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<BotDifficulty>(
                        value: _difficulty,
                        items: const [
                          DropdownMenuItem(value: BotDifficulty.normal, child: Text('Normale')),
                          DropdownMenuItem(value: BotDifficulty.hard, child: Text('Difficile')),
                          DropdownMenuItem(value: BotDifficulty.extreme, child: Text('Extrême')),
                        ],
                        onChanged: (d) => setState(() => _difficulty = d ?? BotDifficulty.normal),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Lancer la partie ---
              // Bouton "Play Local"
              AppButton(
                label: 'New Game',
                variant: ButtonVariant.primary, // FilledButton = style primaire
                onPressed: () {_startNewGame();
                },
              ),
              const SizedBox(height: 8),

              AppButton(
                label: 'Resume/Continue',
                variant: ButtonVariant.primary, // FilledButton = style primaire
                onPressed: () async {
                  try {
                    final snap = await GameSaveService().load();
                    if (snap == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No valid saved game')),
                      );
                      return;
                    }

                    final restored = GameStateCodec.fromSnapshot(snap);
                    ref.read(gameControllerProvider.notifier).restore(restored);

                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          mode: restored.mode,
                          difficulty: restored.botDifficulty,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to resume: $e')),
                    );
                  }
                },

              ),
              const SizedBox(height: 8),

              const AppButton(
                label: 'Play Online – Coming soon',
                variant: ButtonVariant.primary,
                onPressed: null, // Désactivé
                fullWidth: true, // Optionnel si tu veux qu'il prenne toute la largeur
              ),
              const SizedBox(height: 8),

              AppButton(
                label: 'Settings',
                variant: ButtonVariant.secondary, // OutlinedButton = style secondaire
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}
