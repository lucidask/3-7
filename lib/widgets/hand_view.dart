import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'mini_card_widget.dart';

typedef CardTap = void Function(CardModel card);

class HandView extends StatelessWidget {
  final List<CardModel> cards;
  final bool enabled;
  final CardTap onTap;
  final bool Function(CardModel card)? isPlayable;
  final bool faceDown;
  final double desiredOverlap;
  final double minOverlap;
  final double minScale;
  final double baseCardWidth;
  final double baseCardHeight;
  final AlignmentGeometry alignment;
  final double sidePadding;
  final double cardScale;
  final bool Function(CardModel card)? highlightWhen;

  const HandView({
    super.key,
    required this.cards,
    required this.enabled,
    required this.onTap,
    this.isPlayable,
    this.faceDown = false,
    this.desiredOverlap = 38,
    this.minOverlap = 28,
    this.minScale = 0.85,
    this.baseCardWidth = 46,
    this.baseCardHeight = 64,
    this.alignment = Alignment.center,
    this.sidePadding = 8,
    this.cardScale = 1.0,
    this.highlightWhen,

  });

  Widget _wrapHighlight(BuildContext context, Widget child) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          width: 3,
          color: Theme.of(context).colorScheme.secondary,
        ),
        boxShadow: const [
          BoxShadow(blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }


  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double bw = (baseCardWidth * cardScale).toDouble();
        final double bh = (baseCardHeight * cardScale).toDouble();
        double dxDesired = (desiredOverlap * cardScale).toDouble();
        final double dxMin = (minOverlap * cardScale).toDouble();

        final double maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (bw * cards.length);

        final int n = cards.length;
        double scale = 1.0;
        double dx = dxDesired;
        final double available = (maxW - 2 * sidePadding).clamp(0.0, double.infinity).toDouble();
        double widthNeeded = bw + (n - 1) * dx;

        if (widthNeeded > available) {
          if (n == 1) {
            scale = (available / bw).clamp(minScale, 1.0).toDouble();
          } else {
            final double dxCandidate =
            ((available - bw) / (n - 1)).clamp(dxMin, dxDesired).toDouble();
            dx = dxCandidate;
            widthNeeded = bw + (n - 1) * dx;
            if (widthNeeded > available) {
              scale = (available / widthNeeded).clamp(minScale, 1.0).toDouble();
            }
          }
        }

        final double cardW = bw * scale;
        final double cardH = bh * scale;
        final double totalInnerWidth = (cardW + (n - 1) * dx).clamp(0.0, available).toDouble();

        final children = <Widget>[];
        for (var i = 0; i < n; i++) {
          final card = cards[i];

          final playable = isPlayable?.call(card) ?? true;
          Widget base = MiniCardWidget(
            card,
            faceDown: faceDown,
            dimmed: !playable,
          );
          final isHL = highlightWhen?.call(card) == true;
          final visual = isHL ? _wrapHighlight(context, base) : base;

          children.add(
            Positioned(
              left: sidePadding + (i * dx), top: 0.0,
              child: IgnorePointer(
                ignoring: !enabled || !playable,
                child: GestureDetector(
                  onTap: (enabled && playable) ? () => onTap(card) : null,
                  child: visual,
                ),
              ),
            ),
          );
        }

        final handStack = SizedBox(
          width: totalInnerWidth + 2 * sidePadding,
          height: cardH,
          child: Stack(children: children),
        );

        final body = Opacity(opacity: enabled ? 1.0 : 0.6, child: handStack);
        return Align(alignment: alignment, child: body);
      },
    );
  }
}
