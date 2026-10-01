import 'package:flutter/material.dart';

/// 소원방(Wish Room) — 제단 홈 화면 전용 디자인 토큰.
///
/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전" V2 crystal 팔레트]
/// `design_handoff_wish_room.zip`의 3가지 변형(V1 심야의 신전 / V2 달빛
/// 크리스탈 / V3 새벽 한지) 중 과거 세션에서 이미 검증되어 구현되어 있던
/// **V2(crystal, anim-dramatic)** 값을 그대로 이어받는다. 기존
/// `WishWallColors`(짙은 자정보라 + 앰버)와는 별도 네임스페이스로 두어
/// 이름 충돌 없이 소원방 홈(제단) 화면에서만 사용한다.
///
/// [재화 정책 — 절대 원칙] 이 파일은 순수 디자인 토큰(색상/타이포/spacing)만
/// 다루며 어떤 화폐/잔액도 정의하지 않는다. 실제 복주머니 잔액/적립/차감은
/// 항상 [BlessingBagPolicyAdapter] → [LuckPouchProvider] → [WalletProvider]
/// 경로로만 처리된다(새 화폐 절대 생성 금지 — 과거 이 원칙 위반으로 구
/// wish_room 모듈이 2회 삭제된 전례가 있다).
class WishRoomColors {
  WishRoomColors._();

  static const backgroundDeep = Color(0xFF1E1A3A); // --bg-2
  static const backgroundMid = Color(0xFF2C2650);
  static const backgroundSoft = Color(0xFF3D3568); // --bg-1

  static const gold = Color(0xFFE8C8F5); // --glow (라벤더 글로우)
  static const goldSoft = Color(0xFFF5E4FB);

  static const glow = gold;
  static const glowSoft = goldSoft;
  static const glowShadow = Color(0x59E8C8F5);
  static const crystal = Color(0xFFA8D5E3); // --crystal (아쿠아)
  static const accent = Color(0xFF7FB8D4); // --accent
  static const sigil = Color(0xFFE8C8F5); // --sigil

  static const textPrimary = Color(0xFFF0EAFF);
  static const textSecondary = Color(0xA6DCD2F5);
  static const textTertiary = Color(0x66DCD2F5);

  static const surfaceCard = Color(0x14C8B4FF);
  static const surfaceCardBorder = Color(0x26DCC8FF);

  static const success = Color(0xFF8CD9B3);
  static const error = Color(0xFFE58A8A);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSoft, backgroundMid, backgroundDeep],
  );

  static const objectGlowGradient = RadialGradient(
    colors: [goldSoft, gold, Colors.transparent],
    stops: [0.0, 0.4, 1.0],
  );

  /// 소원 하나의 "정성 성장 단계"(0.0~1.0 glow 값 기반, 병/촛불과 무관하게
  /// 소원방 홈 제단에서 촛불 밝기·색으로 표현하기 위한 5단계 매핑).
  static Color forGrowthStage(WishGrowthStage stage) {
    switch (stage) {
      case WishGrowthStage.ember:
        return const Color(0xFF7FA8D4);
      case WishGrowthStage.smallCandle:
        return const Color(0xFF9BBEE0);
      case WishGrowthStage.steadyCandle:
        return const Color(0xFFE8C8F5);
      case WishGrowthStage.brightCandle:
        return const Color(0xFFEFD8FA);
      case WishGrowthStage.goldenFlame:
        return const Color(0xFFFAF0FF);
    }
  }

  static RadialGradient objectGradientForStage(WishGrowthStage stage) {
    final tone = forGrowthStage(stage);
    return RadialGradient(
      colors: [Colors.white, tone, Colors.transparent],
      stops: stage == WishGrowthStage.goldenFlame
          ? const [0.0, 0.55, 1.0]
          : const [0.0, 0.4, 1.0],
    );
  }
}

/// 소원 하나의 정성 성장 단계 — [WishPost.glow](0.0~1.0)를 5단계로 양자화.
enum WishGrowthStage {
  ember,
  smallCandle,
  steadyCandle,
  brightCandle,
  goldenFlame,
}

extension WishGrowthStageX on double {
  WishGrowthStage get toGrowthStage {
    if (this >= 0.85) return WishGrowthStage.goldenFlame;
    if (this >= 0.6) return WishGrowthStage.brightCandle;
    if (this >= 0.35) return WishGrowthStage.steadyCandle;
    if (this >= 0.1) return WishGrowthStage.smallCandle;
    return WishGrowthStage.ember;
  }
}

/// [디자인 핸드오프 적용] 판타지 신전 테마 타이포그래피.
///
/// 3개 폰트 패밀리(NotoSerifKRWish/GowunBatangWish/IBMPlexMonoWish)는 별도
/// 자산 등록 없이 시스템 fallback으로 렌더되며(폰트 파일 미등록 시 fontFamily
/// 지정만 무시되고 기본 폰트로 표시), 값 자체는 원본 핸드오프 스펙을 그대로
/// 유지해 추후 실제 폰트 자산을 추가하기만 하면 즉시 반영되도록 한다.
class WishRoomTextStyles {
  WishRoomTextStyles._();

  static const _serif = 'NotoSerifKRWish';
  static const _batang = 'GowunBatangWish';
  static const _mono = 'IBMPlexMonoWish';

  static const heroTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 30,
    fontWeight: FontWeight.w900,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static const screenTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const sectionTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const wishBodyList = TextStyle(
    fontFamily: _batang,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    height: 1.4,
  );

  static const wishBodyDetail = TextStyle(
    fontFamily: _serif,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    height: 1.5,
  );

  static const bodyMd = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textTertiary,
  );

  static const buttonLabel = TextStyle(
    fontFamily: _batang,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );

  static const pillLabel = TextStyle(
    fontFamily: _batang,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.0,
  );

  static const eyebrow = TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: WishRoomColors.textSecondary,
    letterSpacing: 2.0,
  );

  static const metaMono = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
    letterSpacing: 1.5,
  );
}

class WishRoomSpacing {
  WishRoomSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class WishRoomRadius {
  WishRoomRadius._();

  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}
