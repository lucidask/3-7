import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../models/card_model.dart';
import 'mini_card_widget.dart';

class ScoresPanel extends StatelessWidget {
  final List<PlayerModel> players;
  final Map<String, int> scores;
  final Map<String, int> consecutiveWins;

  final Map<String, List<CardModel>> lastRoundWonCards;
  final Map<String, int> lastRoundPoints;
  final String? lastRoundWinnerId;

  final bool matchOver;
  final String? winnerId;

  const ScoresPanel({
    super.key,
    required this.players,
    required this.scores,
    required this.consecutiveWins,
    required this.lastRoundWonCards,
    required this.lastRoundPoints,
    required this.lastRoundWinnerId,
    required this.matchOver,
    required this.winnerId,
  });

  bool get _hasRoundSummary => lastRoundWonCards.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endNote = _endNoteIfAny();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withOpacity(0.96),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.96)
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.35),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Icon(
                    matchOver ? Icons.emoji_events : Icons.leaderboard,
                    color: matchOver
                        ? Colors.amber.shade700
                        : theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  matchOver ? 'Résumé du match' : 'Résumé de la manche',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (matchOver)
                  _Badge(
                    text: 'Match terminé',
                    bg: Colors.red.withOpacity(0.10),
                    fg: Colors.red.shade700,
                  )
                else if (_hasRoundSummary)
                  _Badge(
                    text: 'Manche terminée',
                    bg: theme.colorScheme.secondary.withOpacity(0.10),
                    fg: theme.colorScheme.secondary,
                  ),
              ],
            ),
            const SizedBox(height: 12),

               if (matchOver) ...[
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.red, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Match terminé — Gagnant : ${_nicknameById(winnerId) ?? '-'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_hasRoundSummary) ...[
              if (matchOver) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.35)),
                    ),
                    child: Text(
                      'Dernière manche',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Gagnant de la manche
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: theme.colorScheme.onSurface, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _roundWinnerText(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // You: X • Bot: Y (scoreboard moderne)
              if (players.length >= 2) _buildRoundPointsLine(context),

              // Règle 4 As / Règle 11 si applicable
              if (endNote != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    endNote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.deepOrange.shade400,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 12),
            ],

            // Cartes gagnées (grilles de mini cartes)
            if (_hasRoundSummary) ...[
              const SizedBox(height: 14),
              Divider(
                height: 20,
                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Cartes gagnées',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final p in players) ...[
                _PlayerWonCardsRow(
                  playerName: p.nickname,
                  cards: lastRoundWonCards[p.id] ?? const [],
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Scores & Séries (pills modernes)
            const SizedBox(height: 8),
            Divider(
              height: 20,
              color: theme.colorScheme.outlineVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Scores et Séries',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final p in players) ...[
              _ScoreRow(
                name: p.nickname,
                points: scores[p.id] ?? 0,
                streak: consecutiveWins[p.id] ?? 0,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Helpers logiques ----------
  String? _nicknameById(String? id) {
    if (id == null) return null;
    try {
      return players.firstWhere((e) => e.id == id).nickname;
    } catch (_) {
      return null;
    }
  }

  String _roundWinnerText() {
    if (lastRoundWinnerId == null) return 'Égalité sur cette manche';
    final nick = _nicknameById(lastRoundWinnerId) ?? '-';
    return 'Gagnant de la manche: $nick';
  }

  Widget _buildRoundPointsLine(BuildContext context) {
    final theme = Theme.of(context);
    final p1 = players[0];
    final p2 = players[1];
    final p1Pts = lastRoundPoints[p1.id] ?? 0;
    final p2Pts = lastRoundPoints[p2.id] ?? 0;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Joueur 1
          Column(
            children: [
              Text(
                p1.nickname,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              Text(
                '$p1Pts',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Text(
            '•',
            style: TextStyle(
              fontSize: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 16),
          // Joueur 2
          Column(
            children: [
              Text(
                p2.nickname,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              Text(
                '$p2Pts',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _endNoteIfAny() {
    if (lastRoundWonCards.isEmpty) return null;

    bool fourAces(String pid) =>
        (lastRoundWonCards[pid] ?? const [])
            .where((c) => c.rank == Rank.ace)
            .length == 4;

    if (players.length >= 2) {
      final p1 = players[0].id;
      final p2 = players[1].id;
      if (fourAces(p1) || fourAces(p2)) {
        return 'Fin de match Règle 4 As';
      }
    }

    if (players.length >= 2) {
      final p1 = players[0];
      final p2 = players[1];
      final p1Pts = lastRoundPoints[p1.id] ?? 0;
      final p2Pts = lastRoundPoints[p2.id] ?? 0;
      if (p1Pts == 0 || p2Pts == 0) {
        return 'Fin de match Règle 11';
      }
    }
    return null;
  }
}

/// Badges pill
class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Badge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

/// Ligne Joueur + grille de mini cartes gagnées
class _PlayerWonCardsRow extends StatelessWidget {
  final String playerName;
  final List<CardModel> cards;
  const _PlayerWonCardsRow({
    required this.playerName,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = cards.map((c) => MiniCardWidget(c)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$playerName  •  ${cards.length} carte${cards.length > 1 ? 's' : ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (grid.isEmpty)
          Text(
            'Aucune carte',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: grid,
          ),
      ],
    );
  }
}

/// Ligne score + série en pills modernes
class _ScoreRow extends StatelessWidget {
  final String name;
  final int points;
  final int streak;
  const _ScoreRow({
    required this.name,
    required this.points,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _pill('Points: $points',
            bg: Colors.blue.shade50, fg: Colors.blue.shade800),
        const SizedBox(width: 8),
        _pill('Série: $streak',
            bg: Colors.orange.shade50, fg: Colors.orange.shade800),
      ],
    );
  }

  Widget _pill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
