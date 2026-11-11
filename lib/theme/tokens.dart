import 'package:flutter/material.dart';

/// Design tokens. Read them with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color card;
  final Color ink; // main buttons, selected items
  final Color onInk;
  final Color text;
  final Color muted;
  final Color faint;
  final Color divider;
  final Color track; // segment / chip / progress tracks
  final Color field; // inputs and tiles background
  final Color border;
  final Color hero; // dark "left to spend" card
  final Color heroTrack;
  final Color heroMuted;
  final Color heroButton;
  final Color income;
  final Color amber;
  final Color amberText;
  final Color barIdle;
  final Color periodBg;
  final Color periodText;
  final Color danger;

  const AppColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.onInk,
    required this.text,
    required this.muted,
    required this.faint,
    required this.divider,
    required this.track,
    required this.field,
    required this.border,
    required this.hero,
    required this.heroTrack,
    required this.heroMuted,
    required this.heroButton,
    required this.income,
    required this.amber,
    required this.amberText,
    required this.barIdle,
    required this.periodBg,
    required this.periodText,
    required this.danger,
  });

  static const light = AppColors(
    bg: Color(0xFFF2F3F5),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF15171C),
    onInk: Color(0xFFFFFFFF),
    text: Color(0xFF15171C),
    muted: Color(0xFF6B7280),
    faint: Color(0xFF9AA0AA),
    divider: Color(0xFFE6E8EC),
    track: Color(0xFFE9EBEF),
    field: Color(0xFFF4F5F7),
    border: Color(0xFFDDE0E5),
    hero: Color(0xFF16181D),
    heroTrack: Color(0xFF30333B),
    heroMuted: Color(0xFFC4C7CE),
    heroButton: Color(0xFF2A2D35),
    income: Color(0xFF1E8A5A),
    amber: Color(0xFFF2A516),
    amberText: Color(0xFFA06A00),
    barIdle: Color(0xFFCDD1D8),
    periodBg: Color(0xFFEFEAFB),
    periodText: Color(0xFF6B46C1),
    danger: Color(0xFFD03A3A),
  );

  static const dark = AppColors(
    bg: Color(0xFF0E0F12),
    card: Color(0xFF1A1C21),
    ink: Color(0xFFF2F3F5),
    onInk: Color(0xFF15171C),
    text: Color(0xFFF2F3F5),
    muted: Color(0xFF9AA0AA),
    faint: Color(0xFF6B7280),
    divider: Color(0xFF2A2D34),
    track: Color(0xFF24272E),
    field: Color(0xFF22252B),
    border: Color(0xFF30333B),
    hero: Color(0xFF22252B),
    heroTrack: Color(0xFF3A3E47),
    heroMuted: Color(0xFFB5B9C1),
    heroButton: Color(0xFF353943),
    income: Color(0xFF3DBE84),
    amber: Color(0xFFF2A516),
    amberText: Color(0xFFF2B544),
    barIdle: Color(0xFF3A3E47),
    periodBg: Color(0xFF2E2547),
    periodText: Color(0xFFB9A3F0),
    danger: Color(0xFFFF6B6B),
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

/// Spacing and radii.
class AppSizes {
  AppSizes._();
  static const double gutter = 16;
  static const double gap = 12;
  static const double cardRadius = 24;
  static const double tileRadius = 16;
  static const double cardPadding = 18;
}

/// Font families.
class AppFonts {
  AppFonts._();
  static const String body = 'Inter';
  static const String display = 'SpaceGrotesk';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}
