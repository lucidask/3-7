import 'package:flutter/material.dart';

class HandWithPileRow extends StatelessWidget {
  final Widget handView;
  final Widget pile;
  final bool pileOnLeft;
  final bool expandHand;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  const HandWithPileRow({
    super.key,
    required this.handView,
    required this.pile,
    required this.pileOnLeft,
    this.expandHand = true,
    this.spacing = 12.0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final Widget hand = expandHand ? Expanded(child: handView) : handView;
    final children = <Widget>[
      if (pileOnLeft) ...[
        pile,
        SizedBox(width: spacing),
        hand,
      ] else ...[
        hand,
        SizedBox(width: spacing),
        pile,
      ],
    ];

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}
