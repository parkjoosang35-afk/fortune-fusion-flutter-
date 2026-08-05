import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/wish_room_analytics.dart';
import '../../domain/enums/prayer_type.dart';
import '../../data/models/wish_item_model.dart';
import '../../data/models/wish_room_model.dart';
import '../../data/models/customize_item_model.dart';
import '../../data/repositories/wish_room_repository.dart';
import '../state/wish_room_state.dart';
import '../providers/wish_room_providers.dart';

/// [소원방 Riverpod 실험판] 서버/영속 데이터(소원방 전체, 복주머니 현황,
/// 오늘의 메시지, 꾸미기 카탈로그)를 관리하는 AsyncNotifier.
///
/// 로딩/에러는 AsyncValue가 자동으로 표현하므로 별도의 boolean 플래그를
/// 두지 않는다. UI는 ref.watch(wishRoomControllerProvider)의
/// .when(loading:, error:, data:)로 분기한다.
class WishRoomController extends AsyncNotifier<WishRoomData> {
  WishRoomRepository get _repo => ref.read(wishRoomRepositoryProvider);

  @override
  Future<WishRoomData> build() async {
    final bundle = await _repo.fetchInitialData();
    return WishRoomData(
      room: bundle.room,
      pouchStatus: bundle.pouchStatus,
      dailyMessage: bundle.dailyMessage,
      isFirstVisit: bundle.isFirstVisit,
    );
  }

  /// [슬롯 시스템] 등록 가능한 슬롯이 있는지 미리 확인할 수 있는 헬퍼.
  /// WishWriteScreen이 진입 시점에 이 값을 확인해, 슬롯이 없으면 작성
  /// 폼 대신 "슬롯 확장" 안내를 보여준다(정책상 슬롯 없이 등록 자체가
  /// 불가능해야 함 — 정책표 ① 참고).
  bool get hasAvailableSlot =>
      state.valueOrNull?.room.hasAvailableSlot ?? false;

  Future<void> addWish({
    required String title,
    required WishCategory category,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.room.hasAvailableSlot) return; // 슬롯 없으면 등록 차단.

    state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
    try {
      final newWish = await _repo.addWish(title: title, category: category);
      final updatedWishes = [...current.room.wishes, newWish];
      state = AsyncData(
        current.copyWith(room: current.room.copyWith(wishes: updatedWishes)),
      );
      // [Sprint 4, ㉑ 소원성장] 신규 소원 등록 성공 이벤트.
      WishRoomAnalytics.logWishAdded(category: category.name);
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
    }
  }

  /// [치성 시스템] 통합 치성 실행. daily(무료)/deep/focused 모두 이 메서드
  /// 하나로 처리한다 — 필요 복주머니 수량/성장치 증가량은 [PrayerType]에서
  /// 파생되므로 호출부는 종류만 지정하면 된다.
  /// 성공 시 true, 실패(예: 복주머니 부족) 시 false를 반환한다.
  Future<bool> prayForWish({
    required String wishId,
    required PrayerType type,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    // [일일 치성 정책] daily는 하루 1회로 제한 — 이미 오늘 기도했다면
    // Repository를 호출하지 않고 즉시 실패 처리(정책표 ② 참고).
    if (type == PrayerType.daily && current.room.hasPrayedToday) {
      return false;
    }

    // [Sprint 4, ㉑ 치성액션] 이벤트 payload용으로 호출 전 상태를 미리
    // 기록해둔다 — WishRoomScreen._startPrayerFlow가 애니메이션 트리거를
    // 위해 이미 같은 방식으로 before/after를 비교하는 것과 동일한 계산.
    WishItem? findWish(WishRoom room) {
      for (final w in room.wishes) {
        if (w.id == wishId) return w;
      }
      return null;
    }

    final stageBefore = findWish(current.room)?.growthStage;
    final beforeCanUnlockSlot = current.room.canUnlockNextSlotByStreak;

    state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
    try {
      await _repo.prayForWish(wishId: wishId, type: type);
      // Mock 구현체는 내부적으로 이미 최신 상태를 들고 있으므로
      // fetchInitialData()를 다시 호출해 정합성을 유지한다.
      final bundle = await _repo.fetchInitialData();
      state = AsyncData(
        current.copyWith(
          room: bundle.room,
          pouchStatus: bundle.pouchStatus,
          dailyMessage: bundle.dailyMessage,
        ),
      );
      final wishAfter = findWish(bundle.room);
      final didLevelUp =
          wishAfter != null && wishAfter.growthStage != stageBefore;
      final didUnlockNewSlot =
          !beforeCanUnlockSlot && bundle.room.canUnlockNextSlotByStreak;
      // [Sprint 4, ㉑ 치성액션] 치성 종류별 실행률/유료 전환율 측정 이벤트.
      WishRoomAnalytics.logPrayerCompleted(
        prayerType: type.name,
        pouchCost: type.pouchCost,
        growthPointGain: type.growthPointGain,
        didLevelUp: didLevelUp,
        didUnlockNewSlot: didUnlockNewSlot,
      );
      return true;
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
      return false;
    }
  }

  /// [슬롯 시스템] 서브 슬롯을 해금한다. [viaPouch]가 false면 스트릭 조건
  /// 충족을 전제로 한 무료 해금 호출이다(호출측이 조건 충족 여부를 먼저
  /// 확인해야 한다 — 정책표 ① 참고).
  Future<bool> unlockSubSlot({required bool viaPouch}) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
    try {
      final updatedRoom = await _repo.unlockSubSlot(viaPouch: viaPouch);
      final bundle = await _repo.fetchInitialData();
      state = AsyncData(
        current.copyWith(room: updatedRoom, pouchStatus: bundle.pouchStatus),
      );
      // [Sprint 4, ㉑ 슬롯확장] 슬롯 해금 경로(스트릭 무료 vs 복주머니 유료) 측정 이벤트.
      WishRoomAnalytics.logSlotUnlocked(viaPouch: viaPouch);
      return true;
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
      return false;
    }
  }

  /// [꾸미기 시스템] 카탈로그를 최초 로드한다(꾸미기 화면 진입 시 호출).
  Future<void> loadCustomizeCatalog() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.customizeCatalog.isNotEmpty) return; // 이미 로드됨.

    try {
      final catalog = await _repo.fetchCustomizeCatalog();
      state = AsyncData(current.copyWith(customizeCatalog: catalog));
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
    }
  }

  Future<bool> purchaseCustomizeItem(String itemId) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    CustomizeItem? findItem(List<CustomizeItem> list) {
      for (final item in list) {
        if (item.id == itemId) return item;
      }
      return null;
    }

    final pouchCost = findItem(current.customizeCatalog)?.pouchPrice ?? 0;

    state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
    try {
      final catalog = await _repo.purchaseCustomizeItem(itemId);
      final bundle = await _repo.fetchInitialData();
      state = AsyncData(
        current.copyWith(
          customizeCatalog: catalog,
          pouchStatus: bundle.pouchStatus,
        ),
      );
      // [Sprint 4, ㉑ 꾸미기구매] 꾸미기 아이템 구매 완료 이벤트.
      WishRoomAnalytics.logCustomizeItemPurchased(
        itemId: itemId,
        pouchCost: pouchCost,
      );
      return true;
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
      return false;
    }
  }

  Future<void> applyCustomizeItem(String itemId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final catalog = await _repo.applyCustomizeItem(itemId);
      state = AsyncData(current.copyWith(customizeCatalog: catalog));
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
    }
  }

  Future<void> markGuideSeen() async {
    await _repo.markGuideSeen();
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isFirstVisit: false));
    }
  }

  /// [슬롯 시스템] 대표 소원을 교체한다(정책표 ① "대표 소원 교체" 참고).
  /// 기존 대표는 Repository 내부에서 자동으로 해제되므로(단일 선택 규칙)
  /// 호출부는 새로 대표로 지정할 [wishId]만 넘기면 된다. [wishId]가 이미
  /// 서브 슬롯에 있던 소원이어도 그대로 대표 슬롯(0번)으로 승격된다.
  ///
  /// 성공 시 true, 대상 소원을 찾을 수 없거나 통신 실패 시 false.
  Future<bool> setRepresentative(String wishId) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    final exists = current.room.wishes.any((w) => w.id == wishId);
    if (!exists) return false;
    if (current.room.representativeWish?.id == wishId) {
      return true; // 이미 대표인 소원 — 별도 호출 없이 성공 처리.
    }

    state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
    try {
      await _repo.setRepresentative(wishId, isRepresentative: true);
      final bundle = await _repo.fetchInitialData();
      state = AsyncData(current.copyWith(room: bundle.room));
      return true;
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
      return false;
    }
  }
}
