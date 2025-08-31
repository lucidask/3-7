import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_difficulty.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../providers/game_controller.dart';
import '../providers/settings_provider.dart';
import '../services/game_flow.dart';
import '../models/game_mode.dart';
import '../utils/suit_emoji.dart';
import '../widgets/app_button.dart';
import '../services/game_save_service.dart';
import '../utils/game_state_codec.dart';
import '../widgets/found_chip.dart';
import '../widgets/game_app_bar.dart';
import '../widgets/game_table.dart';
import '../widgets/global_options_button.dart';
import '../widgets/hand_view.dart';
import '../widgets/hand_with_pile_row.dart';
import '../widgets/name_chip.dart';
import '../widgets/round_mode_chip.dart';
import '../widgets/scores_panel.dart';
import '../widgets/pile.dart';
import '../anim/game_animations.dart';
import '../widgets/mini_card_widget.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameMode mode;
  final BotDifficulty difficulty;
  const GameScreen({super.key, required this.mode, required this.difficulty});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final deckKey = GlobalKey();
  final tableCenterKey = GlobalKey();
  final tableLeftKey = GlobalKey();
  final tableRightKey = GlobalKey();
  final p1HandKey = GlobalKey();
  final p2HandKey = GlobalKey();
  final p1PileKey = GlobalKey();
  final p2PileKey = GlobalKey();

  bool _isDealing = false;
  int _dealP1Shown = 0, _dealP2Shown = 0;
  int? _dealDeckShown;
  int? _lastDeck, _lastP1, _lastP2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = ref.read(gameControllerProvider.notifier);

      if (ref.read(gameControllerProvider) == null) {
        // ⬇️ ATTENDS VRAIMENT le démarrage
        await ctrl.startLocalGame(mode: widget.mode);
        ctrl.setBotDifficulty(widget.difficulty);
      }

      // Frein ON pendant la distrib
      ctrl.setBotPaused(true);
      await _runInitialDeal();             // distrib progressive
      // Frein OFF juste après
      ctrl.setBotPaused(false);

      // Si c'est au bot de jouer maintenant, planifie-le
      final gNow = ref.read(gameControllerProvider);
      if (gNow != null &&
          gNow.players[gNow.currentTurnIndex].type == PlayerType.bot) {
        ctrl.maybeScheduleBotTurn();
      }

      // init des compteurs de pioche
      if (gNow != null) {
        _lastDeck = gNow.deck.length;
        _lastP1 = ctrl.handOf('p1').length;
        _lastP2 = ctrl.handOf('p2').length;
      }
    });
  }

  Future<void> _runInitialDeal() async {
    final ctrl = ref.read(gameControllerProvider.notifier);
    final g = ref.read(gameControllerProvider);
    if (g == null) return;

    final p1 = ctrl.handOf('p1');
    final cardsPerHand = p1.length;
    if (cardsPerHand == 0) return;

    setState(() {
      _isDealing = true;
      _dealP1Shown = 0;
      _dealP2Shown = 0;
      _dealDeckShown = g.deck.length;
    });

    final total = cardsPerHand * 2;
    for (var i = 0; i < total; i++) {
      final toP1 = (i % 2 == 0);
      final toKey = toP1 ? p1HandKey : p2HandKey;

      final backCard = _pickAnyForBack();
      await GameAnimations.drawFromDeck(
        context: context,
        vsync: this,
        deckKey: deckKey,
        handKey: toKey,
        cardBuilder: () => MiniCardWidget(backCard, faceDown: true, dimmed: false),
      );

      if (!mounted) return;
      setState(() {
        if (toP1) {
          _dealP1Shown++;
        } else {
          _dealP2Shown++;
        }
        if (_dealDeckShown != null && _dealDeckShown! > 0) {
          _dealDeckShown = _dealDeckShown! - 1;
        }
      });
    }

    if (!mounted) return;
    setState(() {
      _isDealing = false;
      _dealDeckShown = null;
    });
  }

  CardModel _pickAnyForBack() {
    final g = ref.read(gameControllerProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);
    if (g != null) {
      if (g.deck.isNotEmpty) return g.deck.first;
      final p1 = ctrl.handOf('p1');
      if (p1.isNotEmpty) return p1.first;
      final p2 = ctrl.handOf('p2');
      if (p2.isNotEmpty) return p2.first;
      if (g.currentTrick.isNotEmpty) return g.currentTrick.last;
      for (final e in g.wonCards.values) {
        if (e.isNotEmpty) return e.first;
      }
    }
    return ctrl.handOf('p1').isNotEmpty ? ctrl.handOf('p1').first : ctrl.handOf('p2').first;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final g = ref.read(gameControllerProvider);
      if (g != null) {
        final snapshot = GameStateCodec.toSnapshot(g);
        GameSaveService().save(snapshot, force: true);
      }
      ref.read(gameControllerProvider.notifier).cancelBotTurnTimer();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(gameControllerProvider.notifier).maybeScheduleBotTurn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final screenH = MediaQuery.of(context).size.height;
    final tableHeight = (screenH * 0.60).clamp(300, 700).toDouble();
    const baseH = 56.0;
    final targetCardH = (tableHeight / 5).clamp(50.0, 65.0);
    final slotScale = targetCardH / baseH;
    final sectionGap = (tableHeight * 0.04).clamp(8.0, 20.0);

    bool isTurnIndex(int idx) {
      final g = game;
      if (g == null) return false;
      return g.currentTurnIndex == idx;
    }

    ref.listen(gameControllerProvider, (prev, next) async {
      if (prev == null || next == null) return;

      if (next.currentTrick.length > prev.currentTrick.length) {
        final ownerId = next.currentTrickOwners.last;
        final card = next.currentTrick.last;
        final fromKey = ownerId == 'p1' ? p1HandKey : p2HandKey;
        final toKey = ownerId == next.players[1].id ? tableLeftKey : tableRightKey;
        await GameAnimations.playToTable(
          context: context,
          vsync: this,
          fromHandKey: fromKey,
          tableCenterKey: toKey,
          cardBuilder: () => MiniCardWidget(card, faceDown: false, dimmed: false),
        );
      }

      if (prev.currentTrick.length == 2 && next.currentTrick.isEmpty && next.lastTrickWinnerIndex != null) {
        final winnerId = next.players[next.lastTrickWinnerIndex!].id;
        final winnerKey = winnerId == 'p1' ? p1PileKey : p2PileKey;
        await GameAnimations.collectTrick(
          context: context,
          vsync: this,
          tableCardKeys: [tableLeftKey, tableRightKey],
          winnerPileKey: winnerKey,
          cardBuilder: () => MiniCardWidget(_pickAnyForBack(), faceDown: true, dimmed: false),
        );
      }

      final curDeck = next.deck.length;
      final curP1 = ctrl.handOf('p1').length;
      final curP2 = ctrl.handOf('p2').length;
      if (_lastDeck != null && curDeck < _lastDeck!) {
        final p1Drew = _lastP1 != null && curP1 > _lastP1!;
        final p2Drew = _lastP2 != null && curP2 > _lastP2!;
        if (p1Drew) {
          await GameAnimations.drawFromDeck(
            context: context,
            vsync: this,
            deckKey: deckKey,
            handKey: p1HandKey,
            cardBuilder: () => MiniCardWidget(_pickAnyForBack(), faceDown: true, dimmed: false),
          );
        }
        if (p2Drew) {
          await GameAnimations.drawFromDeck(
            context: context,
            vsync: this,
            deckKey: deckKey,
            handKey: p2HandKey,
            cardBuilder: () => MiniCardWidget(_pickAnyForBack(), faceDown: true, dimmed: false),
          );
        }
      }
      _lastDeck = curDeck;
      _lastP1 = curP1;
      _lastP2 = curP2;

      final c = ref.read(gameControllerProvider.notifier);
      if (!c.botPaused) {
        c.maybeScheduleBotTurn();
      }
    });

    if (game == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final roundFinished = game.lastRoundWonCards.isNotEmpty;
    final matchOver = game.matchOver;
    final showOnlyScores = roundFinished || matchOver;
    final showFindOverlay =
        game.findJustHappened && game.findPlayerId != null && game.currentTrick.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final g = ref.read(gameControllerProvider);
        if (g != null) {
          final snapshot = GameStateCodec.toSnapshot(g);
          await GameSaveService().save(snapshot, force: true);
        }
        if (!context.mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(result);
        } else {
          Navigator.of(context).pushReplacementNamed('/');
        }
      },
      child: Scaffold(
        appBar: GameAppBar(
          showBack: true,
          onBack: () {
            final g = ref.read(gameControllerProvider);
            if (g != null) {
              final snap = GameStateCodec.toSnapshot(g);
              GameSaveService().save(snap, force: true);
            }
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
          onOptionSelected: (opt) async {
            switch (opt) {
              case GlobalOption.save:
                final g = ref.read(gameControllerProvider);
                if (g != null) {
                  final snap = GameStateCodec.toSnapshot(g);
                  await GameSaveService().save(snap, force: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Partie sauvegardée')),
                  );
                }
                break;

              case GlobalOption.restartRound:
                ctrl.restartCurrentRound();
                ctrl.setBotPaused(true);
                await _runInitialDeal();
                ctrl.setBotPaused(false);
                ctrl.maybeScheduleBotTurn();
                break;

              case GlobalOption.restartMatch:
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Recommencer le match ?'),
                    content: const Text('La partie en cours sera effacée et un nouveau match va démarrer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Recommencer')),
                    ],
                  ),
                ) ??
                    false;
                if (!confirm) break;

                await launchNewLocalGame(
                  context: context,
                  ref: ref,
                  mode: widget.mode,
                  difficulty: widget.difficulty,
                  clearSaves: true,
                  cancelExisting: true,
                  replace: true,
                );
                break;

              case GlobalOption.quit:
                final g = ref.read(gameControllerProvider);
                if (g != null) {
                  final snap = GameStateCodec.toSnapshot(g);
                  GameSaveService().save(snap, force: true);
                }
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/');
                }
                break;
            }
          },
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RoundModeChip(
                  roundNumber: game.roundNo,
                  mode: game.mode,
                  sequenceTargetWins: settings.sequencesTarget,
                  scoreTargetPoints: settings.scoreTarget,
                  onTap: () {},
                ),
                const SizedBox(height: 2),

                if (showOnlyScores) ...[
                  ScoresPanel(
                    players: game.players,
                    scores: game.scores,
                    consecutiveWins: game.consecutiveWins,
                    lastRoundWonCards: game.lastRoundWonCards,
                    lastRoundPoints: game.lastRoundPoints,
                    lastRoundWinnerId: game.lastTrickWinnerIndex != null
                        ? game.players[game.lastTrickWinnerIndex!].id
                        : null,
                    matchOver: game.matchOver,
                    winnerId: game.winnerId,
                  ),
                  const SizedBox(height: 12),
                  if (game.lastRoundWonCards.isNotEmpty && !matchOver)
                    AppButton(
                      label: 'Next Round',
                      variant: ButtonVariant.tonal,
                      onPressed: () async {
                        ctrl.startNextRound();
                        ctrl.setBotPaused(true);
                        await _runInitialDeal();
                        ctrl.setBotPaused(false);
                        ctrl.maybeScheduleBotTurn();
                      },
                    )
                  else if (matchOver)
                    AppButton(
                      label: 'New Game',
                      variant: ButtonVariant.primary,
                      onPressed: () async {
                        await launchNewLocalGame(
                          context: context,
                          ref: ref,
                          mode: widget.mode,
                          difficulty: widget.difficulty,
                          clearSaves: true,
                          cancelExisting: true,
                          replace: true,
                        );
                      },
                    ),
                ] else ...[
                  Center(
                    child: NameChip(
                      text: game.players[1].nickname,
                      icon: Icons.smart_toy_outlined,
                      tone: isTurnIndex(1) ? NameChipTone.positive : NameChipTone.negative,
                      pulse: isTurnIndex(1),
                      active: isTurnIndex(1),
                    ),
                  ),
                  const SizedBox(height: 2),

                  SizedBox(
                    height: tableHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        GameTable(
                          trick: showFindOverlay ? const [] : game.currentTrick,
                          trickOwners: showFindOverlay ? const [] : game.currentTrickOwners,
                          leftPlayerId: game.players[1].id,
                          rightPlayerId: game.players[0].id,
                          leftLabel: game.players[1].nickname,
                          rightLabel: game.players[0].nickname,
                          deckCount: _dealDeckShown ?? game.deck.length,
                          turnText: 'Turn : ${game.players[game.currentTurnIndex].nickname}',
                          wonByText: (game.lastTrickWinnerIndex != null)
                              ? 'Last Win : ${game.players[game.lastTrickWinnerIndex!].nickname}'
                              : null,
                          deckAnchorKey: deckKey,
                          tableCenterAnchorKey: tableCenterKey,
                          tableLeftAnchorKey: tableLeftKey,
                          tableRightAnchorKey: tableRightKey,
                          topRow: HandWithPileRow(
                            pileOnLeft: true,
                            handView: KeyedSubtree(
                              key: p2HandKey,
                              child: HandView(
                                cards: _isDealing
                                    ? ref.read(gameControllerProvider.notifier).handOf('p2').take(_dealP2Shown).toList()
                                    : ref.read(gameControllerProvider.notifier).handOf('p2'),
                                enabled: !_isDealing,
                                faceDown: true,
                                cardScale: slotScale,
                                onTap: (_) {},
                              ),
                            ),
                            pile: Pile(
                              key: p2PileKey,
                              visual: PileVisual.diagonal,
                              cards: (showOnlyScores ? game.lastRoundWonCards : game.wonCards)[game.players[1].id] ?? const [],
                              showTop: 32,
                              scale: 40 / 46,
                              overlapX: 0,
                              overlapY: 1,
                              showBadge: true,
                            ),
                          ),
                          bottomRow: HandWithPileRow(
                            pileOnLeft: false,
                            handView: HandView(
                              key: p1HandKey,
                              cards: _isDealing
                                  ? ref.read(gameControllerProvider.notifier).handOf('p1').take(_dealP1Shown).toList()
                                  : ref.read(gameControllerProvider.notifier).handOf('p1'),
                              enabled: !_isDealing && (game.players[game.currentTurnIndex].id == 'p1'),
                              faceDown: false,
                              cardScale: slotScale,
                              isPlayable: (card) => ref.read(gameControllerProvider.notifier).validateMove(card),
                              onTap: (card) {
                                final c = ref.read(gameControllerProvider.notifier);
                                if (!c.validateMove(card)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Coup illégal: obligation de couleur/carte forte')),
                                  );
                                  return;
                                }
                                c.playCard(card); // anim via ref.listen
                              },
                            ),
                            pile: Pile(
                              key: p1PileKey,
                              visual: PileVisual.diagonal,
                              cards: (showOnlyScores ? game.lastRoundWonCards : game.wonCards)[game.players[0].id] ?? const [],
                              showTop: 32,
                              scale: 40 / 46,
                              overlapX: 0,
                              overlapY: 1,
                              showBadge: true,
                            ),
                          ),
                            slotScale: slotScale,
                            sectionGap: sectionGap,
                            minHeight: tableHeight,
                        ),
                        if (showFindOverlay)
                          FoundChip(
                            suit: suitEmoji(game.findSuit),
                            owner: game.findPlayerId == 'p1'
                                ? game.players[0].nickname
                                : game.players[1].nickname,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 2),

                  Center(
                    child: NameChip(
                      text: game.players[0].nickname,
                      icon: Icons.person,
                      tone: isTurnIndex(0) ? NameChipTone.positive : NameChipTone.negative,
                      pulse: isTurnIndex(0),
                      active: isTurnIndex(0),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
