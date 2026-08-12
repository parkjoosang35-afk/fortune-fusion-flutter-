import 'package:flutter/foundation.dart';

/// 신통방통 소원방 · 도메인 모델
///
/// 출처: 디자인 핸드오프 `handoff/dev-spec.md` §5 (AppState / Wish / EarnEvent / SpendEvent).
/// Hive에는 TypeAdapter 코드생성 없이 Map<String, dynamic> 형태로 저장한다
/// (Hive는 Map/List/기본타입을 어댑터 없이 네이티브로 지원함).

/// ─────────────────────────────────────────────────────────
/// 팔레트 (3종) — 사용자가 선택 가능한 소원방 테마
/// ─────────────────────────────────────────────────────────
enum WishRoomThemeId { midnight, hanji, crystal }

extension WishRoomThemeIdX on WishRoomThemeId {
  String get key => switch (this) {
        WishRoomThemeId.midnight => 'midnight',
        WishRoomThemeId.hanji => 'hanji',
        WishRoomThemeId.crystal => 'crystal',
      };

  static WishRoomThemeId fromKey(String? key) => switch (key) {
        'hanji' => WishRoomThemeId.hanji,
        'crystal' => WishRoomThemeId.crystal,
        _ => WishRoomThemeId.midnight,
      };
}

/// ─────────────────────────────────────────────────────────
/// 인장 5종 / 촛불 4종 / 부적 2종 — 카탈로그 고정 데이터
/// (dev-spec/README §사용(Spend) 표 기준)
/// ─────────────────────────────────────────────────────────
class WishRoomCatalogItem {
  const WishRoomCatalogItem({
    required this.id,
    required this.name,
    required this.sub,
    required this.cost,
  });

  final String id;
  final String name;
  final String sub;
  final int cost;
}

class WishRoomCatalog {
  WishRoomCatalog._();

  static const seals = [
    WishRoomCatalogItem(id: 'seal_ok', name: '玉', sub: '귀한 소원', cost: 30),
    WishRoomCatalogItem(id: 'seal_geum', name: '金', sub: '가장 간절한 소원', cost: 60),
    WishRoomCatalogItem(id: 'seal_eun', name: '銀', sub: '조용한 지킴', cost: 40),
    WishRoomCatalogItem(id: 'seal_gwi', name: '龜', sub: '오래 살기를', cost: 50),
    WishRoomCatalogItem(id: 'seal_hak', name: '鶴', sub: '평안 · 장수', cost: 50),
  ];

  static const candles = [
    WishRoomCatalogItem(id: 'candle_lotus', name: '연꽃초', sub: '자비 · 이별한 사람을 위해', cost: 40),
    WishRoomCatalogItem(id: 'candle_star', name: '별초', sub: '밤하늘로 소원이 흩어짐', cost: 80),
    WishRoomCatalogItem(id: 'candle_sandal', name: '향초', sub: '명상 시간 배수 획득', cost: 60),
    WishRoomCatalogItem(id: 'candle_wax_star', name: '촛농이 별이 되는 초', sub: '이뤄진 소원의 촛농이 별로', cost: 100),
  ];

  static const themes = [
    WishRoomCatalogItem(id: 'theme_midnight', name: '심야의 신전', sub: '기본 · 자주 보랏빛', cost: 0),
    WishRoomCatalogItem(id: 'theme_hanji', name: '새벽 한지', sub: '따뜻한 라이트 톤', cost: 50),
    WishRoomCatalogItem(id: 'theme_crystal', name: '달빛 크리스탈', sub: '복주머니 기본 팔레트', cost: 0),
  ];

  static const talismans = [
    WishRoomCatalogItem(id: 'talisman_100day', name: '소원 부적', sub: '매일 자동 촛불 켜기 · 100일', cost: 100),
    WishRoomCatalogItem(id: 'talisman_fullmoon', name: '만월 부적', sub: '다음 보름달까지 항상 ×2', cost: 60),
  ];

  static WishRoomCatalogItem? find(String id) {
    for (final list in [seals, candles, themes, talismans]) {
      for (final item in list) {
        if (item.id == id) return item;
      }
    }
    return null;
  }
}

/// ─────────────────────────────────────────────────────────
/// 오늘의 일일 한도 카운터
/// ─────────────────────────────────────────────────────────
class WishRoomTodayLimits {
  WishRoomTodayLimits({
    this.attendance = false,
    this.meditation = false,
    this.cheerCount = 0,
    this.adCount = 0,
    this.fullMoonClaimed = false,
    required this.resetDateKey,
  });

  bool attendance;
  bool meditation;
  int cheerCount;
  int adCount;
  bool fullMoonClaimed;

  /// yyyy-MM-dd — 이 값이 오늘과 다르면 자정 리셋 대상
  String resetDateKey;

  static const cheerDailyLimit = 5;
  static const adDailyLimit = 5;

  Map<String, dynamic> toMap() => {
        'attendance': attendance,
        'meditation': meditation,
        'cheerCount': cheerCount,
        'adCount': adCount,
        'fullMoonClaimed': fullMoonClaimed,
        'resetDateKey': resetDateKey,
      };

  factory WishRoomTodayLimits.fromMap(Map<dynamic, dynamic>? map, String todayKey) {
    if (map == null) {
      return WishRoomTodayLimits(resetDateKey: todayKey);
    }
    return WishRoomTodayLimits(
      attendance: map['attendance'] as bool? ?? false,
      meditation: map['meditation'] as bool? ?? false,
      cheerCount: (map['cheerCount'] as num?)?.toInt() ?? 0,
      adCount: (map['adCount'] as num?)?.toInt() ?? 0,
      fullMoonClaimed: map['fullMoonClaimed'] as bool? ?? false,
      resetDateKey: map['resetDateKey'] as String? ?? todayKey,
    );
  }

  factory WishRoomTodayLimits.empty(String todayKey) => WishRoomTodayLimits(resetDateKey: todayKey);
}

/// ─────────────────────────────────────────────────────────
/// 인벤토리(보유 인장/촛불/테마/부적)
/// ─────────────────────────────────────────────────────────
class WishRoomInventory {
  WishRoomInventory({
    List<String>? seals,
    List<String>? candles,
    List<String>? themes,
    List<WishRoomTalisman>? talismans,
  })  : seals = seals ?? <String>[],
        candles = candles ?? <String>[],
        themes = themes ?? <String>['theme_midnight', 'theme_crystal'],
        talismans = talismans ?? <WishRoomTalisman>[];

  final List<String> seals;
  final List<String> candles;
  final List<String> themes;
  final List<WishRoomTalisman> talismans;

  bool owns(String catalogId) =>
      seals.contains(catalogId) ||
      candles.contains(catalogId) ||
      themes.contains(catalogId) ||
      talismans.any((t) => t.id == catalogId);

  Map<String, dynamic> toMap() => {
        'seals': seals,
        'candles': candles,
        'themes': themes,
        'talismans': talismans.map((t) => t.toMap()).toList(),
      };

  factory WishRoomInventory.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return WishRoomInventory();
    return WishRoomInventory(
      seals: (map['seals'] as List?)?.map((e) => e.toString()).toList() ?? [],
      candles: (map['candles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      themes: (map['themes'] as List?)?.map((e) => e.toString()).toList() ??
          ['theme_midnight', 'theme_crystal'],
      talismans: (map['talismans'] as List?)
              ?.map((e) => WishRoomTalisman.fromMap(e as Map))
              .toList() ??
          [],
    );
  }
}

class WishRoomTalisman {
  const WishRoomTalisman({required this.id, required this.expiresAt});
  final String id;
  final DateTime expiresAt;

  bool get isActive => DateTime.now().isBefore(expiresAt);

  Map<String, dynamic> toMap() => {
        'id': id,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory WishRoomTalisman.fromMap(Map map) => WishRoomTalisman(
        id: map['id'] as String,
        expiresAt: DateTime.parse(map['expiresAt'] as String),
      );
}

/// ─────────────────────────────────────────────────────────
/// 소원 (Wish)
/// ─────────────────────────────────────────────────────────
class WishRoomWish {
  WishRoomWish({
    required this.id,
    required this.ownerId,
    required this.text,
    required this.seal,
    required this.createdAt,
    this.intensity = 3,
    this.cheersReceived = 0,
    this.shardsPledged = 0,
    this.fulfilledAt,
    this.region,
    this.ageGroup,
    this.day100Rewarded = false,
  });

  final String id;
  final String ownerId;
  String text; // 최대 140자
  String seal; // 願 / 合 / 康 ...
  final DateTime createdAt;
  int intensity; // 1~5
  int cheersReceived;
  int shardsPledged;
  DateTime? fulfilledAt;
  String? region; // 익명 피드용, 예: "대구"
  String? ageGroup; // 익명 피드용, 예: "20대"
  bool day100Rewarded; // 100일 보상 지급 여부(중복 방지)

  int get daysLit => DateTime.now().difference(createdAt).inDays;

  bool get isFulfilled => fulfilledAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'text': text,
        'seal': seal,
        'createdAt': createdAt.toIso8601String(),
        'intensity': intensity,
        'cheersReceived': cheersReceived,
        'shardsPledged': shardsPledged,
        'fulfilledAt': fulfilledAt?.toIso8601String(),
        'region': region,
        'ageGroup': ageGroup,
        'day100Rewarded': day100Rewarded,
      };

  factory WishRoomWish.fromMap(Map<dynamic, dynamic> map) => WishRoomWish(
        id: map['id'] as String,
        ownerId: map['ownerId'] as String,
        text: map['text'] as String? ?? '',
        seal: map['seal'] as String? ?? '願',
        createdAt: DateTime.parse(map['createdAt'] as String),
        intensity: (map['intensity'] as num?)?.toInt() ?? 3,
        cheersReceived: (map['cheersReceived'] as num?)?.toInt() ?? 0,
        shardsPledged: (map['shardsPledged'] as num?)?.toInt() ?? 0,
        fulfilledAt: map['fulfilledAt'] != null ? DateTime.parse(map['fulfilledAt'] as String) : null,
        region: map['region'] as String?,
        ageGroup: map['ageGroup'] as String?,
        day100Rewarded: map['day100Rewarded'] as bool? ?? false,
      );
}

/// ─────────────────────────────────────────────────────────
/// 조각 획득 이벤트 (Earn) / 사용 이벤트 (Spend)
/// dev-spec.md §5.2
/// ─────────────────────────────────────────────────────────
enum WishRoomEarnType {
  attendance,
  meditation,
  cheer,
  compose,
  invite,
  day100,
  fulfilled,
  adWatched,
  fullMoonMult,
  streakBonus,
}

enum WishRoomSpendType { buySeal, buyCandle, buyTheme, buyTalisman, gift }

class WishRoomLedgerEntry {
  const WishRoomLedgerEntry({
    required this.id,
    required this.label,
    required this.sub,
    required this.amount, // 양수=획득, 음수=사용
    required this.date,
  });

  final String id;
  final String label;
  final String sub;
  final int amount;
  final DateTime date;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'sub': sub,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory WishRoomLedgerEntry.fromMap(Map<dynamic, dynamic> map) => WishRoomLedgerEntry(
        id: map['id'] as String,
        label: map['label'] as String,
        sub: map['sub'] as String? ?? '',
        amount: (map['amount'] as num).toInt(),
        date: DateTime.parse(map['date'] as String),
      );

  static String formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

@immutable
class WishRoomEarnResult {
  const WishRoomEarnResult({required this.amount, required this.newBalance, required this.label});
  final int amount;
  final int newBalance;
  final String label;
}
