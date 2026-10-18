// shrine_tokens.dart — 신당(神堂) 디자인 토큰. 신당_개발지시서_v1.4.pdf §2(변경 금지 값)와
// 신당 디자인 핸드오프(05_design_handoff_v4/flutter/lib/core/tokens.dart)를 그대로 이식했다.
// 모든 수치는 HTML 프로토타입 shrine.css 와 1:1 대응하며, P0에서 승인된 바와 같이
// 이 프로젝트의 기존 features/<feature>/ 컨벤션(domain 계층)에 맞춰 이름만
// Shrine 접두사로 바꾸었다. 수치/색상 자체는 변경 금지 값이므로 그대로 유지한다.
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class ShrineColor {
  ShrineColor._();
  // CORE
  static const bg = Color(0xFF070404); // 붉은기 섞인 먹색 — 순수 검정 금지
  static const fg = Color(0xFFEFE4D2); // 따뜻한 회백 — 순수 흰색 금지
  static const muted = Color(0xA8EFE4D2); // fg 66%
  static const faint = Color(0x61EFE4D2); // fg 38%
  static const gold = Color(0xFFC9A368); // 촛농 묻은 놋쇠
  static const goldLine = Color(0x52C9A368); // gold 32% — 모든 패널·버튼 테두리
  static const line = Color(0x1FEFDCC8); // rgba(239,220,200,.12)
  static const panel = Color(0xBD0E0706); // rgba(14,7,6,.74) + blur 10
  // RED — 세 단계. 한 화면에 크게 두 번 나오면 실패.
  static const red = Color(0xFFA11D19); // 배지·도장 — 자주
  static const redDeep = Color(0xFF5E0C0A); // 버튼 하단
  static const redHot = Color(0xFFE0412F); // 계시 한자·선택 강조 — 아껴
  static const redGlow = Color(0x73E0412F); // 모든 그림자의 대체물
  // 부적
  static const jusa = Color(0xFF8E130E); // 주사 — UI 붉음보다 한 단계 탁하게
  static const jusa2 = Color(0xFF9B1A14);
  static const hanji1 = Color(0xFFECDCB9);
  static const hanji2 = Color(0xFFE2CEA3);
  static const ink = Color(0xFF3A2616); // 먹
  static const ember = Color(0xFFFFB070);
  // 버튼 그라데이션
  static const btnTop = Color(0xFFB8241F);
  static const btnMid = Color(0xFF7F1411);
  static const btnBot = Color(0xFF5A0B09);
  static const btnBorder = Color(0xB3D6AA64); // rgba(214,170,100,.7)
  static const btnText = Color(0xFFF8EAD6);
}

class ShrineRadius {
  ShrineRadius._();
  static const badge = 5.0,
      stamp = 6.0,
      button = 12.0,
      topic = 11.0,
      card = 12.0,
      hero = 14.0,
      sheet = 22.0,
      pill = 999.0;
}

class ShrineSpace {
  ShrineSpace._();
  static const s4 = 4.0,
      s8 = 8.0,
      s12 = 12.0,
      s16 = 16.0,
      s20 = 20.0,
      s24 = 24.0,
      s32 = 32.0,
      s40 = 40.0;
  static const screenH = 20.0; // 화면 좌우 16–22
  static const screenBottom = 40.0; // + safe-area
  static const buttonGap = 9.0; // 버튼 간격 9–10
}

/// 글로우 — 회색/검정 BoxShadow 금지. 아래 4개만 사용.
class ShrineGlow {
  ShrineGlow._();
  static const redButton = [
    BoxShadow(color: Color(0x73A11D19), blurRadius: 30, offset: Offset(0, 8)),
  ];
  static const redSoft = [BoxShadow(color: ShrineColor.redGlow, blurRadius: 24)];
  static const ember = [
    BoxShadow(color: Color(0x8CFF9646), blurRadius: 60),
  ]; // 부적 맥동
  static const gold = [BoxShadow(color: Color(0x40C9A368), blurRadius: 30)];
}

/// 모션 — 크롬 ≥1초, 파티클만 빠르게. (변경 금지 값)
class ShrineMotion {
  ShrineMotion._();
  static const screen = Duration(milliseconds: 1100);
  static const buttonIn = Duration(milliseconds: 1000); // 0.8–1.4
  static const stagger = Duration(milliseconds: 100);
  static const logo = Duration(milliseconds: 2200);
  static const press = Duration(milliseconds: 200); // scale .97
  static const pressScale = 0.97;
  static const grainStep = Duration(milliseconds: 900); // steps(4)
  static const breath = Duration(seconds: 5);
  static const candle = Duration(milliseconds: 2400);
  static const petal = Duration(seconds: 9);
  static const ember = Duration(seconds: 6);
  static const door = Duration(milliseconds: 2800);
  static const kenBurns = Duration(seconds: 28);
  static const brushPerChar = Duration(milliseconds: 900);
  static const revealHanja = Duration(milliseconds: 2400);
  static const chapter = Duration(milliseconds: 2600);
  static const stamp = Duration(milliseconds: 900);
  static const scroll = Duration(milliseconds: 1800);
  static const deal = Duration(milliseconds: 1000);
  static const typeEntry = Duration(milliseconds: 60); // 신탁
  static const typeTalk = Duration(milliseconds: 42); // 사람의 말
  static const typeStory = Duration(milliseconds: 38); // 이야기
  static const safety = Duration(milliseconds: 6800); // 영상 안전 타이머 6.5–6.8
  static const doorSafety = Duration(milliseconds: 6500); // 문 열림 전용 안전 타이머
  static const incense = Duration(seconds: 9); // 분기 향 타이머
  static const ease = Cubic(.4, 0, .2, 1);
  static const stampEase = Cubic(.2, .8, .3, 1);
}

/// 여섯 개의 목소리. 본문 크기는 모두 × textScale(.92 / 1 / 1.12).
class ShrineType {
  ShrineType._();
  static TextStyle logo() => GoogleFonts.eastSeaDokdo(
        fontSize: 112,
        height: .82,
        letterSpacing: -2.24,
        color: const Color(0xFFF4EBDE),
        shadows: const [
          Shadow(color: Color(0x66FFFFFF), blurRadius: 2),
          Shadow(color: Color(0xE6000000), blurRadius: 30, offset: Offset(0, 4)),
          Shadow(color: Color(0x80A11D19), blurRadius: 60),
        ],
      );
  static TextStyle logoHanja() => GoogleFonts.notoSerifKr(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: ShrineColor.redHot,
        shadows: const [Shadow(color: Color(0x73E0412F), blurRadius: 12)],
      );
  static TextStyle brush(double size) =>
      GoogleFonts.nanumBrushScript(fontSize: size, color: ShrineColor.jusa, height: .86);
  static TextStyle display(double size, {FontWeight w = FontWeight.w900, Color c = ShrineColor.fg}) =>
      GoogleFonts.notoSerifKr(fontSize: size, fontWeight: w, letterSpacing: -size * .02, color: c);
  static TextStyle say(double ts, {double size = 17, Color c = ShrineColor.fg, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.gowunBatang(fontSize: size * ts, height: 1.8, color: c, fontWeight: w);
  static TextStyle saySmall(double ts) =>
      GoogleFonts.gowunBatang(fontSize: 14.5 * ts, height: 1.75, color: ShrineColor.muted);
  static TextStyle ui(double ts, {double size = 14.5, FontWeight w = FontWeight.w500, Color c = ShrineColor.fg}) =>
      TextStyle(fontFamily: 'Pretendard', fontSize: size * ts, fontWeight: w, color: c);
  static TextStyle mono({Color c = ShrineColor.gold, double size = 10}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: FontWeight.w500, letterSpacing: size * .32, color: c);
}

/// [통합 Fix 03] 에셋 경로 prefix 상수화 — 지시서 §3.3 Fix03.
/// 신당 디자인 핸드오프의 assets/vid·assets/img 를 이 프로젝트 컨벤션인
/// assets/videos/shrine, assets/images/shrine 로 재배치했다(P0에서 복사 완료).
const String kShrineVideoBase = 'assets/videos/shrine/';
const String kShrineImageBase = 'assets/images/shrine/';
