import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.fullWidth = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool fullWidth;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final _Spec spec = _specFor(size);
    final _Colors colors = _colorsFor(variant, cs, enabled: onPressed != null && !isLoading);

    final buttonChild = isLoading
        ? SizedBox(
      width: spec.iconSize,
      height: spec.iconSize,
      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(colors.fg)),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(data: IconThemeData(size: spec.iconSize, color: colors.fg), child: icon!),
          SizedBox(width: spec.gap),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: spec.textStyle.copyWith(color: colors.fg),
          ),
        ),
      ],
    );

    final base = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(spec.radius),
        border: colors.border,
      ),
      child: Padding(
        padding: spec.padding,
        child: Center(child: buttonChild),
      ),
    );

    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(spec.radius),
        onTap: (onPressed != null && !isLoading) ? onPressed : null,
        child: base,
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

enum ButtonVariant { primary, secondary, ghost, tonal }

enum ButtonSize { sm, md, lg }

class _Colors {
  final Color bg;
  final Color fg;
  final Border? border;
  const _Colors(this.bg, this.fg, this.border);
}

class _Spec {
  final EdgeInsets padding;
  final double gap;
  final double iconSize;
  final double radius;
  final TextStyle textStyle;
  const _Spec({
    required this.padding,
    required this.gap,
    required this.iconSize,
    required this.radius,
    required this.textStyle,
  });
}

_Spec _specFor(ButtonSize size) {
  switch (size) {
    case ButtonSize.sm:
      return const _Spec(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        gap: 6,
        iconSize: 16,
        radius: 10,
        textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );
    case ButtonSize.lg:
      return const _Spec(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        gap: 10,
        iconSize: 20,
        radius: 14,
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );
    case ButtonSize.md:
      return const _Spec(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gap: 8,
        iconSize: 18,
        radius: 12,
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
  }
}

_Colors _colorsFor(ButtonVariant v, ColorScheme cs, {required bool enabled}) {
  final disabledBg = cs.surfaceVariant.withOpacity(0.5);
  final disabledFg = cs.onSurface.withOpacity(0.38);

  switch (v) {
    case ButtonVariant.primary:
      return enabled ? _Colors(cs.primary, cs.onPrimary, null) : _Colors(disabledBg, disabledFg, null);
    case ButtonVariant.secondary:
      return enabled
          ? _Colors(Colors.transparent, cs.primary, Border.all(color: cs.primary.withOpacity(0.5), width: 1))
          : _Colors(Colors.transparent, disabledFg, Border.all(color: cs.outlineVariant, width: 1));
    case ButtonVariant.ghost:
      return enabled ? _Colors(Colors.transparent, cs.primary, null) : _Colors(Colors.transparent, disabledFg, null);
    case ButtonVariant.tonal:
      return enabled ? _Colors(cs.secondaryContainer, cs.onSecondaryContainer, null) : _Colors(disabledBg, disabledFg, null);
  }
}
