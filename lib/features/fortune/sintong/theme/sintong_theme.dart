// ═══════════════════════════════════════════════════════════════
// SINTONG THEME — Material ThemeData 조립
//
// 사용법 (main.dart):
//   MaterialApp(
//     theme: SintongTheme.dawnHanji,
//     home: HomePage(),
//   )
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'sintong_colors.dart';
import 'sintong_typography.dart';

class SintongTheme {
  SintongTheme._();

  static const Radius _r14 = Radius.circular(14);
  static const Radius _r18 = Radius.circular(18);

  static final ThemeData dawnHanji = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: SintongColors.bg1,
    fontFamily: SintongType.ui,

    colorScheme: ColorScheme.fromSeed(
      seedColor: SintongColors.glow,
      brightness: Brightness.light,
    ).copyWith(
      primary: SintongColors.glow,
      secondary: SintongColors.crystal,
      tertiary: SintongColors.accent,
      surface: SintongColors.bg1,
      onPrimary: SintongColors.fg,
      onSurface: SintongColors.fg,
      outline: SintongColors.line,
    ),

    textTheme: TextTheme(
      displayLarge: SintongType.displayXl,
      displayMedium: SintongType.displayLg,
      headlineLarge: SintongType.h1,
      headlineMedium: SintongType.h2,
      titleMedium: SintongType.cardTitle,
      bodyLarge: SintongType.bodyText,
      bodyMedium: SintongType.bodySmall,
      labelLarge: SintongType.button,
      labelMedium: SintongType.uiChip,
      labelSmall: SintongType.mono,
      bodySmall: SintongType.caption,
    ),

    // 카드
    cardTheme: CardThemeData(
      color: SintongColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(_r14),
        side: BorderSide(color: SintongColors.line, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // Primary 버튼 (glow bg, dark text, halo shadow)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(SintongColors.glow),
        foregroundColor: WidgetStateProperty.all(SintongColors.fg),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(SintongColors.glowShadow),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20),
        ),
        textStyle: WidgetStateProperty.all(SintongType.button),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_r14),
          ),
        ),
      ),
    ),

    // Ghost 버튼 (OutlinedButton으로 매핑)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(SintongColors.fg),
        side: WidgetStateProperty.all(
          BorderSide(color: SintongColors.line, width: 1),
        ),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        textStyle: WidgetStateProperty.all(SintongType.button),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_r14),
          ),
        ),
      ),
    ),

    // AppBar (뒤로가기 + 모노 타이틀 · 우리는 커스텀 헤더 쓸 확률 높지만 폴백)
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: SintongColors.fg),
      titleTextStyle: SintongType.mono.copyWith(color: SintongColors.fg),
      centerTitle: true,
    ),

    // 하단 시트
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: SintongColors.bg1,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: _r18, topRight: _r18),
      ),
      elevation: 0,
    ),

    dividerTheme: DividerThemeData(
      color: SintongColors.line,
      thickness: 1,
      space: 1,
    ),
  );
}
