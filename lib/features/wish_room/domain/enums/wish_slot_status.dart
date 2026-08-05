/// [대표 소원 슬롯 시스템] 소원방의 소원 슬롯 3개(대표 1 + 서브 2) 각각의
/// 상태. 슬롯은 "소원을 담을 수 있는 자리"이고, [WishItem]은 그 자리에
/// 놓인 실제 소원이다 — 슬롯이 비어 있어도(empty) 잠기지 않았다면(unlocked)
/// 언제든 새 소원을 등록해 채울 수 있다.
enum WishSlotStatus {
  /// 대표 슬롯(0번) — 항상 1개, 잠금 불가. 가장 강하게 키우는 대상이며
  /// 메인 오브제 후광/배경 반응이 대표 소원의 성장 단계를 기준으로 계산된다.
  representative,

  /// 서브 슬롯 — 해금되었고 소원이 채워진 상태.
  subFilled,

  /// 서브 슬롯 — 해금되었지만 아직 소원을 등록하지 않은 상태(빈 자리).
  subEmpty,

  /// 서브 슬롯 — 아직 해금되지 않은 잠긴 상태(정책표 ① 참고: 스트릭
  /// 달성 또는 복주머니 사용으로 해금).
  locked,
}

extension WishSlotStatusX on WishSlotStatus {
  bool get isLocked => this == WishSlotStatus.locked;
  bool get isEmptySlot =>
      this == WishSlotStatus.subEmpty; // representative는 항상 비어있을 수 없음(필수 소원)

  String get label {
    switch (this) {
      case WishSlotStatus.representative:
        return '대표 소원';
      case WishSlotStatus.subFilled:
        return '보조 소원';
      case WishSlotStatus.subEmpty:
        return '빈 자리';
      case WishSlotStatus.locked:
        return '잠긴 자리';
    }
  }
}
