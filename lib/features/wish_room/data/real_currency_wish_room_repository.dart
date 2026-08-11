import '../../luckpouch/application/luck_pouch_provider.dart';
import '../domain/enums/prayer_type.dart';
import 'models/customize_item_model.dart';
import 'models/guide_slide_model.dart';
import 'models/wish_item_model.dart';
import 'models/wish_room_model.dart';
import 'models/prayer_session_model.dart';
import 'repositories/wish_room_repository.dart';
import 'mock/mock_wish_room_repository.dart';

/// ⚠️ [사용 중단 - HttpWishRoomRepository로 교체됨] 이 클래스는 소원방이
/// 실제 서버(admin_web `/api/wish-room/*` API)와 완전히 연동되기 전,
/// 클라이언트 로컬(Mock 인메모리) 상태 + 실 복주머니 잔액만 연동하던
/// 중간 단계의 구현체다. `WishRoomRiverpodEntry`의
/// `wishRoomRepositoryProvider` override 및 `wish_room_providers.dart`의
/// 기본값이 이제 [HttpWishRoomRepository]를 가리키므로, 이 클래스는 현재
/// 앱의 어떤 코드에서도 import되지 않는다(orphan). 삭제하지 않고 남겨두는
/// 이유는 "기존 구현 삭제/재작성 금지" 원칙과, 서버 장애 시 임시 롤백
/// 참고 자료로서의 가치 때문이다. 신규 기능은 이 파일이 아니라
/// [HttpWishRoomRepository](`http_wish_room_repository.dart`)에 추가한다.
///
/// [원래 설계 배경] 소원/스트릭/오늘의 메시지/성장치/꾸미기는 소원방
/// 고유 자산이라 [MockWishRoomRepository]의 인메모리 로직을 그대로
/// 재사용하지만, 복주머니 잔액/차감만은 앱의 실제 재화 원장인
/// [LuckPouchProvider](→WalletProvider)에 위임한다.
///
/// [기존 소원방과의 관계] 기존 WishRoomProvider.applyRitualReward()는
/// "무료 일일 치성 → 복주머니 적립(EARN)" 흐름이었다. 신규 설계는 "정성
/// 담기 → 복주머니 소비(SPEND)"로 정반대 방향이라 두 메커니즘이 공존할 수
/// 없다(하나의 잔액에 대해 서로 다른 화면이 자유롭게 벌고 쓰면 밸런스가
/// 무너진다). 단, PrayerType.daily(오늘의 치성)는 pouchCost=0이므로 실제
/// 잔액 차감 없이도 성장치를 올릴 수 있다 — 이것이 "매일 무료로 들어올
/// 이유"의 핵심 장치다(§3 재방문 설계 참고). 공식 전환 시 기존 무료 적립
/// 치성(EARN)은 폐기하고, 신규 설계의 daily(무료·차감없음)+deep/focused
/// (복주머니 소비)만 유지한다 — 이미 앱 전역에 출석체크(attendance)/광고
/// 시청 등 별도의 복주머니 적립 경로가 있으므로, 소원방이 별도로 적립
/// 경로를 가질 필요가 없다.
class RealCurrencyWishRoomRepository implements WishRoomRepository {
  RealCurrencyWishRoomRepository(this._luckPouch)
    : _inner = MockWishRoomRepository();

  final LuckPouchProvider _luckPouch;
  final MockWishRoomRepository _inner;

  @override
  Future<WishRoomBundle> fetchInitialData() async {
    final bundle = await _inner.fetchInitialData();
    // 표시값(totalCount)만 실 잔액으로 덮어쓴다 — 소원/스트릭 등 나머지
    // 필드는 mock 그대로 사용한다(소원방 고유 자산이라 실 백엔드 연동 범위
    // 밖, 정책표 참고).
    _inner.overridePouchTotalCount(_luckPouch.balance);
    return WishRoomBundle(
      room: bundle.room,
      pouchStatus: bundle.pouchStatus.copyWith(totalCount: _luckPouch.balance),
      dailyMessage: bundle.dailyMessage,
      isFirstVisit: bundle.isFirstVisit,
    );
  }

  @override
  Future<WishItem> addWish({
    required String title,
    required WishCategory category,
  }) => _inner.addWish(title: title, category: category);

  @override
  Future<void> setRepresentative(
    String wishId, {
    required bool isRepresentative,
  }) => _inner.setRepresentative(wishId, isRepresentative: isRepresentative);

  @override
  Future<PrayerSession> prayForWish({
    required String wishId,
    required PrayerType type,
  }) async {
    final cost = type.pouchCost;
    if (cost == 0) {
      // 오늘의 치성(무료) — 실 잔액을 건드리지 않고 mock 성장 로직만 실행.
      return _inner.prayForWish(wishId: wishId, type: type);
    }

    // 실 잔액 기준으로 먼저 검증 — 부족하면 mock을 건드리지 않고 즉시
    // 예외를 던져 Controller가 실패로 처리하게 한다(WishRoomController.
    // prayForWish()의 catch 블록에서 false를 반환 → UI가 스낵바 안내).
    if (!_luckPouch.canSpend(cost)) {
      throw Exception('복주머니가 부족합니다');
    }

    final spent = await _luckPouch.spend(
      cost,
      '소원방 정성 담기',
      sourceType: 'wish_room_prayer',
    );
    if (!spent) {
      throw Exception('복주머니가 부족합니다');
    }

    return _inner.prayWithExternalPouch(
      wishId: wishId,
      type: type,
      realBalanceAfterSpend: _luckPouch.balance,
    );
  }

  @override
  Future<WishRoom> unlockSubSlot({required bool viaPouch}) async {
    if (!viaPouch) {
      return _inner.unlockSubSlot(viaPouch: false);
    }
    const price = WishRoom.subSlotUnlockPouchPrice; // Mock과 동일 기준값.
    if (!_luckPouch.canSpend(price)) {
      throw Exception('복주머니가 부족합니다');
    }
    final spent = await _luckPouch.spend(
      price,
      '소원방 슬롯 확장',
      sourceType: 'wish_room_slot_unlock',
    );
    if (!spent) {
      throw Exception('복주머니가 부족합니다');
    }
    // 실 잔액을 이미 차감했으므로 mock 쪽은 재차감 없이 슬롯만 늘린다.
    return _inner.unlockSubSlot(viaPouch: false);
  }

  @override
  Future<List<CustomizeItem>> fetchCustomizeCatalog() =>
      _inner.fetchCustomizeCatalog();

  @override
  Future<List<CustomizeItem>> purchaseCustomizeItem(String itemId) async {
    final catalog = await _inner.fetchCustomizeCatalog();
    final item = catalog.firstWhere((c) => c.id == itemId);
    if (!_luckPouch.canSpend(item.pouchPrice)) {
      throw Exception('복주머니가 부족합니다');
    }
    final spent = await _luckPouch.spend(
      item.pouchPrice,
      '소원방 꾸미기 - ${item.name}',
      sourceType: 'wish_room_customize',
    );
    if (!spent) {
      throw Exception('복주머니가 부족합니다');
    }
    _inner.overridePouchTotalCount(_luckPouch.balance);
    return _inner.markOwnedExternally(itemId);
  }

  @override
  Future<List<CustomizeItem>> applyCustomizeItem(String itemId) =>
      _inner.applyCustomizeItem(itemId);

  @override
  Future<void> markGuideSeen() => _inner.markGuideSeen();

  @override
  Future<List<GuideSlide>> fetchGuideSlides() => _inner.fetchGuideSlides();

  /// [소원 깨우기] wake는 비용이 없는 무료 회복 액션이므로(서버
  /// `wish-room/wake` 라우트도 복주머니 소비 없이 오히려 보상을 지급하는
  /// 구조) 실 잔액 검증/차감 없이 그대로 mock 구현에 위임한다. 보상
  /// 지급(+2 복주머니)은 [MockWishRoomRepository.wakeWish] 내부에서
  /// pouch.totalCount에 반영되며, 이는 표시값일 뿐 실제 지갑 원장에는
  /// 반영되지 않는다 — 이 클래스가 orphan(사용 중단) 상태이므로 실 지갑
  /// 연동은 [HttpWishRoomRepository] 쪽에서만 이뤄진다(클래스 docstring
  /// 참고).
  @override
  Future<PrayerSession?> wakeWish(String wishId) => _inner.wakeWish(wishId);
}
