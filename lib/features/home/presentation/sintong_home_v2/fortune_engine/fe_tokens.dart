// ═══════════════════════════════════════════════════════════════
// FILE: fe_tokens.dart
// [운세 엔진 디자인 핸드오프 — design_handoff_fortune_engine.zip]
// Design Tokens (Midnight Temple palette). 출처:
// uploaded_files/fortune_engine_extracted/flutter/lib/theme/sintong_tokens.dart
// (README.md가 "바로 가져다 쓸 수 있다"고 명시한 레퍼런스 구현)을 그대로
// 포팅하되, 기존 앱에 이미 존재하는 `SintongColors`
// (lib/features/fortune/sintong/theme/sintong_colors.dart, 관상·손금
// 전용 Dawn Hanji 팔레트)와 이름이 충돌하지 않도록 전부 `Fe` 접두사를
// 붙인 전용 네임스페이스로 분리한다. 이 화면(/home/fortune-engine)
// 밖에서는 참조하지 않으므로 다른 화면에 영향이 없다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

class FeColors {
  FeColors._();

  // Base palette — Midnight Temple
  static const bg1 = Color(0xFF1A0D2E);
  static const bg2 = Color(0xFF0A0716);
  static const bgDeep = Color(0xFF120A24);
  static const fg = Color(0xFFF8F2E6);
  static const muted = Color(0x9EE8DCC8);
  static const glow = Color(0xFFF5CF6A);
  static const glowShadow = Color(0x59F5CF6A);
  static const glowLight = Color(0xFFFFF3CF);
  static const glowDark = Color(0xFFC99A3A);
  static const crystal = Color(0xFF8DBFD6);
  static const accent = Color(0xFFC94A3B);
  static const accentLight = Color(0xFFD55A49);
  static const accentDark = Color(0xFFA33528);
  static const card = Color(0x0DFFEBC8);
  static const line = Color(0x1FFFEBC8);
  static const ink = Color(0xFF1A0D2E);
  static const sealText = Color(0xFFFFF9E8);

  // Engine colors
  static const saju = Color(0xFFF5CF6A);
  static const guiin = Color(0xFF8DBFD6);
  static const tarot = Color(0xFFE8C8F5);
  static const face = Color(0xFFD97941);
  static const palm = Color(0xFF7BA896);

  // Cross-check status
  static const ok = Color(0xFF7BA896);
  static const mid = Color(0xFFF5CF6A);
  static const tense = Color(0xFFE57A6C);
  static const solo = Color(0xFF8DBFD6);

  // 오행
  static const wood = Color(0xFF7BA896);
  static const fire = Color(0xFFE57A6C);
  static const earth = Color(0xFFD9A85A);
  static const metal = Color(0xFFE8E0CC);
  static const water = Color(0xFF8DBFD6);

  // Hanji scroll (해설 두루마리)
  static const scrollTop = Color(0xFFF3E5C3);
  static const scrollBottom = Color(0xFFE8D5A3);
  static const scrollInk = Color(0xFF3A2515);
  static const scrollBarLight = Color(0xFF8B5A2B);
  static const scrollBarDark = Color(0xFF4A2F15);
}

class FeFonts {
  FeFonts._();
  // 앱 pubspec.yaml에 이미 family로 등록되어 있는 폰트들을 그대로 재사용한다
  // (NotoSerifKR/GowunBatang/IBMPlexMono — 관상·손금 섹션과 동일 패밀리명).
  static const display = 'NotoSerifKR';
  static const body = 'GowunBatang';
  static const ui = 'Pretendard';
  static const mono = 'IBMPlexMono';
}

class FeText {
  FeText._();
  static const heroTitle = TextStyle(
    fontFamily: FeFonts.display,
    fontWeight: FontWeight.w900,
    fontSize: 42,
    height: 1.08,
    letterSpacing: -1.2,
    color: FeColors.fg,
  );
  static const sectionTitle = TextStyle(
    fontFamily: FeFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.3,
    letterSpacing: -0.4,
    color: FeColors.fg,
  );
  static const engineTitle = TextStyle(
    fontFamily: FeFonts.display,
    fontWeight: FontWeight.w900,
    fontSize: 28,
    height: 1.1,
    letterSpacing: -0.5,
    color: FeColors.fg,
  );
  static const lead = TextStyle(
    fontFamily: FeFonts.body,
    fontSize: 15,
    height: 1.7,
    color: FeColors.fg,
  );
  static const body = TextStyle(
    fontFamily: FeFonts.body,
    fontSize: 13.5,
    height: 1.65,
    color: FeColors.fg,
  );
  static const bodyMuted = TextStyle(
    fontFamily: FeFonts.body,
    fontSize: 13.5,
    height: 1.65,
    color: FeColors.muted,
  );
  static const cardTitle = TextStyle(
    fontFamily: FeFonts.body,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 1.45,
    color: FeColors.fg,
  );
  static const ui = TextStyle(
    fontFamily: FeFonts.ui,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.5,
    color: FeColors.fg,
  );
  static const caption = TextStyle(
    fontFamily: FeFonts.ui,
    fontSize: 11.5,
    height: 1.5,
    color: FeColors.muted,
  );
  // 항상 .toUpperCase() 하여 사용 (MONO 라벨 전부 대문자 표기).
  static const mono = TextStyle(
    fontFamily: FeFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 9.5,
    height: 1.4,
    letterSpacing: 2.6,
    color: FeColors.muted,
  );
  static const topBar = TextStyle(
    fontFamily: FeFonts.body,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: 0.3,
    color: FeColors.fg,
  );
}

class FeSpace {
  FeSpace._();
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0;
  static const s6 = 24.0, s8 = 32.0, s10 = 40.0, s12 = 48.0;
  static const screenH = 20.0;
  static const sectionTop = 32.0;
  static const maxContentWidth = 440.0;
}

class FeRadius {
  FeRadius._();
  static const seal = 6.0;
  static const chip = 10.0;
  static const smallCard = 12.0;
  static const button = 14.0;
  static const card = 16.0;
  static const altar = 18.0;
  static const hero = 20.0;
  static const pill = 999.0;
}

class FeShadow {
  FeShadow._();
  static List<BoxShadow> glow(Color c, {double blur = 20, double a = 0.35}) => [
    BoxShadow(
      color: c.withValues(alpha: a),
      blurRadius: blur,
      offset: const Offset(0, 4),
    ),
  ];
  static const primaryButton = [
    BoxShadow(color: FeColors.glowShadow, blurRadius: 20, offset: Offset(0, 4)),
  ];
  static const scroll = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

class FeMotion {
  FeMotion._();
  static const sigilSlow = Duration(seconds: 120);
  static const orbitRing = Duration(seconds: 60);
  static const corePulse = Duration(milliseconds: 3400);
  static const flicker = Duration(milliseconds: 2600);
  static const reveal = Duration(milliseconds: 700);
  static const fadeUp = Duration(milliseconds: 900);
  static const cardFlip = Duration(milliseconds: 1000);
  static const marquee = Duration(seconds: 36);
  static const revealCurve = Curves.easeOut;
  static const flipCurve = Cubic(0.3, 0.7, 0.2, 1);
}

/// 페이지 배경: linear bg1→bg2(40%)→bgDeep.
/// (3개의 radial wash는 FeStarField/배경 Stack에서 함께 그린다.)
BoxDecoration fePageBackground() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [FeColors.bg1, FeColors.bg2, FeColors.bgDeep],
    stops: [0, 0.4, 1],
  ),
);
