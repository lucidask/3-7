import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'mini_card_widget.dart';
import 'pile.dart';

class GameTable extends StatelessWidget {
  final List<CardModel> trick;
  final List<String> trickOwners;

  final String leftPlayerId;
  final String rightPlayerId;

  final String leftLabel;
  final String rightLabel;

  final String? turnText;
  final String? wonByText;

  final int deckCount;
  final VoidCallback? onDeckTap;

  final EdgeInsets padding;
  final double cornerRadius;
  final double minHeight;

  final double slotScale;
  final double overlapPx;

  final int deckShowTop;
  final double deckScale;
  final double deckDx;
  final double deckDy;
  final bool deckShowBadge;

  final GlobalKey? deckAnchorKey;
  final GlobalKey? tableCenterAnchorKey;
  final GlobalKey? tableLeftAnchorKey;
  final GlobalKey? tableRightAnchorKey;

  final Widget? topRow;
  final Widget? bottomRow;
  final double sectionGap;

  const GameTable({
    super.key,
    required this.trick,
    required this.trickOwners,
    required this.leftPlayerId,
    required this.rightPlayerId,
    required this.leftLabel,
    required this.rightLabel,
    required this.deckCount,
    this.turnText,
    this.wonByText,
    this.onDeckTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.cornerRadius = 18,
    this.minHeight = 300,
    this.slotScale = 64 / 46,
    this.overlapPx = 12,
    this.deckShowTop = 6,
    this.deckScale = 50 / 46,
    this.deckDx = 1,
    this.deckDy = 0,
    this.deckShowBadge = true,
    this.deckAnchorKey,
    this.tableCenterAnchorKey,
    this.tableLeftAnchorKey,
    this.tableRightAnchorKey,
    this.topRow,
    this.bottomRow,
    this.sectionGap = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    CardModel? leftCard;
    CardModel? rightCard;
    for (int i = 0; i < trick.length && i < trickOwners.length; i++) {
      final owner = trickOwners[i];
      if (owner == leftPlayerId) {
        leftCard = trick[i];
      } else if (owner == rightPlayerId) {
        rightCard = trick[i];
      }
    }

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: cs.outlineVariant.withOpacity(.50)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.maxHeight.isFinite;

          final centerRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 100),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (turnText != null && turnText!.isNotEmpty) _InfoPill(text: turnText!),
                    if (wonByText != null && wonByText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoPill(text: wonByText!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Center(
                  key: tableCenterAnchorKey,
                  child: _TrickCards(
                      leftCard: leftCard,
                      rightCard: rightCard,
                      scale: slotScale,
                      overlapPx: overlapPx,
                      leftAnchorKey: tableLeftAnchorKey,
                      rightAnchorKey: tableRightAnchorKey,
                    ),
                ),
              ),
              const SizedBox(width: 16),
              Pile(
                key: deckAnchorKey,
                visual: PileVisual.diagonal,
                count: deckCount,
                showTop: deckShowTop,
                scale: deckScale,
                overlapX: deckDx,
                overlapY: deckDy,
                showBadge: deckShowBadge,
                onTap: onDeckTap,
              ),
            ],
          );

          if (bounded) {
            return Column(
              children: [
                if (topRow != null) topRow!,
                if (topRow != null) SizedBox(height: sectionGap),
                Expanded(child: centerRow),
                if (bottomRow != null) SizedBox(height: sectionGap),
                if (bottomRow != null) bottomRow!,
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (topRow != null) topRow!,
              if (topRow != null) SizedBox(height: sectionGap),
              centerRow,
              if (bottomRow != null) SizedBox(height: sectionGap),
              if (bottomRow != null) bottomRow!,
            ],
          );
        },
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final CardModel? card;
  final double scale;

  static const double _baseW = 46.0;
  static const double _baseH = 64.0;

  const _TableCard({required this.card, required this.scale});

  @override
  Widget build(BuildContext context) {
    final cardW = _baseW * scale;
    final cardH = _baseH * scale;

    if (card == null) {
      return SizedBox(width: cardW, height: cardH);
    }

    return SizedBox(
      width: cardW,
      height: cardH,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _baseW,
          height: _baseH,
          child: MiniCardWidget(card!, faceDown: false, dimmed: false),
        ),
      ),
    );
  }
}

class _TrickCards extends StatelessWidget {
  final CardModel? leftCard;
  final CardModel? rightCard;
  final double scale;
  final double overlapPx;
  final GlobalKey? leftAnchorKey;
  final GlobalKey? rightAnchorKey;

  static const double _baseW = 46.0;
  static const double _baseH = 64.0;

  const _TrickCards({
    required this.leftCard,
    required this.rightCard,
    required this.scale,
    required this.overlapPx,
    this.leftAnchorKey,
    this.rightAnchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final cardW = _baseW * scale;
    final cardH = _baseH * scale;
    final totalW = (cardW * 2) - overlapPx;
    final hasLeft = leftCard != null;
    final hasRight = rightCard != null;
    final int count = (hasLeft ? 1 : 0) + (hasRight ? 1 : 0);
    final double displayW = (count == 2) ? (cardW * 2 - overlapPx) : cardW;

    return SizedBox(
      width: totalW,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(key: leftAnchorKey, width: cardW, height: cardH),
          ),
          Positioned(
            left: cardW - overlapPx,
            top: 0,
            child: SizedBox(key: rightAnchorKey, width: cardW, height: cardH),
          ),
          if (hasLeft)
            Positioned(
              left: 0,
              top: 0,
              child: _TableCard(card: leftCard, scale: scale),
            ),
          if (hasRight)
            Positioned(
              left: cardW - overlapPx,
              top: 0,
              child: _TableCard(card: rightCard, scale: scale),
            ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  const _InfoPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(.55)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
