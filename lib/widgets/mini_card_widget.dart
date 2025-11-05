import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../theme/card_back_theme.dart';
import '../utils/card_format.dart' show suitSymbol, rankLabel;

class MiniCardWidget extends StatelessWidget {
  final CardModel card;

  final bool faceDown;
  final bool dimmed;

  const MiniCardWidget(
      this.card, {
        super.key,
        this.faceDown = false,
        this.dimmed = false,
      });

  @override
  Widget build(BuildContext context) {
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;

    Widget front() {
      final suit = suitSymbol(card.suit);   // ← au lieu de suitEmoji(...)
      final rank = rankLabel(card.rank);    // ← au lieu de _rankText(...)

      return Stack(
        children: [
          // coin top-left
          Positioned(
            top: 6,
            left: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isRed ? Colors.red.shade700 : Colors.black87,
                  ),
                ),
                Text(
                  suit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isRed ? Colors.red.shade600 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // symbole central
          Center(
            child: Text(
              suit,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isRed ? Colors.red.shade600 : Colors.black87,
              ),
            ),
          ),
        ],
      );
    }

    Widget back() {
      // Dos de carte (sobre, lisible)
      final ext = Theme.of(context).extension<CardBackTheme>();
      final colors = ext?.gradientColors ?? const [Color(0xFF1B2245), Color(0xFF2F3A77)];
      final border = ext?.borderColor ?? Colors.white24;

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '★',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Container(
        width: 46,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: faceDown
              ? null
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isRed
                ? [const Color(0xFFFFF1F1), const Color(0xFFFFE4E4)]
                : [const Color(0xFFF3F6FF), const Color(0xFFEAEFFF)],
          ),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: faceDown ? back() : front(),
        ),
      ),
    );
  }
}
