import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/wish_room/data/local/wish_room_local_store.dart';
import 'package:flutter_app/features/wish_room/data/mock/mock_wish_room_repository.dart';
import 'package:flutter_app/features/wish_room/data/models/wish_room_model.dart';
import 'package:flutter_app/features/wish_room/domain/enums/prayer_type.dart';

/// [Sprint 2 단위테스트] MockWishRoomRepository의 예외/경계 동작 검증.
///
/// [중요] unlockSubSlot과 prayForWish는 실패 처리 방식이 서로 다르다:
/// - prayForWish: 복주머니 부족 시 `throw Exception(...)`.
/// - unlockSubSlot: 서브 슬롯 상한(2) 도달 시 예외를 던지지 않고 조용히
///   변경 없는 `_room`을 그대로 반환한다(line 170-172).
/// 이 차이를 반영해 두 메서드는 서로 다른 방식(`throwsException` vs
/// 상태 불변 확인)으로 테스트한다.
///
/// [Sprint 3] `MockWishRoomRepository`가 이제 Hive(`WishRoomLocalStore`)에
/// 실제로 저장/로드하므로, 각 테스트가 이전 테스트가 남긴 디스크 상태에
/// 영향받지 않도록 `setUp`에서 매번 box를 비운다.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WishRoomLocalStore.resetForTest();
  });

  group('fetchInitialData 기본 mock 상태', () {
    test('초기 room은 대표 소원 1개 + 서브 소원 2개, 서브 슬롯은 이미 상한(2) 해금됨', () async {
      final repo = MockWishRoomRepository();
      final bundle = await repo.fetchInitialData();

      expect(bundle.room.wishes.length, 3);
      expect(bundle.room.representativeWish, isNotNull);
      expect(bundle.room.unlockedSubSlotCount, WishRoom.maxSubSlotCount);
      expect(bundle.pouchStatus.totalCount, 6);
    });
  });

  group('unlockSubSlot 상한 동작 (throw 없이 무변화 리턴)', () {
    test(
      '이미 상한(2)에 도달한 상태에서 호출하면 예외 없이 unlockedSubSlotCount가 그대로 유지된다',
      () async {
        final repo = MockWishRoomRepository();
        // 기본 mock 데이터는 이미 unlockedSubSlotCount == maxSubSlotCount(2).
        final before = (await repo.fetchInitialData()).room.unlockedSubSlotCount;
        expect(before, WishRoom.maxSubSlotCount);

        // viaPouch:true를 넘겨도(가격 30 > 보유 6) 상한 체크가 먼저이므로
        // 복주머니 부족 예외가 아니라 "조용한 무변화"로 처리되어야 한다.
        final result = await repo.unlockSubSlot(viaPouch: true);

        expect(result.unlockedSubSlotCount, WishRoom.maxSubSlotCount);
        // 예외가 발생하지 않고 정상적으로 반환값을 받았음을 명시적으로 확인.
      },
    );

    test('viaPouch:false로 호출해도 상한 상태에서는 동일하게 무변화 리턴', () async {
      final repo = MockWishRoomRepository();
      final result = await repo.unlockSubSlot(viaPouch: false);
      expect(result.unlockedSubSlotCount, WishRoom.maxSubSlotCount);
    });
  });

  group('prayForWish 성공 경로', () {
    test('daily 치성은 무료(pouchCost=0)이며 growthPoint가 5 증가한다', () async {
      final repo = MockWishRoomRepository();
      final beforeBundle = await repo.fetchInitialData();
      final wishId = beforeBundle.room.representativeWish!.id;
      final beforeGrowth = beforeBundle.room.representativeWish!.growthPoint;
      final beforePouch = beforeBundle.pouchStatus.totalCount;

      await repo.prayForWish(wishId: wishId, type: PrayerType.daily);

      final afterBundle = await repo.fetchInitialData();
      final afterWish =
          afterBundle.room.wishes.firstWhere((w) => w.id == wishId);

      expect(afterWish.growthPoint, beforeGrowth + 5);
      expect(afterBundle.pouchStatus.totalCount, beforePouch); // 복주머니 소비 없음.
    });

    test('deep 치성은 복주머니 1개를 소비하며 growthPoint가 15 증가한다', () async {
      final repo = MockWishRoomRepository();
      final beforeBundle = await repo.fetchInitialData();
      final wishId = beforeBundle.room.representativeWish!.id;
      final beforeGrowth = beforeBundle.room.representativeWish!.growthPoint;
      final beforePouch = beforeBundle.pouchStatus.totalCount;

      await repo.prayForWish(wishId: wishId, type: PrayerType.deep);

      final afterBundle = await repo.fetchInitialData();
      final afterWish =
          afterBundle.room.wishes.firstWhere((w) => w.id == wishId);

      expect(afterWish.growthPoint, beforeGrowth + 15);
      expect(afterBundle.pouchStatus.totalCount, beforePouch - 1);
    });
  });

  group('prayForWish 실패 경로 (복주머니 부족 -> throw Exception)', () {
    test('focused 치성(비용 3) 시도 시 잔액이 부족하면 Exception이 던져진다', () async {
      final repo = MockWishRoomRepository();
      final bundle = await repo.fetchInitialData();
      final wishId = bundle.room.representativeWish!.id;

      // 초기 보유량 6 -> deep(비용1)을 4회 실행해 2로 낮춘다(6-4=2 < focused 비용3).
      for (var i = 0; i < 4; i++) {
        await repo.prayForWish(wishId: wishId, type: PrayerType.deep);
      }
      final drainedPouch = (await repo.fetchInitialData()).pouchStatus.totalCount;
      expect(drainedPouch, 2);

      // 이제 focused(비용3) 시도는 잔액 부족으로 예외를 던져야 한다.
      expect(
        () => repo.prayForWish(wishId: wishId, type: PrayerType.focused),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('markGuideSeen 영속화', () {
    test('markGuideSeen 호출 후 새 인스턴스에서도 isFirstVisit=false로 유지된다', () async {
      final repo1 = MockWishRoomRepository();
      final firstBundle = await repo1.fetchInitialData();
      expect(firstBundle.isFirstVisit, isTrue); // 초회 방문 기본값.

      await repo1.markGuideSeen();

      // shared_preferences에 영속화되므로 완전히 새로운 인스턴스에서도
      // isFirstVisit=false가 유지되어야 한다(가이드 재노출 방지).
      final repo2 = MockWishRoomRepository();
      final secondBundle = await repo2.fetchInitialData();
      expect(secondBundle.isFirstVisit, isFalse);
    });
  });
}
