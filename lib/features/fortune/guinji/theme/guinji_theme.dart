// ═══════════════════════════════════════════════════════════════
// SINTONG THEME — Material ThemeData 조립
//
// 사용법 (main.dart):
//   MaterialApp(
//     theme: GuinjiTheme.dawnHanji,
//     home: HomePage(),
//   )
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'guinji_colors.dart';
import 'guinji_typography.dart';

class GuinjiTheme {
  GuinjiTheme._();

  static const Radius _r14 = Radius.circular(14);
  static const Radius _r18 = Radius.circular(18);

  static final ThemeData dawnHanji = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: GuinjiColors.bg1,
    fontFamily: GuinjiType.ui,

    colorScheme: ColorScheme.fromSeed(
      seedColor: GuinjiColors.glow,
      brightness: Brightness.light,
    ).copyWith(
      primary: GuinjiColors.glow,
      secondary: GuinjiColors.crystal,
      tertiary: GuinjiColors.accent,
      surface: GuinjiColors.bg1,
      onPrimary: GuinjiColors.fg,
      onSurface: GuinjiColors.fg,
      outline: GuinjiColors.line,
    ),

    textTheme: TextTheme(
      displayLarge: GuinjiType.displayXl,
      displayMedium: GuinjiType.displayLg,
      headlineLarge: GuinjiType.h1,
      headlineMedium: GuinjiType.h2,
      titleMedium: GuinjiType.cardTitle,
      bodyLarge: GuinjiType.bodyText,
      bodyMedium: GuinjiType.bodySmall,
      labelLarge: GuinjiType.button,
      labelMedium: GuinjiType.uiChip,
      labelSmall: GuinjiType.mono,
      bodySmall: GuinjiType.caption,
    ),

    // 카드
    cardTheme: CardThemeData(
      color: GuinjiColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(_r14),
        side: BorderSide(color: GuinjiColors.line, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // Primary 버튼 (glow bg, dark text, halo shadow)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(GuinjiColors.glow),
        foregroundColor: WidgetStateProperty.all(GuinjiColors.fg),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(GuinjiColors.glowShadow),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20),
        ),
        textStyle: WidgetStateProperty.all(GuinjiType.button),
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
        foregroundColor: WidgetStateProperty.all(GuinjiColors.fg),
        side: WidgetStateProperty.all(
          BorderSide(color: GuinjiColors.line, width: 1),
        ),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        textStyle: WidgetStateProperty.all(GuinjiType.button),
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
      iconTheme: IconThemeData(color: GuinjiColors.fg),
      titleTextStyle: GuinjiType.mono.copyWith(color: GuinjiColors.fg),
      centerTitle: true,
    ),

    // 하단 시트
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: GuinjiColors.bg1,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: _r18, topRight: _r18),
      ),
      elevation: 0,
    ),

    dividerTheme: DividerThemeData(
      color: GuinjiColors.line,
      thickness: 1,
      space: 1,
    ),
  );
}
