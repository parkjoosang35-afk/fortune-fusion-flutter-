import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/enums/customize_category.dart';
import '../../domain/enums/prayer_type.dart';
import '../local/wish_room_local_store.dart';
import '../models/customize_item_model.dart';
import '../models/guide_slide_model.dart';
import '../models/wish_item_model.dart';
import '../models/wish_room_model.dart';
import '../models/prayer_session_model.dart';
import '../repositories/wish_room_repository.dart';
import 'mock_wish_room_data.dart';

/// [소원방 Riverpod 실험판] 서버 없이 화면을 바로 렌더링하기 위한 인메모리
/// Mock 구현체. 실 API 연동 시 이 클래스 대신 WishRoomRepository를 구현하는
/// 새 클래스(예: HttpWishRoomRepository)를 주입하면 된다.
///
/// [초회 가이드 영속화] 소원/스트릭 등은 여전히 인메모리 mock이지만,
/// "초회 가이드를 봤는가"만은 shared_preferences로 기기에 저장한다 —
/// 그렇지 않으면 앱을 새로 열 때마다 가이드 팝업이 매번 다시 뜨는
/// 사용자 경험 문제가 생긴다.
///
/// [Sprint 3 로컬 영속성] 소원/성장치/슬롯/복주머니 표시값/꾸미기 카탈로그도
/// [WishRoomLocalStore](Hive 기반)로 영속화한다. 최초 `fetchInitialData()`
/// 호출 시 저장된 값이 있으면 그것으로 인메모리 상태를 대체하고, 이후
/// 상태를 변경하는 모든 메서드(정성 담기/소원 등록/슬롯 해금/꾸미기 구매·
/// 적용) 끝에서 변경된 부분만 다시 저장한다. 저장소가 비어 있거나(첫 실행)
/// Hive를 사용할 수 없는 환경(예: 단위 테스트)이면 조용히 기존 인메모리
/// mock 값을 그대로 사용한다(WishRoomLocalStore의 방어적 실패 처리 참고).
class MockWishRoomRepository implements WishRoomRepository {
  static const _kGuideSeenKey = 'wish_room_guide_seen';

  MockWishRoomRepository({WishRoomLocalStore? localStore})
    : _localStore = localStore ?? WishRoomLocalStore();

  final WishRoomLocalStore _localStore;

  var _room = buildMockWishRoom();
  var _pouch = buildMockPouchStatus();
  final _dailyMessage = buildMockDailyMessage();
  var _catalog = buildMockCustomizeCatalog();
  bool? _isFirstVisitCache;
  bool _localStoreLoaded = false;

  /// [실 재화 연동] 소원/스트릭 등 다른 필드는 그대로 두고 복주머니
  /// 표시값(totalCount/earnedToday)만 실제 값으로 덮어써야 할 때 사용한다.
  /// [RealCurrencyWishRoomRepository]가 fetchInitialData() 이후 이 메서드로
  /// pouchStatus를 실 잔액 기준으로 다시 맞춘다.
  void overridePouchTotalCount(int realBalance) {
    _pouch = _pouch.copyWith(totalCount: realBalance);
  }

  /// [실 재화 연동] 정성 담기 시 소원/스트릭/성장치 갱신 로직은 그대로
  /// 재사용하되, 복주머니 차감은 이미 외부(LuckPouchProvider)에서 완료된
  /// 상태이므로 내부 pouch.totalCount는 건드리지 않고 usedToday만 표시용으로
  /// 늘린다.
  Future<PrayerSession> prayWithExternalPouch({
    required String wishId,
    required PrayerType type,
    required int realBalanceAfterSpend,
  }) async {
    final pouchCount = type.pouchCost;
    _pouch = _pouch.copyWith(
      totalCount: realBalanceAfterSpend,
      usedToday: _pouch.usedToday + pouchCount,
    );
    final session = _applyPrayerEffect(wishId: wishId, type: type);
    // [실 재화 연동] pouch.totalCount는 실 지갑이 유일한 진실 원천이므로
    // 여기서 캐싱하지 않는다(saveRoom만 호출 — 클래스 docstring의 "복주머니
    // 실 잔액과의 경계" 참고). 소원/성장치만 영속화하면 충분하다.
    await _localStore.saveRoom(_room);
    return session;
  }

  @override
  Future<WishRoomBundle> fetchInitialData() async {
    // 네트워크 지연 시뮬레이션(로딩 상태 확인용).
    await Future.delayed(const Duration(milliseconds: 400));
    _isFirstVisitCache ??= !(await _loadGuideSeen());
    await _loadFromLocalStoreOnce();
    return WishRoomBundle(
      room: _room,
      pouchStatus: _pouch,
      dailyMessage: _dailyMessage,
      isFirstVisit: _isFirstVisitCache!,
    );
  }

  /// [Sprint 3 로컬 영속성] 이 Repository 인스턴스의 수명 동안 최초 1회만
  /// Hive에 저장된 값을 읽어 인메모리 상태를 덮어쓴다. 이후 재호출되는
  /// `fetchInitialData()`(예: 정성 담기 후 재조회)에서는 이미 최신 인메모리
  /// 상태가 있으므로 다시 로드하지 않는다 — 그렇지 않으면 방금 반영한
  /// 변경사항이 아직 저장되지 않은 시점에 덮어써질 위험이 있다.
  Future<void> _loadFromLocalStoreOnce() async {
    if (_localStoreLoaded) return;
    _localStoreLoaded = true;

    final savedRoom = await _localStore.loadRoom();
    if (savedRoom != null) _room = savedRoom;

    final savedPouch = await _localStore.loadPouch();
    if (savedPouch != null) _pouch = savedPouch;

    final savedCatalog = await _localStore.loadCatalog();
    if (savedCatalog != null) _catalog = savedCatalog;
  }

  /// 소원방 상태가 바뀌는 모든 지점(정성 담기/소원 등록/슬롯 해금/대표
  /// 교체) 뒤에서 호출해 room+pouch를 함께 저장한다.
  Future<void> _persistRoomAndPouch() async {
    await _localStore.saveRoom(_room);
    await _localStore.savePouch(_pouch);
  }

  Future<bool> _loadGuideSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kGuideSeenKey) ?? false;
  }

  @override
  Future<WishItem> addWish({
    required String title,
    required WishCategory category,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // [슬롯 시스템] 대표 소원이 없으면 대표 슬롯(0번)에 배정하고, 있으면
    // 해금된 서브 슬롯 중 빈 자리에 배정한다. hasAvailableSlot이 false인데
    // 이 메서드가 호출되는 경우는 UI가 CTA를 막아야 하는 예외 상황이다
    // (그래도 방어적으로 서브 소원으로 등록되도록 처리).
    final isFirstWish = _room.wishes.every((w) => !w.isRepresentative);
    final newWish = WishItem(
      id: 'wish_${Random().nextInt(99999)}',
      title: title,
      category: category,
      createdAt: DateTime.now(),
      isRepresentative: isFirstWish,
    );
    _room = _room.copyWith(wishes: [..._room.wishes, newWish]);
    await _persistRoomAndPouch();
    return newWish;
  }

  @override
  Future<void> setRepresentative(
    String wishId, {
    required bool isRepresentative,
  }) async {
    _room = _room.copyWith(
      wishes: _room.wishes
          .map(
            (w) => w.id == wishId
                ? w.copyWith(isRepresentative: isRepresentative)
                : (isRepresentative ? w.copyWith(isRepresentative: false) : w),
          )
          .toList(),
    );
    await _persistRoomAndPouch();
  }

  @override
  Future<PrayerSession> prayForWish({
    required String wishId,
    required PrayerType type,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final cost = type.pouchCost;
    if (cost > 0 && _pouch.totalCount < cost) {
      throw Exception('복주머니가 부족합니다');
    }
    if (cost > 0) {
      _pouch = _pouch.copyWith(
        totalCount: _pouch.totalCount - cost,
        usedToday: _pouch.usedToday + cost,
      );
    }
    final session = _applyPrayerEffect(wishId: wishId, type: type);
    await _persistRoomAndPouch();
    return session;
  }

  /// [치성 시스템 + 소원 성장 시스템] 치성 성공 시 공통 갱신 로직 —
  /// 대상 소원의 성장 포인트/기도 횟수, 방 전체의 누적/연속 기도일수를
  /// 함께 갱신한다. 복주머니 차감은 호출측(prayForWish 또는
  /// prayWithExternalPouch)에서 이미 처리했다고 가정한다.
  PrayerSession _applyPrayerEffect({
    required String wishId,
    required PrayerType type,
  }) {
    final now = DateTime.now();
    final wasPrayedToday = _room.hasPrayedToday;
    final gain = type.growthPointGain;
    _room = _room.copyWith(
      wishes: _room.wishes
          .map(
            (w) => w.id == wishId
                ? w.copyWith(
                    lastPrayedAt: now,
                    prayerCount: w.prayerCount + 1,
                    growthPoint: w.growthPoint + gain,
                  )
                : w,
          )
          .toList(),
      totalPrayerCount: _room.totalPrayerCount + 1,
      consecutivePrayerDays: wasPrayedToday
          ? _room.consecutivePrayerDays
          : _room.consecutivePrayerDays + 1,
      lastPrayedDate: now,
      lastVisitedAt: now,
    );

    return PrayerSession(
      id: 'session_${Random().nextInt(99999)}',
      wishId: wishId,
      pouchUsed: type.pouchCost,
      prayedAt: now,
      resultMessage: '당신의 진심이 빛으로 남았어요',
    );
  }

  @override
  Future<WishRoom> unlockSubSlot({required bool viaPouch}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_room.unlockedSubSlotCount >= WishRoom.maxSubSlotCount) {
      return _room;
    }
    if (viaPouch) {
      const price = WishRoom.subSlotUnlockPouchPrice; // 정책표 ① 기준값.
      if (_pouch.totalCount < price) {
        throw Exception('복주머니가 부족합니다');
      }
      _pouch = _pouch.copyWith(totalCount: _pouch.totalCount - price);
    }
    _room = _room.copyWith(
      unlockedSubSlotCount: _room.unlockedSubSlotCount + 1,
    );
    await _persistRoomAndPouch();
    return _room;
  }

  @override
  Future<List<CustomizeItem>> fetchCustomizeCatalog() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _catalog;
  }

  @override
  Future<List<CustomizeItem>> purchaseCustomizeItem(String itemId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final item = _catalog.firstWhere((c) => c.id == itemId);
    if (item.isOwned) return _catalog;
    if (_pouch.totalCount < item.pouchPrice) {
      throw Exception('복주머니가 부족합니다');
    }
    _pouch = _pouch.copyWith(totalCount: _pouch.totalCount - item.pouchPrice);
    _catalog = _catalog
        .map((c) => c.id == itemId ? c.copyWith(isOwned: true) : c)
        .toList();
    await _localStore.saveCatalog(_catalog);
    await _persistRoomAndPouch();
    return _catalog;
  }

  /// [실 재화 연동] 실 잔액 차감은 이미 외부(LuckPouchProvider)에서 완료된
  /// 상태이므로, 이 mock 내부에서는 가격을 재차감하지 않고 소유 플래그만
  /// true로 세팅한다. [RealCurrencyWishRoomRepository.purchaseCustomizeItem]
  /// 전용 진입점이다.
  Future<List<CustomizeItem>> markOwnedExternally(String itemId) async {
    _catalog = _catalog
        .map((c) => c.id == itemId ? c.copyWith(isOwned: true) : c)
        .toList();
    await _localStore.saveCatalog(_catalog);
    return _catalog;
  }

  @override
  Future<List<CustomizeItem>> applyCustomizeItem(String itemId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final target = _catalog.firstWhere((c) => c.id == itemId);
    if (!target.isOwned) {
      throw Exception('아직 보유하지 않은 아이템입니다');
    }
    if (target.category.allowsMultiple) {
      // 장식류는 다중 적용 허용 — 대상만 토글.
      _catalog = _catalog
          .map((c) => c.id == itemId ? c.copyWith(isApplied: !c.isApplied) : c)
          .toList();
    } else {
      // 나머지 카테고리는 단일 선택 — 같은 카테고리 내 다른 적용 아이템 해제.
      _catalog = _catalog.map((c) {
        if (c.category != target.category) return c;
        return c.copyWith(isApplied: c.id == itemId);
      }).toList();
    }
    await _localStore.saveCatalog(_catalog);
    return _catalog;
  }

  @override
  Future<void> markGuideSeen() async {
    _isFirstVisitCache = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuideSeenKey, true);
  }

  /// [소원 깨우기] Mock 환경에는 서버의 실제 감쇠(decay) 스케줄러가 없으므로
  /// "감쇠가 실제로 발생했는지"를 [WishItem.isWeak](growthPoint가
  /// maxEnergy의 30% 미만)로 근사 판정한다. 서버 `wish-room/wake` 라우트의
  /// `NOTHING_TO_WAKE`(감쇠 없음 → null 반환) 계약과 동일한 모양을 맞추기
  /// 위함 — 대표 소원이 이미 충분히 밝다면(30% 이상) 깨울 필요가 없다고
  /// 보고 null을 반환하고, 약해진 상태라면 소량 회복시키고 세션을 반환한다.
  @override
  Future<PrayerSession?> wakeWish(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    WishItem? target;
    for (final w in _room.wishes) {
      if (w.id == wishId) target = w;
    }
    if (target == null) return null;
    if (!target.isWeak) return null; // 서버의 NOTHING_TO_WAKE와 동일한 의미.

    const gain = 20; // 서버 wish_room_wake_energy_gain 기본값과 동일.
    const reward = 2; // 서버 wish_room_wake 보상 기본값과 동일.
    final now = DateTime.now();
    _room = _room.copyWith(
      wishes: _room.wishes
          .map(
            (w) => w.id == wishId
                ? w.copyWith(growthPoint: w.growthPoint + gain)
                : w,
          )
          .toList(),
    );
    _pouch = _pouch.copyWith(totalCount: _pouch.totalCount + reward);
    await _persistRoomAndPouch();
    return PrayerSession(
      id: 'wake_${Random().nextInt(99999)}',
      wishId: wishId,
      pouchUsed: 0,
      prayedAt: now,
      resultMessage: '소원이 다시 밝게 빛나요 (+$reward 복주머니)',
    );
  }

  /// [가이드 슬라이드] 서버가 없는 Mock 단계에서는 합리적인 기본 5단계
  /// 안내를 그대로 반환한다(기존 [WishGuideDialog]가 하드코딩하던 5단계
  /// 문구를 이 위치로 옮겨온 것 — 실 서버 연동 시에는
  /// [HttpWishRoomRepository]가 관리자 CMS 원본을 반환하므로 이 목록은
  /// 쓰이지 않는다).
  @override
  Future<List<GuideSlide>> fetchGuideSlides() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      GuideSlide(title: '1. 입장하기', body: '조용히 문을 열고 당신만의 소원방에 들어와요'),
      GuideSlide(title: '2. 소원 정하기', body: '직접 적거나, 추천 카테고리 중 하나를 골라보세요'),
      GuideSlide(title: '3. 정성 담기', body: '복주머니로 소원에 마음을 담아보세요'),
      GuideSlide(title: '4. 매일 기도하기', body: '하루 한 번, 오늘의 정성을 이어가요'),
      GuideSlide(title: '5. 소원 확인하기', body: '쌓여가는 기도의 기록을 언제든 돌아볼 수 있어요'),
    ];
  }
}
