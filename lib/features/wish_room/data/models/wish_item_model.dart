/// [소원방 Riverpod 실험판] 소원 카테고리.
///
/// 이 열거형은 wish_room 모듈 내부(추천 카테고리 칩, 카드 아이콘)에서만
/// 사용되며, 기존 87개 카테고리(T/S/N/C/K/V/O/F/X/G/B/D/R) 게이팅 시스템과는
/// 완전히 무관한 소원방 전용 분류다.
enum WishCategory {
  health,
  wealth,
  exam,
  love,
  family,
  achievement,
  healing,
  custom,
}

extension WishCategoryX on WishCategory {
  String get label {
    switch (this) {
      case WishCategory.health:
        return '건강운';
      case WishCategory.wealth:
        return '금전운';
      case WishCategory.exam:
        return '합격운';
      case WishCategory.love:
        return '연애운';
      case WishCategory.family:
        return '가족운';
      case WishCategory.achievement:
        return '소망성취';
      case WishCategory.healing:
        return '마음치유';
      case WishCategory.custom:
        return '나만의 소원';
    }
  }

  String get emoji {
    switch (this) {
      case WishCategory.health:
        return '🌿';
      case WishCategory.wealth:
        return '💰';
      case WishCategory.exam:
        return '📚';
      case WishCategory.love:
        return '💗';
      case WishCategory.family:
        return '🏡';
      case WishCategory.achievement:
        return '⭐';
      case WishCategory.healing:
        return '🕊️';
      case WishCategory.custom:
        return '✨';
    }
  }
}

/// [소원 성장 시스템] 소원 하나의 "정성 누적치(growthPoint)"에 따라 결정되는
/// 성장 단계. 기본 오브제 컨셉(촛불 제단)에 맞춰 불씨→촛불→성화 흐름으로 정의.
///
/// 주의: 이 enum은 "개별 소원 카드"의 성장 단계다. 방(Room) 전체의 앰비언트
/// 오브제 후광 단계는 [WishObjectLevel](연속 방문일 기반, 4단계)이 별도로
/// 담당한다 — 서로 다른 축(정성 누적 vs 연속 방문)이므로 절대 하나로
/// 합치지 않는다(정책표 ⑥ 성장 단계 정책 참고).
enum WishGrowthStage {
  ember,
  smallCandle,
  steadyCandle,
  brightCandle,
  goldenFlame,
}

extension WishGrowthStageX on WishGrowthStage {
  /// 정성 누적치(growthPoint) → 성장 단계 매핑. 임계값은 정책표 기준값이며
  /// 서버 밸런싱 시 이 상수만 조정하면 된다.
  static WishGrowthStage fromGrowthPoint(int point) {
    if (point >= 250) return WishGrowthStage.goldenFlame;
    if (point >= 120) return WishGrowthStage.brightCandle;
    if (point >= 60) return WishGrowthStage.steadyCandle;
    if (point >= 20) return WishGrowthStage.smallCandle;
    return WishGrowthStage.ember;
  }

  /// 다음 단계로 넘어가기 위한 누적치 상한(현재 단계 진행률 계산용).
  /// 최종 단계(goldenFlame)는 상한이 없으므로 null.
  int? get nextThreshold {
    switch (this) {
      case WishGrowthStage.ember:
        return 20;
      case WishGrowthStage.smallCandle:
        return 60;
      case WishGrowthStage.steadyCandle:
        return 120;
      case WishGrowthStage.brightCandle:
        return 250;
      case WishGrowthStage.goldenFlame:
        return null;
    }
  }

  int get currentThreshold {
    switch (this) {
      case WishGrowthStage.ember:
        return 0;
      case WishGrowthStage.smallCandle:
        return 20;
      case WishGrowthStage.steadyCandle:
        return 60;
      case WishGrowthStage.brightCandle:
        return 120;
      case WishGrowthStage.goldenFlame:
        return 250;
    }
  }

  String get label {
    switch (this) {
      case WishGrowthStage.ember:
        return '불씨';
      case WishGrowthStage.smallCandle:
        return '작은 촛불';
      case WishGrowthStage.steadyCandle:
        return '안정된 촛불';
      case WishGrowthStage.brightCandle:
        return '환한 촛불';
      case WishGrowthStage.goldenFlame:
        return '황금 성화';
    }
  }

  String get emoji {
    switch (this) {
      case WishGrowthStage.ember:
        return '🕯️';
      case WishGrowthStage.smallCandle:
        return '🕯️';
      case WishGrowthStage.steadyCandle:
        return '🔥';
      case WishGrowthStage.brightCandle:
        return '🔥';
      case WishGrowthStage.goldenFlame:
        return '✨';
    }
  }
}

/// 사용자가 등록한 하나의 소원.
class WishItem {
  final String id;
  final String title;
  final WishCategory category;
  final DateTime createdAt;
  final DateTime? lastPrayedAt;
  final int prayerCount;
  final bool isRepresentative;

  /// [소원 성장 시스템] 이 소원에 쌓인 정성 누적치. 치성 타입별 증가량은
  /// [PrayerTypeX.growthPointFor] 참고. 0에서 시작해 상한 없이 누적된다
  /// (goldenFlame 도달 이후에도 계속 누적 가능 — 향후 시즌 보상/특별 연출
  /// 트리거 용도로 재사용 가능하도록 상한을 두지 않는다).
  final int growthPoint;

  /// [소원 감쇠 시스템] 서버 `WishRoomWish.maxEnergy`(관리자 설정,
  /// 기본 300)와 동일한 상한. `growthPoint`가 이 상한에 근접/도달했는지
  /// 판단할 때 쓰이며, 감쇠(미접속 시 에너지 감소) 발생 여부를 판단하는
  /// [isWeak] 게터의 기준값이기도 하다. Mock 구현체는 서버 감쇠 로직이
  /// 없으므로 기본값(300)을 그대로 사용한다.
  final int maxEnergy;

  const WishItem({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    this.lastPrayedAt,
    this.prayerCount = 0,
    this.isRepresentative = false,
    this.growthPoint = 0,
    this.maxEnergy = 300,
  });

  /// [소원 깨우기 CTA 노출 조건] 서버 `wish-room/wake` 라우트의 "깨울
  /// 필요 없음" 판단 기준(`before < maxEnergy * 0.3`)과 동일한 임계값을
  /// 클라이언트에서도 미리 계산해, 에너지가 약해진 소원에만 "🥀 소원의
  /// 빛이 조금 약해졌어요" 복귀 CTA를 노출한다(정책표 참고, 서버가 최종
  /// 판정을 다시 하므로 여기서는 UI 노출 여부만 결정한다 — 실제 회복량/
  /// 보상은 항상 서버 응답 기준).
  bool get isWeak => growthPoint < maxEnergy * 0.3;

  /// 현재 정성 누적치에 대응하는 성장 단계(파생값, 별도 저장하지 않음).
  WishGrowthStage get growthStage =>
      WishGrowthStageX.fromGrowthPoint(growthPoint);

  /// 다음 단계까지 남은 정성치(0.0~1.0 진행률). 최종 단계면 1.0.
  double get growthProgress {
    final stage = growthStage;
    final next = stage.nextThreshold;
    if (next == null) return 1.0;
    final cur = stage.currentThreshold;
    return ((growthPoint - cur) / (next - cur)).clamp(0.0, 1.0);
  }

  WishItem copyWith({
    String? title,
    WishCategory? category,
    DateTime? lastPrayedAt,
    int? prayerCount,
    bool? isRepresentative,
    int? growthPoint,
    int? maxEnergy,
  }) {
    return WishItem(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      createdAt: createdAt,
      lastPrayedAt: lastPrayedAt ?? this.lastPrayedAt,
      prayerCount: prayerCount ?? this.prayerCount,
      isRepresentative: isRepresentative ?? this.isRepresentative,
      growthPoint: growthPoint ?? this.growthPoint,
      maxEnergy: maxEnergy ?? this.maxEnergy,
    );
  }
}
