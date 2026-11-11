import 'package:expenses_charts/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text styles from the mockups (sizes in logical pixels for a 390px-wide phone).
class AppText {
  AppText._();

  static const _d = AppFonts.display;
  static const _b = AppFonts.body;
  static const _tab = AppFonts.tabular;

  // Space Grotesk: titles and big amounts
  static const pageTitle = TextStyle(fontFamily: _d, fontSize: 30, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.6);
  static const heroAmount = TextStyle(fontFamily: _d, fontSize: 46, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -1.2, fontFeatures: _tab);
  static const bigAmount = TextStyle(fontFamily: _d, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.8, fontFeatures: _tab);
  static const amountInput = TextStyle(fontFamily: _d, fontSize: 56, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -1.5, fontFeatures: _tab);
  static const tileAmount = TextStyle(fontFamily: _d, fontSize: 21, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3, fontFeatures: _tab);
  static const statAmount = TextStyle(fontFamily: _d, fontSize: 16, fontWeight: FontWeight.w700, height: 1.25, fontFeatures: _tab);
  static const donutCenter = TextStyle(fontFamily: _d, fontSize: 17, fontWeight: FontWeight.w700, height: 1.2, fontFeatures: _tab);
  static const allowance = TextStyle(fontFamily: _d, fontSize: 18, fontWeight: FontWeight.w700, fontFeatures: _tab);

  // Inter: everything else
  static const overline = TextStyle(fontFamily: _b, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3);
  static const sectionTitle = TextStyle(fontFamily: _b, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);
  static const sectionLabel = TextStyle(fontFamily: _b, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 1.1);
  static const link = TextStyle(fontFamily: _b, fontSize: 14, fontWeight: FontWeight.w600);
  static const itemTitle = TextStyle(fontFamily: _b, fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);
  static const itemSub = TextStyle(fontFamily: _b, fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.3);
  static const itemAmount = TextStyle(fontFamily: _b, fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: _tab);
  static const body = TextStyle(fontFamily: _b, fontSize: 15, fontWeight: FontWeight.w400, height: 1.35);
  static const bodyStrong = TextStyle(fontFamily: _b, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35);
  static const small = TextStyle(fontFamily: _b, fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.3);
  static const smallStrong = TextStyle(fontFamily: _b, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3);
  static const navLabel = TextStyle(fontFamily: _b, fontSize: 11.5, fontWeight: FontWeight.w500);
  static const button = TextStyle(fontFamily: _b, fontSize: 16, fontWeight: FontWeight.w600);
  static const chip = TextStyle(fontFamily: _b, fontSize: 14, fontWeight: FontWeight.w600);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: c.ink, brightness: b).copyWith(
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.ink,
      onSecondary: c.onInk,
      surface: c.card,
      onSurface: c.text,
      error: c.danger,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.divider,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppFonts.body, bodyColor: c.text, displayColor: c.text),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: b == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.cardRadius)),
        titleTextStyle: AppText.sectionTitle.copyWith(color: c.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.cardRadius))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: AppText.body.copyWith(color: c.onInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.text, textStyle: AppText.bodyStrong),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.income : c.border),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: AppText.body.copyWith(color: c.faint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.tileRadius), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.tileRadius), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.tileRadius), borderSide: BorderSide(color: c.ink, width: 1.5)),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.ink, selectionHandleColor: c.ink),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.ink,
        headerForegroundColor: c.onInk,
      ),
    );
  }
}
