import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../domain/enums/customize_category.dart';
import '../models/customize_item_model.dart';
import '../models/fortune_pouch_status_model.dart';
import '../models/wish_item_model.dart';
import '../models/wish_room_model.dart';

/// [Sprint 3 로컬 영속성] 소원방 상태(소원 목록/성장치/복주머니 표시값/
/// 꾸미기 카탈로그)를 기기에 저장해 앱 재시작 후에도 유지되도록 하는
/// 저장소.
///
/// [설계 결정: 코드 생성 없이 Map 직렬화] `hive_generator`/`build_runner`를
/// 새로 추가하지 않기 위해 `HiveObject` 서브클래싱 대신 `Map<String,
/// dynamic>` 수동 직렬화 방식을 쓴다. Hive는 Map/List/String/int/double/
/// bool을 어댑터 없이 그대로 지원하므로(DateTime은 ISO8601 문자열로 변환해
/// 저장) 이 방식으로 충분하고, 프로젝트에 새 빌드 스텝을 추가하지 않아도
/// 된다.
///
/// [설계 결정: 방어적 실패 처리] 이 클래스의 모든 메서드는 Hive
/// 미초기화(예: `Hive.initFlutter()`를 호출하지 않는 단위 테스트 환경) 또는
/// 디스크 I/O 오류 상황에서 예외를 삼키고 null(읽기) 또는 조용한 무동작
/// (쓰기)으로 처리한다. 그 결과:
///   1. 기존 Sprint 1/2 단위 테스트들은 Hive를 전혀 초기화하지 않았음에도
///      아무 코드 변경 없이 계속 통과한다(인메모리 기본값으로 자동 폴백).
///   2. 실제 기기에서 디스크 오류가 발생해도 앱이 크래시하지 않고 "이번
///      세션만 저장 안 됨" 정도로 저하되고 넘어간다.
///
/// [설계 결정: 복주머니 실 잔액과의 경계] `RealCurrencyWishRoomRepository`
/// 사용 시 복주머니 총량의 진실 원천은 `LuckPouchProvider`(WalletProvider)
/// 이며, 이 저장소가 캐싱하는 `FortunePouchStatus.totalCount`는 그 값을
/// 화면 표시용으로 매 fetchInitialData() 시점에 덮어쓰는 파생값일 뿐이다.
/// 따라서 `MockWishRoomRepository.overridePouchTotalCount()`(실 잔액 동기화
/// 전용 메서드)는 이 저장소에 쓰지 않는다 — 실 지갑 잔액과 Hive 캐시가
/// 서로 다른 값을 주장하며 충돌하는 상황을 원천적으로 막기 위함이다.
class WishRoomLocalStore {
  static const _boxName = 'wish_room_box';
  static const _roomKey = 'room';
  static const _pouchKey = 'pouch';
  static const _catalogKey = 'catalog';

  /// [방어적 실패 처리, 정적(static) 스위치] `Hive.initFlutter()`가 호출되지
  /// 않은 환경(단위 테스트, 또는 초기화 전 극초반 프레임)에서 `Hive.openBox`를
  /// 호출하면 항상 동일한 `HiveError`가 던져진다. 이 실패를 최초 1회만
  /// try/catch로 흡수하고 이후에는 `_openBoxSafely`를 재호출조차 하지 않도록
  /// 이 플래그로 완전히 차단한다.
  ///
  /// 이렇게 하는 이유는 단순히 "느려서"가 아니라, `package:hive`가 동일한
  /// box 이름에 대해 동시에 여러 `openBox()` 호출이 들어오면 내부적으로
  /// Future/Completer를 공유하는데, 실패가 반복되는 과정에서 우리 쪽
  /// try/catch가 감싸지 못하는 타이밍에 "테스트 종료 후 처리되지 않은
  /// 예외"로 새어나가는 현상이 관찰됐다(Flutter test 프레임워크가 이를
  /// 잡아 테스트 실패로 표시). 최초 실패 이후 재시도를 원천적으로 막으면
  /// 이 경쟁 상태 자체가 발생하지 않는다.
  static bool _disabledAfterFirstFailure = false;

  /// [race condition 수정] 여러 곳(addWish/prayForWish/setRepresentative
  /// 등)에서 거의 동시에 `_openBoxSafely()`가 호출되면, 각 호출이 독립적으로
  /// `Hive.openBox()`를 시도하다가 실패 처리 타이밍이 서로 겹쳐 "테스트 종료
  /// 후 처리되지 않은 예외"로 새어나가는 현상이 있었다. 이를 근본적으로
  /// 막기 위해 진행 중인 open 시도의 Future 자체를 캐싱해, 동시 호출이
  /// 모두 "같은 하나의 Future"를 기다리도록 한다 — 이러면 try/catch가 정확히
  /// 한 번만 실행되고, 그 결과(성공 Box 또는 null)를 모든 호출자가 공유해서
  /// 받는다.
  static Future<Box?>? _cachedOpenFuture;

  Future<Box?> _openBoxSafely() async {
    if (_disabledAfterFirstFailure) return null;
    _cachedOpenFuture ??= _tryOpenBox();
    return _cachedOpenFuture;
  }

  Future<Box?> _tryOpenBox() async {
    try {
      if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
      return await Hive.openBox(_boxName);
    } catch (e) {
      _disabledAfterFirstFailure = true;
      if (kDebugMode) {
        debugPrint(
          '[WishRoomLocalStore] Hive box open failed, disabling local '
          'persistence for the rest of this process: $e',
        );
      }
      return null;
    }
  }

  /// [테스트 전용] static 캐시(성공/실패 플래그, 진행 중 Future)를
  /// 초기화한다. 여러 테스트 파일이 순서대로 실행되면서 이전 테스트의
  /// "Hive 미초기화로 인한 비활성화" 상태가 static 필드에 남아 다음 테스트
  /// (예: 실제 Hive.init()으로 초기화한 persistence 테스트)에 영향을 주는
  /// 것을 막기 위함이다.
  @visibleForTesting
  static void resetStaticStateForTest() {
    _disabledAfterFirstFailure = false;
    _cachedOpenFuture = null;
  }

  /// [테스트 전용] 저장된 box 파일 자체를 디스크에서 삭제하고 static 캐시도
  /// 초기화한다.
  ///
  /// [배경] `test/flutter_test_config.dart`가 진짜 Hive(`Hive.init`)를
  /// 초기화하게 되면서, 같은 테스트 파일 안의 여러 테스트가 동일한
  /// `wish_room_box`를 공유하는 문제가 드러났다 — 예를 들어 A 테스트에서
  /// `MockWishRoomRepository`가 소원에 정성을 담아 복주머니를 소비하면 그
  /// 값이 Hive에 저장되고, 곧이어 실행되는 B 테스트가 새 Repository
  /// 인스턴스를 만들어도 `_loadFromLocalStoreOnce()`가 A가 남긴 값을 그대로
  /// 읽어와 "완전히 새로운 mock 상태"를 기대하는 B 테스트를 오염시킨다.
  /// 각 테스트의 `setUp`에서 이 메서드를 호출해 매 테스트마다 깨끗한
  /// 상태로 시작하도록 한다.
  @visibleForTesting
  static Future<void> resetForTest() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        await Hive.box(_boxName).close();
      }
      await Hive.deleteBoxFromDisk(_boxName);
    } catch (_) {
      // 아직 파일이 없거나(최초 테스트) Hive가 초기화되지 않은 예외 상황은
      // 무시한다 — 어차피 목표는 "깨끗한 상태 보장"이므로 삭제할 대상이
      // 없으면 이미 목표를 달성한 것과 같다.
    }
    resetStaticStateForTest();
  }

  Future<void> saveRoom(WishRoom room) async {
    final box = await _openBoxSafely();
    if (box == null) return;
    try {
      await box.put(_roomKey, _roomToMap(room));
    } catch (e) {
      if (kDebugMode) debugPrint('[WishRoomLocalStore] saveRoom failed: $e');
    }
  }

  Future<WishRoom?> loadRoom() async {
    final box = await _openBoxSafely();
    if (box == null) return null;
    try {
      final raw = box.get(_roomKey);
      if (raw == null) return null;
      return _roomFromMap(Map<String, dynamic>.from(raw as Map));
    } catch (e) {
      if (kDebugMode) debugPrint('[WishRoomLocalStore] loadRoom failed: $e');
      return null;
    }
  }

  Future<void> savePouch(FortunePouchStatus pouch) async {
    final box = await _openBoxSafely();
    if (box == null) return;
    try {
      await box.put(_pouchKey, _pouchToMap(pouch));
    } catch (e) {
      if (kDebugMode) debugPrint('[WishRoomLocalStore] savePouch failed: $e');
    }
  }

  Future<FortunePouchStatus?> loadPouch() async {
    final box = await _openBoxSafely();
    if (box == null) return null;
    try {
      final raw = box.get(_pouchKey);
      if (raw == null) return null;
      return _pouchFromMap(Map<String, dynamic>.from(raw as Map));
    } catch (e) {
      if (kDebugMode) debugPrint('[WishRoomLocalStore] loadPouch failed: $e');
      return null;
    }
  }

  Future<void> saveCatalog(List<CustomizeItem> catalog) async {
    final box = await _openBoxSafely();
    if (box == null) return;
    try {
      await box.put(_catalogKey, catalog.map(_customizeToMap).toList());
    } catch (e) {
      if (kDebugMode) debugPrint('[WishRoomLocalStore] saveCatalog failed: $e');
    }
  }

  Future<List<CustomizeItem>?> loadCatalog() async {
    final box = await _openBoxSafely();
    if (box == null) return null;
    try {
      final raw = box.get(_catalogKey);
      if (raw == null) return null;
      final list = raw as List;
      return list
          .map((e) => _customizeFromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[WishRoomLocalStore] loadCatalog failed: $e');
      return null;
    }
  }

  /// [테스트/디버그 전용] 저장된 데이터를 모두 삭제한다.
  Future<void> clearAll() async {
    final box = await _openBoxSafely();
    if (box == null) return;
    try {
      await box.clear();
    } catch (_) {
      // 삭제 실패는 무시 — 디버그 편의 기능이므로 실패해도 앱 동작에
      // 영향을 주지 않아야 한다.
    }
  }

  // ── 직렬화 헬퍼 (Map <-> 모델, 어댑터 코드 생성 없이 수동 변환) ──

  Map<String, dynamic> _roomToMap(WishRoom room) => {
    'userId': room.userId,
    'wishes': room.wishes.map(_wishToMap).toList(),
    'totalPrayerCount': room.totalPrayerCount,
    'consecutivePrayerDays': room.consecutivePrayerDays,
    'lastVisitedAt': room.lastVisitedAt?.toIso8601String(),
    'lastPrayedDate': room.lastPrayedDate?.toIso8601String(),
    'unlockedSubSlotCount': room.unlockedSubSlotCount,
  };

  WishRoom _roomFromMap(Map<String, dynamic> map) => WishRoom(
    userId: map['userId'] as String,
    wishes: (map['wishes'] as List)
        .map((e) => _wishFromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    totalPrayerCount: map['totalPrayerCount'] as int,
    consecutivePrayerDays: map['consecutivePrayerDays'] as int,
    lastVisitedAt: map['lastVisitedAt'] != null
        ? DateTime.parse(map['lastVisitedAt'] as String)
        : null,
    lastPrayedDate: map['lastPrayedDate'] != null
        ? DateTime.parse(map['lastPrayedDate'] as String)
        : null,
    unlockedSubSlotCount: map['unlockedSubSlotCount'] as int,
  );

  Map<String, dynamic> _wishToMap(WishItem w) => {
    'id': w.id,
    'title': w.title,
    'category': w.category.name,
    'createdAt': w.createdAt.toIso8601String(),
    'lastPrayedAt': w.lastPrayedAt?.toIso8601String(),
    'prayerCount': w.prayerCount,
    'isRepresentative': w.isRepresentative,
    'growthPoint': w.growthPoint,
  };

  WishItem _wishFromMap(Map<String, dynamic> map) => WishItem(
    id: map['id'] as String,
    title: map['title'] as String,
    category: WishCategory.values.byName(map['category'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
    lastPrayedAt: map['lastPrayedAt'] != null
        ? DateTime.parse(map['lastPrayedAt'] as String)
        : null,
    prayerCount: map['prayerCount'] as int,
    isRepresentative: map['isRepresentative'] as bool,
    growthPoint: map['growthPoint'] as int,
  );

  Map<String, dynamic> _pouchToMap(FortunePouchStatus p) => {
    'totalCount': p.totalCount,
    'usedToday': p.usedToday,
    'earnedToday': p.earnedToday,
    'dailyFreeQuota': p.dailyFreeQuota,
  };

  FortunePouchStatus _pouchFromMap(Map<String, dynamic> map) =>
      FortunePouchStatus(
        totalCount: map['totalCount'] as int,
        usedToday: map['usedToday'] as int,
        earnedToday: map['earnedToday'] as int,
        dailyFreeQuota: map['dailyFreeQuota'] as int,
      );

  Map<String, dynamic> _customizeToMap(CustomizeItem c) => {
    'id': c.id,
    'name': c.name,
    'category': c.category.name,
    'unlockType': c.unlockType.name,
    'previewEmoji': c.previewEmoji,
    'pouchPrice': c.pouchPrice,
    'unlockThreshold': c.unlockThreshold,
    'isOwned': c.isOwned,
    'isApplied': c.isApplied,
  };

  CustomizeItem _customizeFromMap(Map<String, dynamic> map) => CustomizeItem(
    id: map['id'] as String,
    name: map['name'] as String,
    category: CustomizeCategory.values.byName(map['category'] as String),
    unlockType: CustomizeUnlockType.values.byName(map['unlockType'] as String),
    previewEmoji: map['previewEmoji'] as String,
    pouchPrice: map['pouchPrice'] as int,
    unlockThreshold: map['unlockThreshold'] as int?,
    isOwned: map['isOwned'] as bool,
    isApplied: map['isApplied'] as bool,
  );
}
