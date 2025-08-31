import 'package:flutter/material.dart';

/// Tonalités possibles
enum NameChipTone { neutral, positive, negative }

class NameChip extends StatefulWidget {
  final String text;
  final IconData? icon;
  final String? emoji;
  final bool active;           // petit point à droite si actif
  final bool pulse;            // clignotement/halo animé
  final NameChipTone tone;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const NameChip({
    super.key,
    required this.text,
    this.icon,
    this.emoji,
    this.active = false,
    this.pulse = false,
    this.tone = NameChipTone.neutral,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  State<NameChip> createState() => _NameChipState();
}

class _NameChipState extends State<NameChip> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 900),
    );

    // Animations douces (aller/retour)
    _opacity = Tween<double>(begin: 0.35, end: 0.9)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctl);
    _scale = Tween<double>(begin: 0.98, end: 1.04)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctl);

    if (widget.pulse) {
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant NameChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Démarre/arrête le clignotement selon pulse
    if (oldWidget.pulse != widget.pulse) {
      if (widget.pulse) {
        _ctl.repeat(reverse: true);
      } else {
        _ctl.stop();
        _ctl.reset();
      }
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Color _getToneColor() {
    switch (widget.tone) {
      case NameChipTone.positive:
        return Colors.green.shade600;
      case NameChipTone.negative:
        return Colors.red.shade600;
      case NameChipTone.neutral:
      default:
        return Colors.grey.shade800;
    }
  }

  Color _getBackgroundColor() {
    switch (widget.tone) {
      case NameChipTone.positive:
        return Colors.green.shade50;
      case NameChipTone.negative:
        return Colors.red.shade50;
      case NameChipTone.neutral:
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getToneColor();
    final bg = _getBackgroundColor();

    final chip = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.emoji != null)
            Text(widget.emoji!, style: TextStyle(fontSize: 18, color: borderColor))
          else if (widget.icon != null)
            Icon(widget.icon, size: 18, color: borderColor),

          if (widget.icon != null || widget.emoji != null) const SizedBox(width: 6),

          Text(
            widget.text,
            style: TextStyle(
              color: borderColor,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (widget.active) ...[
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );

    // Si pas de pulse, on renvoie le chip « normal »
    if (!widget.pulse) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      );
    }

    // Avec pulse : on ajoute une lueur + légère variation d’opacité/échelle
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _getToneColor().withOpacity(_opacity.value * 0.55),
                    blurRadius: 18,
                    spreadRadius: 2.5,
                  ),
                ],
              ),
              child: Opacity(
                opacity: 0.95 + (_opacity.value * 0.05),
                child: child,
              ),
            ),
          );
        },
        child: chip,
      ),
    );
  }
}
