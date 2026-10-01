// 신통방통 소원방 · 디자인 토큰 v2.6 — app2/wr2.css :root + 컴포넌트 클래스 1:1
// ⚠️ 이 값 외의 색·폰트·라운드를 쓰지 마세요. 웹 프로토타입과 픽셀이 달라지는 1순위 원인입니다.
// (구버전 wr_theme 의 midnight/hanji/crystal 팔레트는 v2 화면에서 쓰지 않습니다 — 폐기)
//
// [폰트 소스 변경] 핸드오프 원본은 google_fonts 패키지(네트워크 다운로드)를 쓰지만,
// 이 프로젝트는 동일 폰트 파일을 assets/fonts/wish_room/ 에 번들해 pubspec.yaml 에
// NotoSerifKRWish/GowunBatangWish/IBMPlexMonoWish 패밀리로 등록해두었다(상담 모듈과 공용).
// 네트워크 의존 없이 그 번들 폰트를 그대로 쓴다 — 오프라인에서도 동작하고 웹 빌드 크기도 줄어든다.
// 값(크기/굵기/자간/색)은 원본과 1:1 동일, 폰트 조달 방식만 다르다.
import 'package:flutter/material.dart';

class WrC {
  // :root
  static const glow = Color(0xFFF5CF6A); // --glow
  static const glowShadow = Color(0x66F5CF6A); // --glow-shadow rgba(245,207,106,.4)
  static const blossom = Color(0xFFF2628F); // --blossom   ★ 주 버튼 · 선택 · 강조
  static const blossom2 = Color(0xFFFF8FB1); // --blossom-2
  static const blossomShadow = Color(0x73F2628F); // --blossom-shadow rgba(242,98,143,.45)
  static const fg = Color(0xFFFFF6EC); // --fg
  static const muted = Color(0xA8FFECDC); // --muted rgba(255,236,220,.66)
  static const line = Color(0x2EFFC8BE); // --line rgba(255,200,190,.18)
  static const panel = Color(0xB8220E1C); // --panel rgba(34,14,28,.72)
  static const panel2 = Color(0xEB3A1628); // --panel-2 rgba(58,22,40,.92)
  static const card = Color(0x0FFFDCEB); // --card rgba(255,220,235,.06)
  static const bg1 = Color(0xFF3A1630); // --bg-1
  static const bg2 = Color(0xFF12060E); // --bg-2 (모든 화면 바탕)
  static const accent = Color(0xFFC94A3B); // --accent 인장 빨강
  // 자주 쓰는 고정색
  static const cardBorder = Color(0x29FFBED2); // .card border rgba(255,190,210,.16)
  static const panelBorder = Color(0x33FFBED2); // .panel border rgba(255,190,210,.2)
  static const sheetBorder = Color(0x47FFBED2); // .sheet border rgba(255,190,210,.28)
  static const glass = Color(0x8C1E0C18); // .icon-btn/.pill bg rgba(30,12,24,.55)
  static const darkBtn = Color(0xC728101E); // .btn-dark rgba(40,16,30,.78)
  static const chipBg = Color(0x33000000); // .chip rgba(0,0,0,.2)
  static const tabsBg = Color(0x47000000); // .tabs rgba(0,0,0,.28)
  static const hanjiInk = Color(0xFF4A2A1C); // .hanji 글자
  static const navInactive = Color(0x8CFFE6DC); // .nav button rgba(255,230,220,.55)
}

class WrF {
  static TextStyle display(double size, {Color color = WrC.fg, double? height}) => TextStyle(
      fontFamily: 'NotoSerifKRWish', fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -.02 * size, color: color, height: height);
  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color color = WrC.fg, double? height}) =>
      TextStyle(fontFamily: 'GowunBatangWish', fontSize: size, fontWeight: w, color: color, height: height);
  static TextStyle ui(double size, {FontWeight w = FontWeight.w500, Color color = WrC.fg}) =>
      TextStyle(fontFamily: 'Pretendard', fontSize: size, fontWeight: w, color: color);
  /// .mono — 500 10px IBM Plex Mono, letter-spacing .28em, 대문자
  static TextStyle mono({double size = 10, Color color = WrC.muted}) =>
      TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: size, fontWeight: FontWeight.w500, letterSpacing: .28 * size, color: color);
}

class WrR { static const seal = 6.0, chip = 999.0, tab = 10.0, tabs = 14.0, card = 16.0, btn = 16.0, btnSm = 12.0, panel = 20.0, sheet = 26.0; }

/// 컴포넌트 데코레이션 — wr2.css 클래스와 이름 동일
class WrDeco {
  /// .btn-pink  linear(180deg, #ff8fb1, #f2628f 60%, #d9446f) + 0 6 24 blossom-shadow + inset 하이라이트 (Flutter: 위쪽 1px 흰 선 Container 로 대체)
  static const btnPink = BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(16)),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [WrC.blossom2, WrC.blossom, Color(0xFFD9446F)], stops: [0, .6, 1]),
      boxShadow: [BoxShadow(color: WrC.blossomShadow, blurRadius: 24, offset: Offset(0, 6))]);
  /// .btn-gold  linear(180deg, #ffe7a0, #f5cf6a 55%, #d9a53a) · 글자 #4a2a10
  static const btnGold = BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(16)),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE7A0), WrC.glow, Color(0xFFD9A53A)], stops: [0, .55, 1]),
      boxShadow: [BoxShadow(color: WrC.glowShadow, blurRadius: 22, offset: Offset(0, 6))]);
  /// .btn-dark  + BackdropFilter blur 14
  static final btnDark = BoxDecoration(borderRadius: BorderRadius.circular(16), color: WrC.darkBtn, border: Border.all(color: WrC.line));
  /// .panel  + BackdropFilter blur 18 · 그림자 0 10 30 rgba(0,0,0,.35)
  static final panel = BoxDecoration(borderRadius: BorderRadius.circular(20), color: WrC.panel, border: Border.all(color: WrC.panelBorder),
      boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 10))]);
  static final card = BoxDecoration(borderRadius: BorderRadius.circular(16), color: WrC.card, border: Border.all(color: WrC.cardBorder));
  /// .sheet  left/right 10 · bottom 22 · radius 26 · linear(180deg, rgba(62,24,44,.97), rgba(30,10,22,.98))
  static final sheet = BoxDecoration(borderRadius: BorderRadius.circular(26), border: Border.all(color: WrC.sheetBorder),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
      boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, -10)), BoxShadow(color: Color(0x38F2628F), blurRadius: 40)]);
  /// .hanji  linear(135deg, rgba(255,244,226,.97), rgba(247,226,200,.95)) · 글자 #4a2a1c
  static const hanji = BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(16)),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xF7FFF4E2), Color(0xF2F7E2C8)]),
      boxShadow: [BoxShadow(color: Color(0x73000000), blurRadius: 28, offset: Offset(0, 8)), BoxShadow(color: Color(0x80FFDCB4), spreadRadius: 1)]);
  /// .chip / .chip.on
  static final chip = BoxDecoration(borderRadius: BorderRadius.circular(999), color: WrC.chipBg, border: Border.all(color: WrC.line));
  static const chipOn = BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(999)), color: WrC.blossom, boxShadow: [BoxShadow(color: WrC.blossomShadow, blurRadius: 12, offset: Offset(0, 2))]);
  /// .tab.on
  static const tabOn = BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10)),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [WrC.blossom2, WrC.blossom]), boxShadow: [BoxShadow(color: WrC.blossomShadow, blurRadius: 14, offset: Offset(0, 3))]);
  /// .seal 34×34 rotate(-6deg)
  static const seal = BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(6)), color: WrC.accent, boxShadow: [BoxShadow(color: Color(0x80C94A3B), blurRadius: 8, offset: Offset(0, 2))]);
  /// .nav 보호 워시 — linear(180deg, rgba(16,6,12,0), rgba(16,6,12,.94) 38%) · padding 12 4 30
  static const navWash = BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00100610), Color(0xF0100610)], stops: [0, .38]));
}

/// 컴포넌트 치수 (wr2.css)
class WrSize {
  static const btnH = 54.0, btnSmH = 40.0, iconBtn = 38.0, tabH = 34.0, navItemW = 58.0, sealBox = 34.0;
  static const btnFont = 16.0, btnSmFont = 13.5, chipFont = 12.0, tabFont = 13.0, navFont = 10.5, navGlyph = 18.0, pillFont = 14.0;
  static const chipPad = EdgeInsets.symmetric(horizontal: 13, vertical: 7);
  static const pillPad = EdgeInsets.fromLTRB(5, 5, 12, 5);
  static const sheetHeaderPad = EdgeInsets.fromLTRB(20, 20, 20, 6), sheetBodyPad = EdgeInsets.fromLTRB(20, 8, 20, 20);
  static const canvas = Size(390, 844); // 모든 좌표의 기준. 실제 화면 = width/390 배율
  static const statusBarH = 54.0;
}

ThemeData wrThemeData() => ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: WrC.bg2, colorScheme: const ColorScheme.dark(primary: WrC.blossom, secondary: WrC.glow, surface: WrC.bg2, error: WrC.accent),
    splashFactory: NoSplash.splashFactory, highlightColor: Colors.transparent, fontFamily: 'Pretendard');
