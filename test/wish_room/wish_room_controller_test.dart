import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/wish_room/data/local/wish_room_local_store.dart';
import 'package:flutter_app/features/wish_room/data/mock/mock_wish_room_repository.dart';
import 'package:flutter_app/features/wish_room/data/models/customize_item_model.dart';
import 'package:flutter_app/features/wish_room/data/models/guide_slide_model.dart';
import 'package:flutter_app/features/wish_room/data/models/prayer_session_model.dart';
import 'package:flutter_app/features/wish_room/data/models/wish_item_model.dart';
import 'package:flutter_app/features/wish_room/data/models/wish_room_model.dart';
import 'package:flutter_app/features/wish_room/data/repositories/wish_room_repository.dart';
import 'package:flutter_app/features/wish_room/domain/enums/prayer_type.dart';
import 'package:flutter_app/features/wish_room/presentation/providers/wish_room_providers.dart';

/// [Sprint 2 단위테스트 전용] MockWishRoomRepository를 감싸 호출 횟수를
/// 계측하는 spy repository. `WishRoomController.prayForWish`가 daily 중복
/// 시 "Repository를 전혀 호출하지 않고 즉시 false 반환"한다는 구현(line
/// 65-67)을 검증하려면 호출 카운터가 필요하다.
class _SpyWishRoomRepository implements WishRoomRepository {
  final MockWishRoomRepository _inner = MockWishRoomRepository();
  int prayForWishCallCount = 0;

  @override
  Future<WishRoomBundle> fetchInitialData() => _inner.fetchInitialData();

  @override
  Future<WishItem> addWish({
    required String title,
    required WishCategory category,
  }) =>
      _inner.addWish(title: title, category: category);

  @override
  Future<void> setRepresentative(String wishId, {required bool isRepresentative}) =>
      _inner.setRepresentative(wishId, isRepresentative: isRepresentative);

  @override
  Future<PrayerSession> prayForWish({
    required String wishId,
    required PrayerType type,
  }) {
    prayForWishCallCount++;
    return _inner.prayForWish(wishId: wishId, type: type);
  }

  @override
  Future<void> markGuideSeen() => _inner.markGuideSeen();

  @override
  Future<WishRoom> unlockSubSlot({required bool viaPouch}) =>
      _inner.unlockSubSlot(viaPouch: viaPouch);

  @override
  Future<List<CustomizeItem>> fetchCustomizeCatalog() => _inner.fetchCustomizeCatalog();

  @override
  Future<List<CustomizeItem>> purchaseCustomizeItem(String itemId) =>
      _inner.purchaseCustomizeItem(itemId);

  @override
  Future<List<CustomizeItem>> applyCustomizeItem(String itemId) =>
      _inner.applyCustomizeItem(itemId);

  @override
  Future<List<GuideSlide>> fetchGuideSlides() => _inner.fetchGuideSlides();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WishRoomLocalStore.resetForTest();
  });

  ProviderContainer buildContainer(_SpyWishRoomRepository spy) {
    final container = ProviderContainer(
      overrides: [
        wishRoomRepositoryProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('WishRoomController.prayForWish - daily 중복 차단', () {
    test(
      '오늘 이미 daily 치성을 했다면 두 번째 daily 호출은 false를 반환하고 '
      'Repository.prayForWish를 다시 호출하지 않는다',
      () async {
        final spy = _SpyWishRoomRepository();
        final container = buildContainer(spy);

        // 최초 데이터 로드 대기(mock repository는 대표 소원이
        // "어제 기도함" 상태로 시작하므로 hasPrayedToday=false).
        final data = await container.read(wishRoomControllerProvider.future);
        final wishId = data.room.representativeWish!.id;
        expect(data.room.hasPrayedToday, isFalse);

        final controller = container.read(wishRoomControllerProvider.notifier);

        // 첫 번째 daily 치성 -> 성공, Repository가 1회 호출되어야 한다.
        final firstResult =
            await controller.prayForWish(wishId: wishId, type: PrayerType.daily);
        expect(firstResult, isTrue);
        expect(spy.prayForWishCallCount, 1);

        // 두 번째 daily 치성(같은 날) -> Controller가 hasPrayedToday를 먼저
        // 확인해 즉시 false를 반환해야 하며, Repository 호출 카운트는
        // 그대로 1에 머물러야 한다(추가 호출 없음).
        final secondResult =
            await controller.prayForWish(wishId: wishId, type: PrayerType.daily);
        expect(secondResult, isFalse);
        expect(spy.prayForWishCallCount, 1);
      },
    );
  });

  group('WishRoomController.prayForWish - deep/focused 실패 처리', () {
    test(
      '복주머니가 부족한 상태에서 focused 치성을 시도하면 false를 반환하고 '
      'AsyncError 대신 이전 데이터(state.valueOrNull)를 유지한다',
      () async {
        final spy = _SpyWishRoomRepository();
        final container = buildContainer(spy);

        final data = await container.read(wishRoomControllerProvider.future);
        final wishId = data.room.representativeWish!.id;
        final controller = container.read(wishRoomControllerProvider.notifier);

        // 보유량 6 -> deep(비용1) 4회로 2까지 낮춘다.
        for (var i = 0; i < 4; i++) {
          final ok =
              await controller.prayForWish(wishId: wishId, type: PrayerType.deep);
          expect(ok, isTrue);
        }

        // focused(비용3) 시도는 실패해야 한다(false 반환).
        final focusedResult =
            await controller.prayForWish(wishId: wishId, type: PrayerType.focused);
        expect(focusedResult, isFalse);

        // 실패 후에도 이전 데이터가 copyWithPrevious로 보존되어 화면이
        // 갑자기 빈 상태로 깜빡이지 않아야 한다.
        final stateAfterFailure = container.read(wishRoomControllerProvider);
        expect(stateAfterFailure.hasError, isTrue);
        expect(stateAfterFailure.valueOrNull, isNotNull);
      },
    );
  });

  group('WishRoomController.unlockSubSlot - 상한 도달', () {
    test(
      '이미 서브 슬롯이 상한(2)까지 해금된 상태에서 호출해도 예외 없이 '
      'true를 반환하며 unlockedSubSlotCount는 그대로 2로 유지된다',
      () async {
        final spy = _SpyWishRoomRepository();
        final container = buildContainer(spy);

        final data = await container.read(wishRoomControllerProvider.future);
        expect(data.room.unlockedSubSlotCount, WishRoom.maxSubSlotCount);

        final controller = container.read(wishRoomControllerProvider.notifier);
        final result = await controller.unlockSubSlot(viaPouch: true);

        expect(result, isTrue); // Repository가 예외를 던지지 않으므로 true.
        final after = container.read(wishRoomControllerProvider).valueOrNull;
        expect(after?.room.unlockedSubSlotCount, WishRoom.maxSubSlotCount);
      },
    );
  });
}
