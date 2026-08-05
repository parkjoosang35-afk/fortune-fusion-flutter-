import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';

/// [소원방 Riverpod 실험판] 이 모듈 전용 디자인 토큰.
///
/// 앱 전역 AppColors/AppSpacing(lib/core/theme/)과 값 체계가 다르므로
/// (전역은 라이트 테마 골드/바이올렛 톤, 이 모듈은 밤하늘 감성 다크 톤)
/// 이름 충돌과 혼선을 피하기 위해 WishRoom 접두사를 붙여 모듈 내부에
/// 독립적으로 둔다. 실제 프로젝트에 정식 반영할 때는 이 값들을
/// UnifiedColors/UnifiedTokens 체계로 흡수 통합하는 것을 권장한다.
class WishRoomColors {
  WishRoomColors._();

  static const backgroundDeep = Color(0xFF1A1035);
  static const backgroundMid = Color(0xFF2B1B54);
  static const backgroundSoft = Color(0xFF3C2A6B);

  static const gold = Color(0xFFF4C560);
  static const goldSoft = Color(0xFFFDE8B8);

  static const textPrimary = Color(0xFFFDFBFF);
  static const textSecondary = Color(0xB3FDFBFF);
  static const textTertiary = Color(0x80FDFBFF);

  static const surfaceCard = Color(0x1AFFFFFF);
  static const surfaceCardBorder = Color(0x33FFFFFF);

  static const success = Color(0xFF8CD9B3);
  static const error = Color(0xFFE58A8A);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDeep, backgroundMid, backgroundSoft],
  );

  static const objectGlowGradient = RadialGradient(
    colors: [goldSoft, gold, Colors.transparent],
    stops: [0.0, 0.4, 1.0],
  );

  /// [소원 성장 시스템] 대표 소원의 [WishGrowthStage]에 대응하는 오브제 톤.
  /// 단계가 오를수록 붉은 불씨(ember) → 따뜻한 촛불 → 눈부신 금빛(goldenFlame)
  /// 순으로 색온도가 올라가도록 설계했다(정책표 ⑥ "성장 단계 정책" 참고).
  static Color forGrowthStage(WishGrowthStage stage) {
    switch (stage) {
      case WishGrowthStage.ember:
        return const Color(0xFFE8875A);
      case WishGrowthStage.smallCandle:
        return const Color(0xFFF0A85E);
      case WishGrowthStage.steadyCandle:
        return const Color(0xFFF4C560); // = gold
      case WishGrowthStage.brightCandle:
        return const Color(0xFFFAD98A);
      case WishGrowthStage.goldenFlame:
        return const Color(0xFFFFF3D0);
    }
  }

  /// 성장 단계별 오브제 그라디언트(단계가 오를수록 중심부가 더 밝고
  /// 넓게 퍼진다).
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

class WishRoomTextStyles {
  WishRoomTextStyles._();

  static const titleXl = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const titleLg = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
  );

  static const bodyMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textTertiary,
  );

  static const dailyMessage = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: WishRoomColors.goldSoft,
    fontStyle: FontStyle.italic,
    height: 1.4,
  );

  static const ctaLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.backgroundDeep,
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
