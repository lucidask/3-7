import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../utils/mode_label.dart';

class RoundModeChip extends StatelessWidget {
  final int roundNumber;                  // ex: 1, 2, 3...
  final GameMode mode;
  final int? sequenceTargetWins;          // si ModeLabel.build les utilise
  final int? scoreTargetPoints;           // si ModeLabel.build les utilise
  final VoidCallback? onTap;              // null => non interactif

  /// Densité compacte (hauteur ~32)
  final EdgeInsets padding;
  final double dividerHeight;

  const RoundModeChip({
    super.key,
    required this.roundNumber,
    required this.mode,
    this.sequenceTargetWins,
    this.scoreTargetPoints,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.dividerHeight = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final modeText = ModeLabel.build(
      mode,
      sequenceTargetWins: sequenceTargetWins!,
      scoreTargetPoints: scoreTargetPoints!,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Manche
        const Icon(Icons.flag, size: 16),
        const SizedBox(width: 6),
        Text(
          'Manche ${roundNumber.clamp(1, 999)}',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),

        // séparateur fin
        _vDivider(color: cs.outlineVariant.withOpacity(.55), h: dividerHeight),

        // Mode
        const Icon(Icons.category_outlined, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            modeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ),
      ],
    );

    final pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.60),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(.60)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );

    if (onTap == null) return pill;

    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: pill,
      ),
    );
  }

  Widget _vDivider({required Color color, required double h}) {
    return Container(
      width: 1,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: color,
    );
  }
}
