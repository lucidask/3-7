import 'package:flutter/material.dart';

class CardBackTheme extends ThemeExtension<CardBackTheme> {
  final List<Color> gradientColors;
  final Color borderColor;

  const CardBackTheme({
    required this.gradientColors,
    required this.borderColor,
  });

  @override
  CardBackTheme copyWith({
    List<Color>? gradientColors,
    Color? borderColor,
  }) => CardBackTheme(
    gradientColors: gradientColors ?? this.gradientColors,
    borderColor: borderColor ?? this.borderColor,
  );

  @override
  CardBackTheme lerp(ThemeExtension<CardBackTheme>? other, double t) {
    if (other is! CardBackTheme) return this;
    return CardBackTheme(
      gradientColors: [
        Color.lerp(gradientColors[0], other.gradientColors[0], t)!,
        Color.lerp(gradientColors[1], other.gradientColors[1], t)!,
      ],
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
    );
  }
}
