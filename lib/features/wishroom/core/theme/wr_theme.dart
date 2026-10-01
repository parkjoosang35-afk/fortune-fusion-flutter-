// 신통방통 소원방 · Theme tokens (colors_and_type.css 1:1)
import 'package:flutter/material.dart';

enum WrPalette { midnight, hanji, crystal }

@immutable
class WrColors extends ThemeExtension<WrColors> {
  // [네이밍 충돌 수정] WrPalette.crystal 테마의 정의(static const)와 "크리스탈
  // 포인트 컬러" instance 필드가 원본 핸드오프 코드에서 둘 다 `crystal`이라는
  // 이름을 써서 Dart 컴파일 에러(conflicting_static_and_instance)가 났다.
  // 포인트 컬러 필드명을 crystalColor로 변경(의미는 동일, 외부에서 c.crystal
  // 대신 c.crystalColor로 접근).
  final Color bg1, bg2, fg, muted, glow, glowShadow, crystalColor, accent, card, line, sigil;
  const WrColors({required this.bg1, required this.bg2, required this.fg, required this.muted, required this.glow,
    required this.glowShadow, required this.crystalColor, required this.accent, required this.card, required this.line, required this.sigil});

  static const midnight = WrColors(
    bg1: Color(0xFF1A0D2E), bg2: Color(0xFF0A0716), fg: Color(0xFFF8F2E6), muted: Color(0x9EE8DCC8),
    glow: Color(0xFFF5CF6A), glowShadow: Color(0x59F5CF6A), crystalColor: Color(0xFF8DBFD6), accent: Color(0xFFC94A3B),
    card: Color(0x0DFFEBC8), line: Color(0x1FFFEBC8), sigil: Color(0xFFF5CF6A));
  static const hanji = WrColors(
    bg1: Color(0xFFFAF3E0), bg2: Color(0xFFEFE4C8), fg: Color(0xFF2A1F14), muted: Color(0x8C3C2D1E),
    glow: Color(0xFFD97941), glowShadow: Color(0x47D97941), crystalColor: Color(0xFF7BA896), accent: Color(0xFF8B3A2B),
    card: Color(0x0F8B5A2B), line: Color(0x263C2D1E), sigil: Color(0xFF8B5A2B));
  static const crystalPalette = WrColors(
    bg1: Color(0xFF3D3568), bg2: Color(0xFF1E1A3A), fg: Color(0xFFF0EAFF), muted: Color(0xA6DCD2F5),
    glow: Color(0xFFE8C8F5), glowShadow: Color(0x59E8C8F5), crystalColor: Color(0xFFA8D5E3), accent: Color(0xFF7FB8D4),
    card: Color(0x14C8B4FF), line: Color(0x26DCC8FF), sigil: Color(0xFFE8C8F5));

  static WrColors of(WrPalette p) => switch (p) { WrPalette.midnight => midnight, WrPalette.hanji => hanji, WrPalette.crystal => crystalPalette };

  /// 브랜드 규칙: 회색 그림자 금지 — 글로우만
  List<BoxShadow> get glowMd => [BoxShadow(color: glowShadow, blurRadius: 20, offset: const Offset(0, 4))];

  @override
  WrColors copyWith() => this;
  @override
  WrColors lerp(ThemeExtension<WrColors>? o, double t) {
    if (o is! WrColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return WrColors(bg1: l(bg1, o.bg1), bg2: l(bg2, o.bg2), fg: l(fg, o.fg), muted: l(muted, o.muted), glow: l(glow, o.glow),
      glowShadow: l(glowShadow, o.glowShadow), crystalColor: l(crystalColor, o.crystalColor), accent: l(accent, o.accent),
      card: l(card, o.card), line: l(line, o.line), sigil: l(sigil, o.sigil));
  }
}

class WrRadius { static const sm = 6.0, md = 10.0, lg = 14.0, xl = 20.0, pill = 999.0; }
class WrSpace { static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0, s8 = 32.0, s10 = 40.0, s12 = 48.0; }

class WrType {
  // [폰트 소스 변경] 원본은 google_fonts 패키지(네트워크 다운로드)를 썼으나,
  // 이 프로젝트는 이미 동일 폰트 파일을 assets/fonts/wish_room/에 번들해
  // pubspec.yaml에 NotoSerifKRWish/GowunBatangWish/IBMPlexMonoWish 패밀리로
  // 등록해두었다(상담 모듈과 공용). 네트워크 의존 없이 그 번들 폰트를 그대로
  // 쓴다 — 오프라인에서도 동작하고 웹 빌드 크기도 줄어든다.
  // Display: Noto Serif KR 900 · Body: Gowun Batang · UI: Pretendard(번들) · Mono: IBM Plex Mono (UPPERCASE, tracking .3em)
  static TextStyle display1(Color c) => TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 34, height: 1.15, letterSpacing: -0.68, color: c);
  static TextStyle display2(Color c) => TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w700, fontSize: 26, height: 1.2, letterSpacing: -0.52, color: c);
  static TextStyle h1(Color c) => TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w700, fontSize: 22, height: 1.3, color: c);
  static TextStyle h3(Color c) => TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 15, height: 1.4, color: c);
  static TextStyle body(Color c) => TextStyle(fontFamily: 'GowunBatangWish', fontSize: 15, height: 1.6, color: c);
  static TextStyle ui(Color c) => TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w500, fontSize: 14, height: 1.5, color: c);
  static TextStyle mono(Color c, {double size = 10}) => TextStyle(fontFamily: 'IBMPlexMonoWish', fontWeight: FontWeight.w500, fontSize: size, letterSpacing: size * 0.3, color: c);
}

ThemeData wrTheme(WrPalette p) {
  final c = WrColors.of(p);
  return ThemeData(
    brightness: p == WrPalette.hanji ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: c.bg2,
    extensions: [c],
    splashFactory: NoSplash.splashFactory, // 브랜드: 잉크 리플 대신 96% scale press
  );
}

extension WrThemeX on BuildContext { WrColors get wr => Theme.of(this).extension<WrColors>()!; }
