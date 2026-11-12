// ============================================================
//  행운상자 · Design Tokens (Flutter)
//  [행운상자 - 복주머니 탭 신규 기능] 사용자가 첨부한 handoff 패키지의
//  tokens.dart를 그대로 복사했다(수정 없음, 핸드오프 지시사항 그대로 준수).
//  fontDisplay/fontBody/fontMono family 이름(NotoSerifKR/GowunBatang/
//  IBMPlexMono)은 이미 pubspec.yaml에 등록된 wish_room 전용 폰트 3종과
//  완전히 동일한 family 이름이라 별도 폰트 추가 없이 그대로 재사용된다.
//  Palette: 라이트 (신통방통 앱 실제 톤)
// ============================================================

import 'package:flutter/material.dart';

class LuckyBoxTokens {
  LuckyBoxTokens._();

  // ─── Colors ───────────────────────────────────────────────
  static const bgBase = Color(0xFFFFFFFF);
  static const bgSoft = Color(0xFFFAF7FF);
  static const bgSofter = Color(0xFFF5F0FF);
  static const bgLavender = Color(0xFFF0E8FF);

  static const fgPrimary = Color(0xFF1A1A1A);
  static const fgSecondary = Color(0xFF5A5A6A);
  static const fgMuted = Color(0xFF8A8A99);
  static const fgOnGlow = Color(0xFF5A3A8A);

  static const accentGlow = Color(0xFFC89CE0); // 라벤더 (primary)
  static const accentGlowDark = Color(0xFFA878C5);
  static const accentGold = Color(0xFFF5D76E); // 발광
  static const accentRust = Color(0xFFD97941); // 그라디언트 끝
  static const accentSparkle = Color(0xFFFFF2C8); // 스파클

  static final line = const Color(0xFFDCD0F0).withValues(alpha: 0.70);
  static final lineSubtle = const Color(0xFFDCD0F0).withValues(alpha: 0.50);
  static final lineHint = const Color(0xFFC8A0DC).withValues(alpha: 0.40);

  static const ctaPrimaryBg = Color(0xFF1A1A1A); // 검정 CTA
  static const ctaPrimaryFg = Color(0xFFFFFFFF);

  // Gradients
  static const lavenderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [accentGlow, accentGlowDark],
  );

  static const heroTextGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentGlow, accentRust],
  );

  static const countUpGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A3A8A), Color(0xFFA878C5), Color(0xFFD97941)],
    stops: [0.0, 0.5, 1.0],
  );

  /// dev-spec.md §7 항목7 Jackpot 특수 연출 — 골드 계열 카운트업 그라디언트.
  static const jackpotCountUpGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD97941), accentGold, Color(0xFFF5D76E)],
    stops: [0.0, 0.5, 1.0],
  );

  // Shadows
  static final cardShadow = [
    BoxShadow(
      color: const Color(0xFFB4A0D2).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
  static final lavenderShadow = [
    BoxShadow(
      color: const Color(0xFFA878C5).withValues(alpha: 0.45),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
  static final blackShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // ─── Typography ───────────────────────────────────────────
  // family names — pubspec.yaml에 이미 등록된 동일 family를 그대로 사용.
  static const fontDisplay = 'NotoSerifKR'; // 900
  static const fontBody = 'GowunBatang'; // 400 / 700
  static const fontUi = 'Pretendard'; // 400 ~ 700
  static const fontMono = 'IBMPlexMono'; // 500

  static const TextStyle hero = TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w900,
    fontSize: 88,
    letterSpacing: -3.5,
    height: 1.0,
  );
  static const TextStyle display = TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w900,
    fontSize: 34,
    letterSpacing: -1.0,
  );
  static const TextStyle title = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w700,
    fontSize: 22,
  );
  static const TextStyle bodyText = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.6,
  );
  static const TextStyle button = TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: -0.16,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontUi,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: fgMuted,
  );
  static const TextStyle monoLabel = TextStyle(
    fontFamily: fontMono,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 3.3,
  );

  // ─── Spacing (4pt base) ───────────────────────────────────
  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 20;
  static const double sp6 = 24;
  static const double sp8 = 32;
  static const double sp10 = 40;
  static const double sp12 = 48;

  // ─── Radii ────────────────────────────────────────────────
  static const double rChip = 10;
  static const double rCard = 14;
  static const double rTile = 18;
  static const double rHero = 20;
  static const double rPill = 999;

  // ─── Animation durations ──────────────────────────────────
  static const Duration sheetUp = Duration(milliseconds: 450);
  static const Duration boxIdle = Duration(milliseconds: 3000);
  static const Duration boxShake = Duration(milliseconds: 350);
  static const Duration adLength = Duration(seconds: 5);
  static const Duration openingShake = Duration(milliseconds: 1100);
  static const Duration flash = Duration(milliseconds: 900);
  static const Duration ringExpand = Duration(milliseconds: 1400);
  static const Duration burstTotal = Duration(milliseconds: 2000);
  static const Duration countUp = Duration(milliseconds: 900);

  // Curves
  static const Curve sheetCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve particleCurve = Cubic(0.22, 0.61, 0.36, 1.0);
  static const Curve overshootCurve = Cubic(0.34, 1.56, 0.64, 1.0);
}

// ─── Reward config (표시/등급판정용 — 실제 지급량은 항상 서버가 결정) ──
class RewardConfig {
  RewardConfig._();

  static const int dailyLimit = 5;
  static const int resetHourKst = 4;

  // [보상 티어 축소, 2026-11] particlesMin/Max는 "파티클 개수"(시각효과
  // 스케일)이지 복주머니 금액이 아니므로 서버 REWARD_TIERS 축소(300→100)와
  // 무관하게 그대로 유지한다 — 바뀌어야 하는 것은 금액→파티클개수로 보간할
  // 때 쓰는 "금액 범위"(pouch_box_tab_screen.dart _particleCountFor의
  // minR/maxR)이며, 그 값을 15~100으로 맞춰 서버의 실제 보상 범위와
  // 일치시켰다(§15 "판정 기준 불일치 금지"와 같은 이유 — 100(잭팟)을
  // 받았는데 옛 "~300" 스케일 기준으로는 중간 등급 연출만 나오는 문제를
  // 방지).
  static const int particlesMin = 50;
  static const int particlesMax = 300;
  static const double particleSizeMin = 18;
  static const double particleSizeMax = 46;

  /// [핵심 원칙] 보상량 자체는 서버(`/api/pouch-box/complete`)만이 결정한다.
  /// 이 함수는 서버가 이미 응답한 [n]을 받아 결과 화면 카피만 고른다
  /// (dev-spec.md §3-4 메시지 표). 임계값은 서버 REWARD_TIERS 축소(300→100)에
  /// 맞춰 1/3로 비례 축소했다(기존 280/200/120/80 → 93/67/40/27, 등급 간
  /// 상대적 체감 비율은 그대로 유지).
  static String rewardMessage(int n) {
    if (n >= 93) return '오늘 밤하늘이 당신 편이었어요';
    if (n >= 67) return '드문 행운이 담겼습니다';
    if (n >= 40) return '오늘의 정성이 두 손 가득';
    if (n >= 27) return '조용히 쌓인 하루의 몫';
    return '다음 기회에 더 큰 복이 있어요';
  }
}
