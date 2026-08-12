import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/wish_room_models.dart';

/// 신통방통 소원방 · 전역 상태 Provider
///
/// 절대 원칙 준수:
///  - 결제 관련 메서드/필드 없음
///  - 조각 획득은 오직 [earn]류 메서드(활동/광고)로만 발생
///  - 조각 사용은 오직 [spend]류 메서드로만 발생, 잔액 부족 시 결제 대신
///    [WishRoomShortageException]을 던져 상위에서 ShortageDialog로 유도
///
/// 로컬 영속성은 Hive box 'wish_room'(Map 기반, 코드생성 어댑터 불필요)를 사용한다.
class WishRoomShortageException implements Exception {
  WishRoomShortageException({required this.need, required this.have, required this.itemName});
  final int need;
  final int have;
  final String itemName;
}

class WishRoomProvider extends ChangeNotifier {
  static const _boxName = 'wish_room';

  Box? _box;
  bool _ready = false;
  bool get ready => _ready;

  // ── AppState.user ──
  String userId = 'local_user';
  String handle = '@나의소원';
  bool onboarded = false;
  WishRoomThemeId theme = WishRoomThemeId.crystal;

  // ── AppState.pouch ──
  int balance = 0;
  int todayEarned = 0;
  WishRoomTodayLimits todayLimits = WishRoomTodayLimits.empty(_todayKey());
  WishRoomInventory inventory = WishRoomInventory();

  // ── AppState.wishes / ledger / event ──
  final List<WishRoomWish> wishes = [];
  final List<WishRoomLedgerEntry> ledger = [];
  bool fullMoonActive = false;

  // 최근 획득/사용 이벤트(EarnMoment/토스트 트리거용, 1회성 소비)
  WishRoomEarnResult? lastEarnResult;

  static String _todayKey([DateTime? d]) {
    final now = d ?? DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox(_boxName);
    _load();
    _ready = true;
    notifyListeners();
  }

  void _load() {
    final b = _box!;
    userId = b.get('userId', defaultValue: 'local_user') as String;
    handle = b.get('handle', defaultValue: '@나의소원') as String;
    onboarded = b.get('onboarded', defaultValue: false) as bool;
    theme = WishRoomThemeIdX.fromKey(b.get('theme') as String?);
    balance = (b.get('balance', defaultValue: 0) as num).toInt();
    todayEarned = (b.get('todayEarned', defaultValue: 0) as num).toInt();

    final todayKey = _todayKey();
    todayLimits = WishRoomTodayLimits.fromMap(
      b.get('todayLimits') as Map?,
      todayKey,
    );
    if (todayLimits.resetDateKey != todayKey) {
      // 자정 리셋
      todayLimits = WishRoomTodayLimits.empty(todayKey);
      todayEarned = 0;
    }

    inventory = WishRoomInventory.fromMap(b.get('inventory') as Map?);
    fullMoonActive = b.get('fullMoonActive', defaultValue: false) as bool;

    final wishMaps = (b.get('wishes') as List?) ?? [];
    wishes
      ..clear()
      ..addAll(wishMaps.map((e) => WishRoomWish.fromMap(e as Map)));

    final ledgerMaps = (b.get('ledger') as List?) ?? [];
    ledger
      ..clear()
      ..addAll(ledgerMaps.map((e) => WishRoomLedgerEntry.fromMap(e as Map)));
  }

  Future<void> _persist() async {
    final b = _box;
    if (b == null) return;
    await b.putAll({
      'userId': userId,
      'handle': handle,
      'onboarded': onboarded,
      'theme': theme.key,
      'balance': balance,
      'todayEarned': todayEarned,
      'todayLimits': todayLimits.toMap(),
      'inventory': inventory.toMap(),
      'fullMoonActive': fullMoonActive,
      'wishes': wishes.map((w) => w.toMap()).toList(),
      'ledger': ledger.map((l) => l.toMap()).toList(),
    });
  }

  // ─────────────────────────────────────────────────────────
  // 온보딩 / 팔레트
  // ─────────────────────────────────────────────────────────
  Future<void> completeOnboarding() async {
    onboarded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> setTheme(WishRoomThemeId next) async {
    theme = next;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // 조각 획득 (Earn) — dev-spec.md §5.2 EarnEvent
  // ─────────────────────────────────────────────────────────
  int _multiplier() => fullMoonActive ? 2 : 1;

  Future<WishRoomEarnResult?> earnAttendance() async {
    if (todayLimits.attendance) return null;
    todayLimits.attendance = true;
    return _applyEarn(1 * _multiplier(), '오늘도 촛불을 밝히다', '출석');
  }

  Future<WishRoomEarnResult?> earnMeditation() async {
    if (todayLimits.meditation) return null;
    todayLimits.meditation = true;
    return _applyEarn(2 * _multiplier(), '60초 명상을 마치다', '명상');
  }

  Future<WishRoomEarnResult?> earnCheer(String wishId) async {
    if (todayLimits.cheerCount >= WishRoomTodayLimits.cheerDailyLimit) return null;
    todayLimits.cheerCount += 1;
    final wish = _findWish(wishId);
    wish?.cheersReceived += 1;
    return _applyEarn(1 * _multiplier(), '다른 이 소원에 함께 빌다', '함께 빌기');
  }

  Future<WishRoomEarnResult> earnCompose(String wishId) async {
    return _applyEarn(5 * _multiplier(), '새 소원을 봉인하다', '소원 봉인');
  }

  Future<WishRoomEarnResult> earnInvite(String inviteeId) async {
    return _applyEarn(20 * _multiplier(), '소원방을 벗에게 소개하다', '초대');
  }

  Future<WishRoomEarnResult?> earnDay100(String wishId) async {
    final wish = _findWish(wishId);
    if (wish == null || wish.day100Rewarded || wish.daysLit < 100) return null;
    wish.day100Rewarded = true;
    return _applyEarn(30 * _multiplier(), '소원을 100일 지키다', '100일 지킴');
  }

  Future<WishRoomEarnResult> earnFulfilled(String wishId) async {
    final wish = _findWish(wishId);
    wish?.fulfilledAt = DateTime.now();
    return _applyEarn(50 * _multiplier(), '소원이 이루어지다', '成');
  }

  Future<WishRoomEarnResult?> earnAdWatched({int amount = 5}) async {
    if (todayLimits.adCount >= WishRoomTodayLimits.adDailyLimit) return null;
    todayLimits.adCount += 1;
    return _applyEarn(amount * _multiplier(), '광고를 조용히 지켜보다', '광고 시청');
  }

  Future<WishRoomEarnResult> _applyEarn(int amount, String label, String sub) async {
    balance += amount;
    todayEarned += amount;
    final entry = WishRoomLedgerEntry(
      id: _genId(),
      label: label,
      sub: sub,
      amount: amount,
      date: DateTime.now(),
    );
    ledger.insert(0, entry);
    final result = WishRoomEarnResult(amount: amount, newBalance: balance, label: label);
    lastEarnResult = result;
    await _persist();
    notifyListeners();
    return result;
  }

  // ─────────────────────────────────────────────────────────
  // 조각 사용 (Spend) — dev-spec.md §5.2 SpendEvent
  // 잔액 부족 시 결제 유도 없이 WishRoomShortageException을 던진다.
  // ─────────────────────────────────────────────────────────
  Future<void> buySeal(String sealId) => _spendCatalog(
        WishRoomCatalog.seals,
        sealId,
        (id) => inventory.seals.add(id),
        '인장을 봉인하다',
      );

  Future<void> buyCandle(String candleId) => _spendCatalog(
        WishRoomCatalog.candles,
        candleId,
        (id) => inventory.candles.add(id),
        '촛불을 밝히다',
      );

  Future<void> buyTheme(String themeId) => _spendCatalog(
        WishRoomCatalog.themes,
        themeId,
        (id) => inventory.themes.add(id),
        '테마를 담다',
      );

  Future<void> buyTalisman(String talismanId, {required Duration validFor}) async {
    final item = WishRoomCatalog.talismans.firstWhere((e) => e.id == talismanId);
    _ensureBalance(item.cost, item.name);
    balance -= item.cost;
    inventory.talismans.add(WishRoomTalisman(id: talismanId, expiresAt: DateTime.now().add(validFor)));
    await _recordSpend(item.cost, '부적을 지니다', item.name);
  }

  Future<void> giftShards({required String wishId, required int amount, String? message}) async {
    _ensureBalance(amount, '조각 나눔');
    balance -= amount;
    final wish = _findWish(wishId);
    wish?.shardsPledged += amount;
    await _recordSpend(amount, '벗의 소원에 복을 얹다', '나눔');
  }

  Future<void> _spendCatalog(
    List<WishRoomCatalogItem> list,
    String id,
    void Function(String) addToInventory,
    String label,
  ) async {
    final item = list.firstWhere((e) => e.id == id);
    if (inventory.owns(id)) return; // 이미 보유 — 조용히 무시
    _ensureBalance(item.cost, item.name);
    balance -= item.cost;
    addToInventory(id);
    await _recordSpend(item.cost, label, item.name);
  }

  void _ensureBalance(int cost, String itemName) {
    if (balance < cost) {
      throw WishRoomShortageException(need: cost, have: balance, itemName: itemName);
    }
  }

  Future<void> _recordSpend(int cost, String label, String sub) async {
    final entry = WishRoomLedgerEntry(
      id: _genId(),
      label: label,
      sub: sub,
      amount: -cost,
      date: DateTime.now(),
    );
    ledger.insert(0, entry);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // 소원 CRUD
  // ─────────────────────────────────────────────────────────
  Future<WishRoomWish> addWish({
    required String text,
    String seal = '願',
    int intensity = 3,
    String? region,
    String? ageGroup,
  }) async {
    final wish = WishRoomWish(
      id: _genId(),
      ownerId: userId,
      text: text,
      seal: seal,
      createdAt: DateTime.now(),
      intensity: intensity,
      region: region,
      ageGroup: ageGroup,
    );
    wishes.insert(0, wish);
    await earnCompose(wish.id);
    await _persist();
    notifyListeners();
    return wish;
  }

  WishRoomWish? _findWish(String id) {
    for (final w in wishes) {
      if (w.id == id) return w;
    }
    return null;
  }

  WishRoomWish? findWish(String id) => _findWish(id);

  Future<void> markFulfilled(String wishId) async {
    await earnFulfilled(wishId);
    await _persist();
    notifyListeners();
  }

  static String _genId() {
    final rnd = math.Random();
    return '${DateTime.now().microsecondsSinceEpoch}_${rnd.nextInt(99999)}';
  }

  // 오늘의 미션 뷰 모델(EarnList 화면에서 그대로 사용)
  List<WishRoomMissionViewData> get todayMissions => [
        WishRoomMissionViewData(
          label: '오늘도 촛불을 밝히다',
          sub: '출석',
          reward: 1 * _multiplier(),
          done: todayLimits.attendance,
          onClaim: earnAttendance,
        ),
        WishRoomMissionViewData(
          label: '60초 명상 · 심호흡',
          sub: '명상',
          reward: 2 * _multiplier(),
          done: todayLimits.meditation,
          onClaim: earnMeditation,
        ),
        WishRoomMissionViewData(
          label: '다른 이 소원에 함께 빌다',
          sub: '함께 빌기 · ${todayLimits.cheerCount}/${WishRoomTodayLimits.cheerDailyLimit}',
          reward: 1 * _multiplier(),
          done: todayLimits.cheerCount >= WishRoomTodayLimits.cheerDailyLimit,
          onClaim: null, // 개별 소원 화면에서 wishId와 함께 호출
        ),
        WishRoomMissionViewData(
          label: '광고를 조용히 지켜보다',
          sub: '광고 시청 · ${todayLimits.adCount}/${WishRoomTodayLimits.adDailyLimit}',
          reward: 5 * _multiplier(),
          done: todayLimits.adCount >= WishRoomTodayLimits.adDailyLimit,
          onClaim: () => earnAdWatched(),
        ),
      ];
}

class WishRoomMissionViewData {
  const WishRoomMissionViewData({
    required this.label,
    required this.sub,
    required this.reward,
    required this.done,
    this.onClaim,
  });

  final String label;
  final String sub;
  final int reward;
  final bool done;
  final Future<WishRoomEarnResult?> Function()? onClaim;
}
