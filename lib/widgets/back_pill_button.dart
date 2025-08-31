import 'package:flutter/material.dart';

import '../utils/nav_safe_back.dart';

/// Bouton "Retour" réutilisable.
/// - `embedded: true` => icône (ou icône+label) sans fond/bord/ombre, parfait à l'intérieur d'un cadre.
/// - `embedded: false` => pilule autonome (fond, bord, ombre) pour usage hors cadre.
class BackPillButton extends StatelessWidget {
  final String? label;                 // null => icône seule
  final IconData icon;
  final VoidCallback? onTap;

  /// Personnalisation (hors embedded). Si null => prend les couleurs du thème.
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  /// Rend le bouton plat/transparent pour être utilisé "dans" un autre cadre.
  final bool embedded;

  const BackPillButton({
    super.key,
    this.label,
    this.icon = Icons.arrow_back_rounded,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasLabel = (label != null && label!.isNotEmpty);

    // ── Variante "embedded": plat, transparent, seulement hit-test + icon/label ──
    if (embedded) {
      final fg = foregroundColor ?? cs.onSurfaceVariant;
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap ?? () => safeBack(context), // ← fallback sécurisé
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hasLabel ? 6 : 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                if (hasLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ── Variante pilule autonome (fond + bord + ombre) ──
    final bg = backgroundColor ?? cs.surfaceVariant.withOpacity(0.60);
    final fg = foregroundColor ?? cs.onSurfaceVariant;

    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap ?? () => safeBack(context),
        child: Container(
          decoration: const ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(width: 1)),
          ),
          foregroundDecoration: const ShapeDecoration(
            shape: StadiumBorder(),
            shadows: [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          padding: EdgeInsets.symmetric(horizontal: hasLabel ? 12 : 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              if (hasLabel) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
