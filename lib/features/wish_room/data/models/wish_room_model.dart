import '../../domain/enums/wish_slot_status.dart';
import 'wish_item_model.dart';

/// [소원방 Riverpod 실험판] 소원방 전체(사용자 1인 소유) 데이터.
///
/// [대표 소원 슬롯 시스템] 슬롯은 총 3개(인덱스 0=대표, 1~2=서브)이며,
/// 각 슬롯은 [WishItem.isRepresentative] 여부와 [unlockedSubSlotCount]로
/// 상태가 결정된다 — 슬롯 자체를 별도 리스트로 저장하지 않고 wishes +
/// unlockedSubSlotCount로부터 매번 파생(getter)한다(정책표 ① 참고).
class WishRoom {
  final String userId;
  final List<WishItem> wishes;
  final int totalPrayerCount;
  final int consecutivePrayerDays;
  final DateTime? lastVisitedAt;

  /// 마지막으로 정성을 담은 "날짜"(시각 무시, 오늘 기도 여부 판단용).
  final DateTime? lastPrayedDate;

  /// [슬롯 시스템] 해금된 서브 슬롯 개수(0~2). 기본값 0 — 신규 사용자는
  /// 대표 슬롯 1개만 가진 채 시작하고, 정책표 ①의 조건(연속 3일 방문 또는
  /// 복주머니 사용)으로 서브 슬롯을 순서대로 해금한다.
  final int unlockedSubSlotCount;

  static const int maxSlotCount = 3;
  static const int maxSubSlotCount = 2;

  /// [슬롯 시스템] 복주머니로 서브 슬롯을 즉시 해금할 때 드는 공통 가격
  /// (정책표 ① 참고). 여러 파일에서 값이 흩어지지 않도록 이 상수를 유일한
  /// 근거로 삼는다.
  static const int subSlotUnlockPouchPrice = 30;

  const WishRoom({
    required this.userId,
    required this.wishes,
    this.totalPrayerCount = 0,
    this.consecutivePrayerDays = 0,
    this.lastVisitedAt,
    this.lastPrayedDate,
    this.unlockedSubSlotCount = 0,
  });

  /// 메인 화면에 노출할 대표 소원(최대 1개, 슬롯 0번).
  WishItem? get representativeWish =>
      wishes.where((w) => w.isRepresentative).firstOrNull;

  /// 대표 소원을 포함해 메인에 노출 가능한 소원 전체(최대 3개) — 기존
  /// WishRoomScreen/WishCardList 호환을 위해 유지하는 파생 getter.
  List<WishItem> get representativeWishes => wishes.take(maxSlotCount).toList();

  /// 서브 소원 목록(대표가 아닌 소원, 최대 2개).
  List<WishItem> get subWishes =>
      wishes.where((w) => !w.isRepresentative).take(maxSubSlotCount).toList();

  /// [슬롯 시스템] 슬롯 3칸 각각의 현재 상태를 계산한다.
  /// 반환 리스트는 항상 길이 3 — index 0: 대표, index 1~2: 서브.
  List<WishSlotStatus> get slotStatuses {
    final result = <WishSlotStatus>[WishSlotStatus.representative];
    final sub = subWishes;
    for (var i = 0; i < maxSubSlotCount; i++) {
      if (i >= unlockedSubSlotCount) {
        result.add(WishSlotStatus.locked);
      } else if (i < sub.length) {
        result.add(WishSlotStatus.subFilled);
      } else {
        result.add(WishSlotStatus.subEmpty);
      }
    }
    return result;
  }

  /// 새 소원을 등록할 수 있는 빈 자리가 있는지(대표가 없거나, 해금된
  /// 서브 슬롯 중 빈 자리가 있는 경우).
  bool get hasAvailableSlot =>
      representativeWish == null || subWishes.length < unlockedSubSlotCount;

  /// [슬롯 시스템] 다음으로 해금할 서브 슬롯에 필요한 연속 방문일수.
  /// 이미 모든 서브 슬롯이 해금됐으면 null(더 해금할 슬롯 없음).
  int? get requiredStreakForNextSlot {
    if (unlockedSubSlotCount >= maxSubSlotCount) return null;
    return unlockedSubSlotCount == 0 ? 3 : 7;
  }

  /// [슬롯 시스템] 지금 당장 스트릭만으로 다음 서브 슬롯을 무료 해금할 수
  /// 있는지. `wish_room_providers.dart`의 `canUnlockSlotByStreakProvider`가
  /// 이 getter 하나로 위임한다(정책 값이 여러 곳에 흩어지지 않도록).
  bool get canUnlockNextSlotByStreak {
    final required = requiredStreakForNextSlot;
    if (required == null) return false;
    return consecutivePrayerDays >= required;
  }

  /// [재방문 축하 연출] 연속 방문일수가 슬롯 해금 임계값(3일/7일)에 "오늘
  /// 막" 도달했는지 여부 — `revisitCelebration` 플로우 전환 트리거로 쓰인다.
  /// (임계값을 막 넘겼는지는 호출측에서 이전 streak과 비교해 판단한다.)
  bool get isAtSlotUnlockMilestone =>
      consecutivePrayerDays == 3 || consecutivePrayerDays == 7;

  bool get hasPrayedToday {
    final last = lastPrayedDate;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  bool get isEmpty => wishes.isEmpty;

  WishRoom copyWith({
    List<WishItem>? wishes,
    int? totalPrayerCount,
    int? consecutivePrayerDays,
    DateTime? lastVisitedAt,
    DateTime? lastPrayedDate,
    int? unlockedSubSlotCount,
  }) {
    return WishRoom(
      userId: userId,
      wishes: wishes ?? this.wishes,
      totalPrayerCount: totalPrayerCount ?? this.totalPrayerCount,
      consecutivePrayerDays:
          consecutivePrayerDays ?? this.consecutivePrayerDays,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      lastPrayedDate: lastPrayedDate ?? this.lastPrayedDate,
      unlockedSubSlotCount: unlockedSubSlotCount ?? this.unlockedSubSlotCount,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
