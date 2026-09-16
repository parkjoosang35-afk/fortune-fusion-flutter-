// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_tokens.dart
// [신통방통 메인 매핑 - design_handoff_sintongbangtong_home.zip]
// 홈 화면 전면 리메이크 디자인 토큰. `Handoff.html` §03/§04/§05 스펙을
// 그대로 상수화한다. 이 화면(sintong_home/*)에서만 사용하며, 앱 전역
// UnifiedColors/UnifiedText(다른 화면들이 참조)는 건드리지 않는다.
// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color Tokens — Handoff.html §03
class SintongHomeColors {
  SintongHomeColors._();

  static const Color background = Color(0xFFFFFFFF);
  /// [메인 배경 색상 보정] 순백색(background) 그대로 화면 전체 배경으로
  /// 쓰면 인트로(다크 네이비~퍼플)와 톤이 완전히 끊겨 "흰 바탕이 앱
  /// 색상이 아닌 것 같다"는 이질감이 생긴다. 카드 자체 배경(background)은
  /// 화이트를 유지해 카드-배경 대비는 그대로 살리고, Scaffold 배경만 이
  /// 값(아주 연한 라벤더 화이트)으로 톤다운해 인트로의 보라 계열과
  /// 자연스럽게 이어지도록 한다.
  static const Color scaffoldBackground = Color(0xFFF7F6FB);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkSoft = Color(0xFF6B6B6B);
  static const Color inkMute = Color(0xFF9A9A9A);
  static const Color ember = Color(0xFFD97941);
  static const Color rose = Color(0xFFB04A5A);
  static const Color sage = Color(0xFF7BA896);
  static const Color gold = Color(0xFFD4A24A);
  static const Color storyGold = Color(0xFFFFD6A0); // 스토리 진행도트/캡션 강조
  static const Color ctaGreen = Color(0xFFB8D94A);
  static const Color cardTint = Color(0xFFFAF6EE); // 손금·관상 웜 카드
  static const Color line = Color(0xFFECECEC);
  static const Color inkBlack = Color(0xFF0F0F0F); // 프리패스 바
  static const Color chipBg = Color(0xFFF6F6F6);
  static const Color coinPillBg = Color(0xFFF4F4F4);
}

/// Radii — Handoff.html §03
class SintongHomeRadii {
  SintongHomeRadii._();

  static const double sm = 6;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 18;
  static const double pill = 999;
}

/// Spacing — Handoff.html §05
class SintongHomeSpacing {
  SintongHomeSpacing._();

  static const double screenHPad = 22;
  static const double sectionGap = 18;
  static const double cardInteriorPad = 14;
  static const double cardGap = 10;
}

/// Typography — Fraunces Italic(감성 타이틀) + Pretendard(UI 텍스트)
class SintongHomeText {
  SintongHomeText._();

  /// Brand · Display — Fraunces Italic 500, 20/1.15/-1%
  static TextStyle brand({Color color = SintongHomeColors.ink}) =>
      GoogleFonts.fraunces(
        fontSize: 20,
        height: 1.15,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
      );

  /// Hero caption — Fraunces Italic 500, 18/1.25/-1%
  static TextStyle heroCaption({Color color = Colors.white}) =>
      GoogleFonts.fraunces(
        fontSize: 18,
        height: 1.25,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.18,
        color: color,
      );

  /// Service name — Fraunces Italic 500, 18/1.15
  static TextStyle serviceName({Color color = SintongHomeColors.ink}) =>
      GoogleFonts.fraunces(
        fontSize: 18,
        height: 1.15,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.09,
        color: color,
      );

  /// Body — Pretendard 400, 12.5/1.5
  static const TextStyle body = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: SintongHomeColors.inkSoft,
  );

  /// Button/CTA — Pretendard 700, 14/1.0/+2%
  static const TextStyle cta = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.28,
    color: Colors.white,
  );

  /// Chip/Mode — Pretendard 600, 13/1.0
  static const TextStyle chip = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: SintongHomeColors.ink,
  );

  /// Caption/Meta — Pretendard 400, 11/1.4/+2%
  static const TextStyle caption = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.22,
    color: SintongHomeColors.inkMute,
  );

  /// Nav label — Pretendard 500(active 700), 10.5
  static const TextStyle navLabel = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle navLabelActive = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
  );

  /// Healing bar label — sage 11px/600
  static const TextStyle healingLabel = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.02,
    color: SintongHomeColors.sage,
  );

  /// Coin pill count text
  static const TextStyle coinCount = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: SintongHomeColors.inkSoft,
  );
}
