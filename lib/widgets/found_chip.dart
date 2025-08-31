import 'package:flutter/material.dart';

class FoundChip extends StatefulWidget {
  final String suit;   // '♥' | '♦' | '♣' | '♠'
  final String owner;  // "Vous" / "Adversaire" / "Joueur" / etc.

  const FoundChip({
    super.key,
    required this.suit,
    required this.owner,
  });

  @override
  State<FoundChip> createState() => _FoundChipState();
}

class _FoundChipState extends State<FoundChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRed = widget.suit == '♥' || widget.suit == '♦';
    return ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.06)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.32),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black54,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.suit,
              style: TextStyle(
                fontSize: 26,
                color: isRed ? Colors.red.shade300 : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '• ${widget.owner}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
