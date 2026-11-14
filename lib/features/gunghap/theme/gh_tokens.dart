// ═══════════════════════════════════════════════════════════════
// FILE: gh_tokens.dart
// [궁합지도 Star Map 디자인 적용] design_handoff_gunghap_map.zip
// `flutter_starter/lib/gunghap/theme/gh_tokens.dart` 포팅본.
//
// [2026-11 「인연지도」 디자인 핸드오프 2차 반영 — 포인트 컬러 통일]
// design_handoff_gunghap_map (1).zip `README.md` §4 디자인 토큰 확정에
// 따라 기존 Champagne Gold(#C6A15B 계열)를 Accent Gold(#E2C07F 계열)
// 단일 팔레트로 전면 교체한다. 토큰 "이름"(gold/goldLight/goldDark 등)은
// 하위 호환을 위해 그대로 유지하고 값만 교체했다 — 이 토큰을 참조하는
// gh_button.dart/gh_screen.dart/star_map.dart/cat_icon.dart 등 기존
// 화면들은 코드 변경 없이 새 색상이 자동 반영된다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

abstract final class GHColors {
  static const bg2 = Color(0xFF10172D); // Midnight Navy — base
  static const bg1 = Color(0xFF19233D); // Deep Navy — top tint
  static const cardSolid = Color(0xFF202B47); // Dark Blue
  static const card = Color(0xC7202B47); // 78%
  static const gold = Color(0xFFE2C07F); // Accent Gold (2026-11 통일)
  static const goldLight = Color(0xFFF0D9A8); // Accent Gold Light
  static const goldDark = Color(0xFFD3AE69); // Accent Gold Deep
  static const violet = Color(0xFF8C7CC3); // Mystic Violet
  static const violetText = Color(0xFFB5A9E0);
  static const violetTextLight = Color(0xFFD8D0F2);
  static const ivory = Color(0xFFF3EBDD); // Moon Ivory
  static const gray = Color(0xFFAEB7C8); // Soft Gray
  static const divider = Color(0x8C66563B); // Muted Gold 55%
  static const lineSoft = Color(0x24AEB7C8); // 14%
  static const mint = Color(0xFF91C8B0);
  static const rose = Color(0xFFD98C7A);
  static const ink = Color(0xFF1A1408);
  static const glowShadow = Color(0x52E2C07F); // 32%
  static const kakao = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF191600);
  static const scrim = Color(0xB3080C1A);
}

abstract final class GHSpace {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0;
  static const s8 = 32.0, s10 = 40.0;
  static const screenH = 20.0;
  static const appBar = 56.0;
  static const minTouch = 44.0;
}

abstract final class GHRadius {
  static const button = 16.0;
  static const input = 16.0;
  static const card = 20.0;
  static const cardSm = 18.0;
  static const hero = 24.0;
  static const sheet = 24.0;
  static const chip = 999.0;
}

abstract final class GHButtonSize {
  static const xl = 58.0, lg = 54.0, md = 48.0, sm = 40.0;
}

abstract final class GHMotion {
  static const screen = Duration(milliseconds: 450);
  static const sheet = Duration(milliseconds: 400);
  static const sheetCurve = Cubic(0.22, 1, 0.36, 1);
  static const press = Duration(milliseconds: 180);
  static const lineSegment = Duration(milliseconds: 550);
  static const lineStagger = Duration(milliseconds: 220);
  static const ringRevolution = Duration(seconds: 180);
  static const pulse = Duration(milliseconds: 2400);
  static const loadingTotal = Duration(milliseconds: 5100);
}

abstract final class GHShadow {
  static const primary = [
    BoxShadow(color: GHColors.glowShadow, blurRadius: 22, offset: Offset(0, 6)),
  ];
  static const xl = [
    BoxShadow(color: Color(0x6BE2C07F), blurRadius: 34, offset: Offset(0, 10)),
  ];
  static const selected = [
    BoxShadow(color: GHColors.glowShadow, blurRadius: 24, offset: Offset(0, 6)),
  ];
}

const ghGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [GHColors.goldLight, GHColors.gold, GHColors.goldDark],
  stops: [0, .55, 1],
);
