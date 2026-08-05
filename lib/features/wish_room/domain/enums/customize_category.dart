/// [꾸미기 시스템] 소원방을 꾸밀 수 있는 항목 카테고리.
/// 각 카테고리는 "동시에 1개만 적용 가능"(라디오 방식)하며, 보유한
/// 여러 아이템 중 하나를 선택해 적용한다(CustomizeItem.isApplied).
enum CustomizeCategory {
  /// 메인 오브제 스킨(촛불 제단의 형태/색感 변경).
  objectSkin,

  /// 제단/받침대 디자인.
  altar,

  /// 배경 테마(밤하늘/서재/사찰/사계절 등).
  background,

  /// 치성 시 발생하는 이펙트(파티클/빛 번짐 스타일).
  effect,

  /// 방 안에 놓는 장식 소품(꽃, 초롱, 학, 방석 등) — 유일하게 다중 적용 가능.
  decoration,

  /// 시즌 한정 테마(설/추석/연말 등 기간 한정 종합 스킨 세트).
  seasonalTheme,
}

extension CustomizeCategoryX on CustomizeCategory {
  String get label {
    switch (this) {
      case CustomizeCategory.objectSkin:
        return '오브제';
      case CustomizeCategory.altar:
        return '제단';
      case CustomizeCategory.background:
        return '배경';
      case CustomizeCategory.effect:
        return '이펙트';
      case CustomizeCategory.decoration:
        return '장식';
      case CustomizeCategory.seasonalTheme:
        return '시즌 테마';
    }
  }

  /// 이 카테고리가 다중 적용을 허용하는지(장식만 true, 나머지는 단일 선택).
  bool get allowsMultiple => this == CustomizeCategory.decoration;
}

/// [꾸미기 시스템] 아이템 해금 방식.
enum CustomizeUnlockType {
  /// 복주머니로 즉시 구매.
  purchase,

  /// 성장 단계 도달 시 자동 해금(무료).
  growthReward,

  /// 연속 방문/치성 일수 도달 시 자동 해금(무료).
  streakReward,

  /// 이벤트/시즌 한정 해금(별도 조건, 예: 특정 기간 접속).
  eventLimited,
}
