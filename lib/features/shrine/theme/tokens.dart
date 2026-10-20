// 신당 THE SHRINE — 디자인 토큰 (웹 shrine.css :root 값을 그대로 옮김)
// 원칙: 회색 그림자 금지 → 모든 그림자는 붉은/금 글로우. 붉은색은 3단계로 아껴 쓴다.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  // 어둠 · 본문
  static const bg = Color(0xFF070404);          // 붉은기 섞인 먹색
  static const fg = Color(0xFFEFE4D2);          // 따뜻한 회백
  static const muted = Color(0xA8EFE4D2);       // fg 66%
  static const faint = Color(0x61EFE4D2);       // fg 38%
  // 촛불(금)
  static const gold = Color(0xFFC9A368);
  static const goldLine = Color(0x52C9A368);    // 32%
  static const goldDim = Color(0x73C9A368);     // 45%
  // 붉음 3단계
  static const red = Color(0xFFA11D19);         // 배지 · 도장 (자주)
  static const redDeep = Color(0xFF5E0C0A);
  static const redHot = Color(0xFFE0412F);      // 경고 · 선택 · 계시 (아껴서)
  static const redGlow = Color(0x73E0412F);     // 45% — 모든 그림자의 대체물
  // 패널 · 선
  static const panel = Color(0xBD0E0706);       // rgba(14,7,6,.74)
  static const line = Color(0x1FEFDCC8);        // rgba(239,220,200,.12)
  // 한지 · 먹 · 주사
  static const hanjiTop = Color(0xFFECDCB9);
  static const hanjiBottom = Color(0xFFE2CEA3);
  static const ink = Color(0xFF3A2616);
  static const cinnabar = Color(0xFF8E130E);    // 부적 붓글씨
  static const btnText = Color(0xFFF8EAD6);
}

class R { // 반경
  static const badge = 5.0, seal = 6.0, btn = 12.0, opt = 11.0, card = 14.0, sheet = 22.0, pill = 999.0;
}

class Dur { // 타이밍 (디자인 스토리 §6)
  static const screen = Duration(milliseconds: 1100);
  static const logo = Duration(milliseconds: 2200);
  static const crossfade = Duration(milliseconds: 1400);
  static const brushPerChar = Duration(milliseconds: 900);
  static const reveal = Duration(milliseconds: 2400);
  static const stamp = Duration(milliseconds: 900);
  static const unroll = Duration(milliseconds: 1800);
  static const chapter = Duration(milliseconds: 2600);
  static const videoSafety = Duration(milliseconds: 6800);
  static const typeEntry = 60, typeTalk = 42, typeStory = 38; // ms / 글자
}

/// 글자 크기 배율(설정: 작게 .92 / 보통 1 / 크게 1.12)을 모든 본문에 곱한다.
class T {
  final double ts;
  const T(this.ts);
  TextStyle get logo => GoogleFonts.eastSeaDokdo(fontSize: 112, height: .82, color: const Color(0xFFF4EBDE), letterSpacing: -2);
  TextStyle get brushName => GoogleFonts.nanumBrushScript(fontSize: 76 * ts, height: .95, color: C.cinnabar);
  TextStyle display(double size, {FontWeight w = FontWeight.w700, Color c = C.fg}) =>
      GoogleFonts.notoSerifKr(fontSize: size * ts, fontWeight: w, height: 1.45, letterSpacing: -.02 * size, color: c);
  TextStyle body(double size, {FontWeight w = FontWeight.w400, Color c = C.fg, double h = 1.7}) =>
      GoogleFonts.gowunBatang(fontSize: size * ts, fontWeight: w, height: h, color: c);
  TextStyle ui(double size, {FontWeight w = FontWeight.w500, Color c = C.fg}) =>
      TextStyle(fontFamily: 'Pretendard', fontSize: size * ts, fontWeight: w, color: c);
  TextStyle get mono => GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3.2, color: C.faint);
}

/// 그림자 = 글로우
class Glow {
  static List<BoxShadow> red([double blur = 30]) => [BoxShadow(color: C.redGlow, blurRadius: blur)];
  static List<BoxShadow> gold([double blur = 16]) => [const BoxShadow(color: Color(0x66C9A368), blurRadius: 16)];
  static const btnRed = [
    BoxShadow(color: Color(0x73A11D19), blurRadius: 30, offset: Offset(0, 8)),
  ];
}

/// 빨강 버튼 그라데이션 (#b8241f → #7f1411 55% → #5a0b09)
const redButtonGradient = LinearGradient(
  begin: Alignment.topCenter, end: Alignment.bottomCenter,
  colors: [Color(0xFFB8241F), Color(0xFF7F1411), Color(0xFF5A0B09)], stops: [0, .55, 1],
);
const optGradient = LinearGradient(
  begin: Alignment.topCenter, end: Alignment.bottomCenter,
  colors: [Color(0xEB961C18), Color(0xEB5A0D0B)],
);
const hanjiGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.hanjiTop, C.hanjiBottom]);
