// ═══════════════════════════════════════════════════════════════
// FILE: gh_tokens.dart
// [궁합지도 Star Map 디자인 적용] design_handoff_gunghap_map.zip
// `flutter_starter/lib/gunghap/theme/gh_tokens.dart` 포팅본.
//
// 이번 작업 범위: "궁합지도 클릭시 지금 디자인 나오게 만들어주면됨" —
// 사용자가 보낸 15섹션 분량의 정식 개발 지시서(실제 사주 FACT 엔진,
// 초대장 토큰 백엔드, 복주머니 결제 연동, 관리자 CRUD 등)는 이번
// 턴에서 구현하지 않는다. 디자인 핸드오프의 비주얼/클릭 흐름만
// 정적으로 구현한다 — 추후 실제 엔진 연동 시 이 파일의 토큰은
// 그대로 재사용 가능하다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

abstract final class GHColors {
  static const bg2 = Color(0xFF10172D); // Midnight Navy — base
  static const bg1 = Color(0xFF19233D); // Deep Navy — top tint
  static const cardSolid = Color(0xFF202B47); // Dark Blue
  static const card = Color(0xC7202B47); // 78%
  static const gold = Color(0xFFC6A15B); // Champagne Gold
  static const goldLight = Color(0xFFD4B272);
  static const goldDark = Color(0xFFB38E4B);
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
  static const glowShadow = Color(0x52C6A15B); // 32%
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
    BoxShadow(color: Color(0x6BC6A15B), blurRadius: 34, offset: Offset(0, 10)),
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
