import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color cardBackground;
  final Color mainText;
  final Color accent;
  final Color secondaryText;
  final Color border;

  const AppColors({
    required this.background,
    required this.cardBackground,
    required this.mainText,
    required this.accent,
    required this.secondaryText,
    required this.border,
  });

  // Светлая тема
  static const light = AppColors(
    background: Color(0xFFF8F4F0),
    cardBackground: Color(0xFFF5F1EB),
    mainText: Color(0xFF4E342E),
    accent: Color(0xffab867f),
    secondaryText: Color(0xFF8D6E63),
    border: Color(0xFFD7CCC8),
  );

  // Темная тема (пример, поправим потом)
  static const dark = AppColors(
    background: Color(0xFF121212),
    cardBackground: Color(0xFF1E1E1E),
    mainText: Color(0xFFE0E0E0),
    accent: Color(0xFF333333),
    secondaryText: Color(0xFFBDBDBD),
    border: Color(0xFF333333),
  );

  @override
  ThemeExtension<AppColors> copyWith(
      {Color? background,
      Color? cardBackground,
      Color? mainText,
      Color? accent,
      Color? secondaryText,
      Color? border}) {
    return AppColors(
      background: background ?? this.background,
      cardBackground: cardBackground ?? this.cardBackground,
      mainText: mainText ?? this.mainText,
      accent: accent ?? this.accent,
      secondaryText: secondaryText ?? this.secondaryText,
      border: border ?? this.border,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      mainText: Color.lerp(mainText, other.mainText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
