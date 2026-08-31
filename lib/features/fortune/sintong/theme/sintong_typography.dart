// ═══════════════════════════════════════════════════════════════
// SINTONG TYPOGRAPHY — Font Families + Semantic Scale
// 신통방통 소원방 · Design System v1.0
//
// 사용법:
//   Text('관상', style: SintongType.displayLg)
//   Text('SINTONG · N°02', style: SintongType.mono)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'sintong_colors.dart';

class SintongType {
  SintongType._();

  // ── Font families (pubspec.yaml에 등록된 이름과 일치해야 함) ──
  static const String display = 'NotoSerifKR';  // 900 · Hero, hanja seals
  static const String body    = 'GowunBatang';  // 400/700 · Poetic body, wish content
  static const String ui      = 'Pretendard';   // 400-700 · Buttons, chips
  static const String monoFamily = 'IBMPlexMono';  // 500 · UPPERCASE meta labels

  // ── Semantic text styles ──────────────────────────────────

  /// Hero title. 34/1.15, 900, tight -0.02em
  static TextStyle displayXl = TextStyle(
    fontFamily: display, fontWeight: FontWeight.w900,
    fontSize: 34, height: 1.15, letterSpacing: -0.68,
    color: SintongColors.fg,
  );

  /// Page title. 26/1.2, 900, tight
  static TextStyle displayLg = TextStyle(
    fontFamily: display, fontWeight: FontWeight.w900,
    fontSize: 26, height: 1.2, letterSpacing: -0.52,
    color: SintongColors.fg,
  );

  /// Section h1. 22/1.3, 700
  static TextStyle h1 = TextStyle(
    fontFamily: display, fontWeight: FontWeight.w700,
    fontSize: 22, height: 1.3, letterSpacing: -0.44,
    color: SintongColors.fg,
  );

  /// Section h2. 18/1.3, 700
  static TextStyle h2 = TextStyle(
    fontFamily: display, fontWeight: FontWeight.w700,
    fontSize: 18, height: 1.3, letterSpacing: -0.36,
    color: SintongColors.fg,
  );

  /// Card title. Gowun Batang 15/1.4, 700
  static TextStyle cardTitle = TextStyle(
    fontFamily: body, fontWeight: FontWeight.w700,
    fontSize: 15, height: 1.4,
    color: SintongColors.fg,
  );

  /// Body serif. Gowun Batang 15/1.6, 400 (읽기 텍스트)
  static TextStyle bodyText = TextStyle(
    fontFamily: body, fontWeight: FontWeight.w400,
    fontSize: 15, height: 1.6,
    color: SintongColors.fg,
  );

  /// Body serif small. 13/1.65 for hero copy
  static TextStyle bodySmall = TextStyle(
    fontFamily: body, fontWeight: FontWeight.w400,
    fontSize: 13, height: 1.55,
    color: SintongColors.fg,
  );

  /// UI button label. Gowun Batang 15/1.5, 700 (Primary CTA)
  static TextStyle button = TextStyle(
    fontFamily: body, fontWeight: FontWeight.w700,
    fontSize: 15, height: 1.5,
    color: SintongColors.fg,
  );

  /// UI chip / small button. Pretendard 14/1.5, 500
  static TextStyle uiChip = TextStyle(
    fontFamily: ui, fontWeight: FontWeight.w500,
    fontSize: 14, height: 1.5,
    color: SintongColors.fg,
  );

  /// Caption. Pretendard 12/1.5, 400
  static TextStyle caption = TextStyle(
    fontFamily: ui, fontWeight: FontWeight.w400,
    fontSize: 12, height: 1.5,
    color: SintongColors.muted,
  );

  /// Mono meta label. IBM Plex Mono 11/1.4, 500, UPPERCASE, tracked 0.3em
  /// 사용 예: `SINTONG · N°02`, `NEW WISH · 001`
  static TextStyle mono = TextStyle(
    fontFamily: monoFamily, fontWeight: FontWeight.w500,
    fontSize: 11, height: 1.4,
    letterSpacing: 3.3,  // 0.3em × 11px
    color: SintongColors.muted,
  );

  /// Mono small (배지, 좌표 라벨).
  static TextStyle monoSm = TextStyle(
    fontFamily: monoFamily, fontWeight: FontWeight.w500,
    fontSize: 9, height: 1.4,
    letterSpacing: 2.7,  // 0.3em × 9px
    color: SintongColors.muted,
  );

  /// Mono eyebrow (섹션 시작 표시).
  static TextStyle eyebrow = TextStyle(
    fontFamily: monoFamily, fontWeight: FontWeight.w500,
    fontSize: 10, height: 1.4,
    letterSpacing: 4.0,  // 0.4em
    color: SintongColors.muted,
  );

  /// Hanja glyph (인장, 마법진 내부 하자).
  static TextStyle hanja = TextStyle(
    fontFamily: display, fontWeight: FontWeight.w900,
    fontSize: 20, height: 1.0,
    color: SintongColors.accent,
  );
}
