// ============================================================
// 정통사주 전용 · Dawn Hanji 디자인 토큰
// 원본: flutter_handoff.zip (신통방통 디자인 이관본) theme/design_tokens.dart
//
// [naming collision 회피] 기존 프로젝트에 이미 `AppColors`
// (core/theme/app_colors.dart, 355줄, 다수 화면 참조)와 `AppSpacing`
// (core/theme/app_spacing.dart)가 존재하므로, 이 파일의 클래스는 전부
// `Hanji` 접두어를 붙여 완전히 다른 이름으로 격리한다. 값 자체는 원본
// design_tokens.dart와 100% 동일 — 이름만 바꿨다(§ naming collision 3건
// 중 AppColors/AppSpacing 대응).
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dawn Hanji 팔레트. 정통사주 화면은 이 팔레트를 고정으로 사용한다.
class HanjiColors {
  HanjiColors._();

  static const Color bg1 = Color(0xFFFAF3E0); // 크림 한지 (상단 그라디언트)
  static const Color bg2 = Color(0xFFEFE4C8); // 크림 한지 (하단 그라디언트)
  static const Color fg = Color(0xFF2A1F14); // 잉크 브라운 (본문)
  static const Color muted = Color(0x8C3C2D1E); // rgba(60,45,30,0.55)
  static const Color glow = Color(0xFFD97941); // 러스트 랜턴 (하이라이트)
  static const Color glowShadow = Color(0x47D97941); // rgba(217,121,65,0.28)
  static const Color crystal = Color(0xFF7BA896); // 옥색 (보조)
  static const Color accent = Color(0xFF8B3A2B); // 잉크 레드-브라운 (인장·경고)
  static const Color card = Color(0x0F8B5A2B); // rgba(139,90,43,0.06)
  static const Color line = Color(0x263C2D1E); // rgba(60,45,30,0.15)
  static const Color sigil = Color(0xFF8B5A2B); // 마법진 스트로크

  // 오행(五行) 색상
  static const Color mok = Color(0xFF4A7C59); // 木 · 나무 (청록)
  static const Color hwa = Color(0xFFB0463A); // 火 · 불 (붉음)
  static const Color to = Color(0xFF9A7B3F); // 土 · 흙 (황갈)
  static const Color geum = Color(0xFF8A7761); // 金 · 쇠 (베이지 그레이)
  static const Color su = Color(0xFF3A5A7A); // 水 · 물 (남색)

  static Color wuxingColor(String? el) {
    switch (el) {
      case '목':
      case '木':
        return mok;
      case '화':
      case '火':
        return hwa;
      case '토':
      case '土':
        return to;
      case '금':
      case '金':
        return geum;
      case '수':
      case '水':
        return su;
      default:
        return to;
    }
  }
}

class HanjiSpacing {
  HanjiSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double screenSide = 20;
}

class HanjiRadii {
  HanjiRadii._();
  static const double seal = 6;
  static const double chip = 10;
  static const double card = 14;
  static const double hero = 20;
  static const double scroll = 4;
  static const double pill = 999;
}

class HanjiTextStyles {
  HanjiTextStyles._();

  static TextStyle display1({Color? color}) => GoogleFonts.notoSansKr(
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.68,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle display2({Color? color}) => GoogleFonts.notoSansKr(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.52,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle h1({Color? color}) => GoogleFonts.notoSansKr(
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle bodyTitle({Color? color}) => GoogleFonts.gowunBatang(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle body({Color? color}) => GoogleFonts.gowunBatang(
        fontSize: 15,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.gowunBatang(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color ?? HanjiColors.muted,
      );

  static TextStyle ui({Color? color, FontWeight? weight}) => GoogleFonts.notoSans(
        fontSize: 14,
        height: 1.5,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle button({Color? color}) => GoogleFonts.gowunBatang(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: color ?? HanjiColors.fg,
      );

  static TextStyle monoSmall({Color? color}) => GoogleFonts.ibmPlexMono(
        fontSize: 10,
        height: 1.4,
        fontWeight: FontWeight.w500,
        letterSpacing: 3.0,
        color: color ?? HanjiColors.muted,
      );

  static TextStyle mono({Color? color}) => GoogleFonts.ibmPlexMono(
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w500,
        letterSpacing: 3.3,
        color: color ?? HanjiColors.muted,
      );
}

class HanjiMotion {
  HanjiMotion._();
  static const Duration sigilRotation = Duration(seconds: 220);
  static const Duration flameFlicker = Duration(milliseconds: 2600);
  static const Duration screenFade = Duration(milliseconds: 1200);
  static const Duration ganjiStream = Duration(seconds: 8);
  static const Duration press = Duration(milliseconds: 120);
}
