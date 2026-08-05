import 'package:flutter/foundation.dart';

/// [타로 섹션 전면 개편 §5-4] 저사양 기기 Degrade 옵션.
///
/// `TarotMysticBackground`(intensity 파라미터)와 `TarotParticleBurst`(count
/// 파라미터)는 이미 화려함 정도를 조절할 수 있는 파라미터를 갖고 있으므로,
/// 이 클래스는 새로운 렌더링 로직을 추가하지 않고 "어떤 값을 넘길지"만
/// 결정하는 얇은 정책 계층이다.
///
/// 1차 구현은 사용자가 설정에서 수동으로 전환하는 방식(간단하고 예측 가능)을
/// 기본으로 하고, 디바이스 성능 휴리스틱(예: 저메모리 기기 자동 감지)은
/// 2차 로드맵(§11 P6)에서 보강한다.
enum TarotVisualTier { high, medium, low }

class TarotPerfConfig {
  TarotPerfConfig._();

  static TarotVisualTier _tier = TarotVisualTier.high;

  static TarotVisualTier get tier => _tier;

  static void setTier(TarotVisualTier tier) {
    _tier = tier;
  }

  /// `TarotMysticBackground(intensity: ...)`에 전달할 값.
  static double backgroundIntensity(double baseIntensity) {
    switch (_tier) {
      case TarotVisualTier.high:
        return baseIntensity;
      case TarotVisualTier.medium:
        return baseIntensity * 0.75;
      case TarotVisualTier.low:
        return baseIntensity * 0.4;
    }
  }

  /// `TarotParticleBurst(count: ...)`에 전달할 값.
  static int particleCount(int baseCount) {
    switch (_tier) {
      case TarotVisualTier.high:
        return baseCount;
      case TarotVisualTier.medium:
        return (baseCount * 0.5).round();
      case TarotVisualTier.low:
        return 0; // low 등급에서는 파티클(L4) 완전 비활성
    }
  }

  /// 카테고리별 심볼 실루엣(L3) 레이어를 그릴지 여부.
  static bool get showSymbolLayer => _tier != TarotVisualTier.low;

  static bool get isDebugForcedLow =>
      kDebugMode && _tier == TarotVisualTier.low;
}
