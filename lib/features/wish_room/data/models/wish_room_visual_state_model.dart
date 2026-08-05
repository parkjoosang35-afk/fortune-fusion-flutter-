import 'wish_item_model.dart';

/// [소원방 Riverpod 실험판] 메인 오브제 성장 단계.
///
/// 주의: 이 enum은 "방(Room) 전체"의 앰비언트 후광 단계다(연속 방문일
/// 기반, 4단계). 개별 소원 카드의 정성 성장 단계는 [WishGrowthStage]
/// (data/models/wish_item_model.dart)가 별도로 담당한다 — 두 축은 서로
/// 다른 기준(연속 방문 vs 정성 누적)이므로 하나로 합치지 않는다.
enum WishObjectLevel { seed, glow, bloom, radiant }

extension WishObjectLevelX on WishObjectLevel {
  /// 연속 기도일수 → 성장 단계 매핑 (MVP 규칙, 고도화 시 서버값으로 대체 가능).
  static WishObjectLevel fromStreak(int streakDays) {
    if (streakDays >= 14) return WishObjectLevel.radiant;
    if (streakDays >= 7) return WishObjectLevel.bloom;
    if (streakDays >= 3) return WishObjectLevel.glow;
    return WishObjectLevel.seed;
  }
}

/// 서버 데이터로부터 파생되는 순수 뷰(View) 상태.
/// WishRoomData에 별도로 저장하지 않고 getter로 매번 계산해서 사용한다.
class WishRoomVisualState {
  final WishObjectLevel objectLevel;

  /// 0.0 ~ 1.0
  final double glowIntensity;

  /// 0.0 ~ 1.0, 방문 누적에 따라 점진 증가
  final double backgroundSparkleLevel;

  /// [소원 성장 시스템 연동] 대표 소원의 현재 성장 단계 — 오브제의 색조
  /// (WishRoomColors.forGrowthStage)를 결정하는 데 쓰인다. 대표 소원이
  /// 없으면(빈 상태) 기본값 ember로 둔다.
  final WishGrowthStage representativeGrowthStage;

  const WishRoomVisualState({
    required this.objectLevel,
    required this.glowIntensity,
    required this.backgroundSparkleLevel,
    this.representativeGrowthStage = WishGrowthStage.ember,
  });

  factory WishRoomVisualState.fromRoom({
    required int consecutivePrayerDays,
    required bool hasPrayedToday,
    WishGrowthStage representativeGrowthStage = WishGrowthStage.ember,
  }) {
    final sparkle = (consecutivePrayerDays / 14).clamp(0.2, 1.0);
    return WishRoomVisualState(
      objectLevel: WishObjectLevelX.fromStreak(consecutivePrayerDays),
      glowIntensity: hasPrayedToday ? 0.9 : 0.4,
      backgroundSparkleLevel: sparkle.toDouble(),
      representativeGrowthStage: representativeGrowthStage,
    );
  }

  WishRoomVisualState copyWith({
    WishObjectLevel? objectLevel,
    double? glowIntensity,
    double? backgroundSparkleLevel,
    WishGrowthStage? representativeGrowthStage,
  }) {
    return WishRoomVisualState(
      objectLevel: objectLevel ?? this.objectLevel,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      backgroundSparkleLevel:
          backgroundSparkleLevel ?? this.backgroundSparkleLevel,
      representativeGrowthStage:
          representativeGrowthStage ?? this.representativeGrowthStage,
    );
  }
}
