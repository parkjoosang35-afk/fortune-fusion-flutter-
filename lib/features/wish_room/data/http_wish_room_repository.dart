import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/enums/customize_category.dart';
import '../domain/enums/prayer_type.dart';
import 'models/customize_item_model.dart';
import 'models/daily_message_model.dart';
import 'models/fortune_pouch_status_model.dart';
import 'models/guide_slide_model.dart';
import 'models/prayer_session_model.dart';
import 'models/wish_item_model.dart';
import 'models/wish_room_model.dart';
import 'repositories/wish_room_repository.dart';

/// [소원방 실 서버 연동] admin_web `/api/wish-room/*` 공개 API를 호출하는
/// [WishRoomRepository] 구현체.
///
/// ══════════════════════════════════════════════════════════════════
/// [설계 배경 - 서버 ↔ 클라이언트 모델 갭 매핑 원칙]
/// 기존 Flutter wish_room 모듈(Mock 단계)의 도메인 모델과 실제로 구현된
/// 서버 API(admin_web `wish-room-service.ts` + 9개+ 라우트)는 서로 다른
/// 시점에 독립적으로 설계되어 개념 체계가 정확히 일치하지 않는다. 이
/// 클래스는 그 갭을 해소하는 "어댑터"이며, Controller/위젯 코드는 전혀
/// 손대지 않고 이 파일 하나로 실 서버 연동을 완결한다.
///
/// [인터페이스 확장 메서드] `fetchGuideSlides()`는 [WishRoomRepository]
/// 정식 인터페이스에 포함됐지만, `wakeWish()`/`publishWish()`/
/// `removeCustomizeItem()` 3개는 서버 전용 액션(소원 깨우기/게시판 공개/
/// 꾸미기 해제)이라 기존 인터페이스에 아직 없다 — 이 클래스에만 추가된
/// 확장 메서드이며, 정식 인터페이스로 승격하려면 Mock 구현체에도 대응
/// 메서드를 추가해야 한다(§ "기존 구현 삭제/재작성 금지" — 인터페이스를
/// 성급하게 넓혀 다른 구현체를 깨뜨리지 않기 위해 최소 변경만 반영).
///
/// 1) ID 형식 — 서버는 `wrw_<id>` 문자열을 그대로 소원 ID로 쓴다
///    (parseWishRoomWishId가 이 형식과 순수 숫자 둘 다 파싱 가능하도록
///    서버에 이미 구현되어 있음). Flutter WishItem.id도 String이라 별도
///    변환 없이 그대로 저장한다.
///
/// 2) WishCategory(8종) — 서버 WishRoomCategory 시딩값과 코드가 1:1로
///    동일하다(seed_wish_room.ts 참고). `WishCategory.name`이 그대로
///    서버 `categoryCode`다.
///
/// 3) 성장 축 — Flutter `growthPoint`(0~250+, WishGrowthStage 5단계)와
///    서버 `energy`(0~maxEnergy=300, 관리자 설정)는 스케일이 유사해
///    `growthPoint = energy`로 그대로 매핑한다. `prayerCount`=`careCount`,
///    `lastPrayedAt`=`lastCaredAt`.
///
/// 4) 치성 액션 — 서버에는 "하루 1회 힘주기(care)"와 "깨우기(wake)" 2종
///    액션만 존재한다. 기존 Flutter `PrayerType`(daily/deep/focused/
///    gratitude) 중 서버에 대응하는 것은 daily뿐이다. deep/focused/
///    gratitude 호출은 이 구현체에서 daily와 동일하게 `care` API를
///    호출하도록 폴백 처리한다(서버가 하루 1회 제한을 이미 검증하므로
///    이중 소비는 발생하지 않음). 이 폴백은 임시 조치이며, UI에서
///    deep/focused 전용 버튼(prayer_type_sheet.dart)을 정리하는 후속
///    작업이 필요하다 — 절대 이 Repository가 복주머니를 임의로 추가
///    차감하는 방식으로 "deep/focused 전용 소비"를 흉내내지 않는다
///    (§ "클라이언트에서 복주머니 수치 임의 증가/차감 금지" 원칙).
///
/// 5) 슬롯 시스템 — 서버 정책(`wish_room_max_wish_count`, 기본 3)은
///    슬롯 잠금 개념 없이 "동시 보유 가능한 최대 소원 개수"만 제한한다.
///    즉 서버는 처음부터 대표1+서브2(=3개)를 자유롭게 채울 수 있게
///    허용하므로, 클라이언트의 "서브 슬롯이 잠겨있다"는 상태 자체가
///    서버 설계와 맞지 않는다. 이 Repository는 항상
///    `unlockedSubSlotCount = WishRoom.maxSubSlotCount`로 응답해
///    UI가 처음부터 3칸을 모두 사용 가능하게 하며, `unlockSubSlot()`
///    호출 시에도 서버에 아무 요청도 보내지 않고(비용 없음) 그대로
///    성공 처리한다 — 복주머니를 잘못 차감하는 사고를 원천 차단한다.
///
/// 6) 꾸미기 카테고리 — Flutter `CustomizeCategory`(6종: objectSkin/
///    altar/background/effect/decoration/seasonalTheme)와 서버
///    `WishRoomTheme`(itemType="theme") + `WishRoomObject.category`
///    (6종: star_effect/moon_effect/orb_effect/special_animation/
///    decoration/energy_charge)는 이름과 세분화 수준이 다르다. 매핑:
///      - itemType="theme"                  -> CustomizeCategory.background
///      - category="star_effect"/"moon_effect"/"orb_effect"
///                                           -> CustomizeCategory.effect
///      - category="special_animation"       -> CustomizeCategory.objectSkin
///      - category="decoration"              -> CustomizeCategory.decoration
///      - category="energy_charge"           -> 카탈로그에서 제외(배치
///        불가 소모성 아이템 — 서버 customize/apply도 NOT_PLACEABLE로
///        거부하는 항목이라 꾸미기 카탈로그에 노출하지 않는다).
///    `CustomizeItem.id`는 서버의 (itemType, itemId) 조합을 문자열로
///    인코딩한 합성 ID `"theme_<id>"` / `"object_<id>"`를 쓴다.
/// ══════════════════════════════════════════════════════════════════
class HttpWishRoomRepository implements WishRoomRepository {
  // 서버에 대응 API가 없는 daily_message는 로컬에서만 생성한다(재화/상태에
  // 영향을 주지 않는 순수 표시 문구이므로 "서버 확정" 원칙과 무관).
  static const _moods = MessageMood.values;

  int? _cachedUserId;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${EnvConfig.adminApiBaseUrl}$path',
    ).replace(queryParameters: query);
  }

  Future<int> _userId() async {
    _cachedUserId ??= await AuthTokenStore.getCurrentUserId();
    return _cachedUserId!;
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final uri = _uri(path, query);
    debugPrint('[HttpWishRoomRepository] GET -> $uri');
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    debugPrint('[HttpWishRoomRepository] POST -> $uri, body=$body');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      final error = decoded['error'] as String? ?? '요청에 실패했습니다.';
      debugPrint(
        '[HttpWishRoomRepository] 실패 -> status=${response.statusCode}, error=$error, reason=${decoded['reason']}',
      );
      throw WishRoomApiException(
        error,
        reason: decoded['reason'] as String?,
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  // ── fetchInitialData ──────────────────────────────────────────────
  @override
  Future<WishRoomBundle> fetchInitialData() async {
    final userId = await _userId();
    final decoded = await _get('/api/wish-room/me', query: {'userId': '$userId'});
    final data = decoded['data'] as Map<String, dynamic>;

    final profile = data['profile'] as Map<String, dynamic>;
    final wishesRaw = (data['wishes'] as List<dynamic>? ?? []);
    final wishes = wishesRaw
        .map((e) => _wishFromJson(e as Map<String, dynamic>))
        .toList();
    final pouchBalance = data['pouchBalance'] as int? ?? 0;
    final policy = data['policy'] as Map<String, dynamic>? ?? const {};
    final dailyFreeQuota = policy['careDailyFreeCount'] as int? ?? 1;
    final hasSeenGuide = profile['hasSeenGuide'] as bool? ?? false;

    final room = WishRoom(
      userId: '$userId',
      wishes: wishes,
      totalPrayerCount: profile['totalCareCount'] as int? ?? 0,
      consecutivePrayerDays: profile['consecutiveVisitDays'] as int? ?? 0,
      // [슬롯 시스템 매핑] 서버는 슬롯 잠금 개념이 없으므로 항상 서브
      // 슬롯 전부가 해금된 상태로 표시한다(설계 배경 5번 참고).
      unlockedSubSlotCount: WishRoom.maxSubSlotCount,
      lastPrayedDate: _lastCaredAtOfRepresentative(wishes),
    );

    return WishRoomBundle(
      room: room,
      pouchStatus: FortunePouchStatus(
        totalCount: pouchBalance,
        dailyFreeQuota: dailyFreeQuota,
      ),
      dailyMessage: _buildDailyMessage(),
      isFirstVisit: !hasSeenGuide,
    );
  }

  DateTime? _lastCaredAtOfRepresentative(List<WishItem> wishes) {
    // "오늘 이미 정성을 담았는지" 판단 기준값 — 대표 소원이 있으면 그 값을,
    // 없으면 전체 소원 중 가장 최근 값을 사용한다.
    for (final w in wishes) {
      if (w.isRepresentative && w.lastPrayedAt != null) return w.lastPrayedAt;
    }
    DateTime? latest;
    for (final w in wishes) {
      final t = w.lastPrayedAt;
      if (t != null && (latest == null || t.isAfter(latest))) latest = t;
    }
    return latest;
  }

  DailyMessage _buildDailyMessage() {
    final now = DateTime.now();
    const messages = [
      '오늘도 당신의 소원을 응원해요.',
      '작은 정성이 큰 변화를 만들어요.',
      '소원방이 당신을 기다리고 있어요.',
      '오늘 하루도 반짝이는 마음으로.',
    ];
    final idx = now.day % messages.length;
    return DailyMessage(
      id: 'daily_${now.year}${now.month}${now.day}',
      date: now,
      text: messages[idx],
      mood: _moods[idx % _moods.length],
    );
  }

  WishItem _wishFromJson(Map<String, dynamic> json) {
    final categoryCode = json['categoryCode'] as String? ?? 'custom';
    final category = WishCategory.values.firstWhere(
      (c) => c.name == categoryCode,
      orElse: () => WishCategory.custom,
    );
    final lastCaredAt = json['lastCaredAt'] as String?;
    final createdAt = json['createdAt'] as String?;
    return WishItem(
      id: json['id'] as String,
      title: json['content'] as String? ?? '',
      category: category,
      createdAt: createdAt != null ? DateTime.parse(createdAt) : DateTime.now(),
      lastPrayedAt: lastCaredAt != null ? DateTime.parse(lastCaredAt) : null,
      prayerCount: json['careCount'] as int? ?? 0,
      isRepresentative: json['isRepresentative'] as bool? ?? false,
      growthPoint: json['energy'] as int? ?? 0,
      maxEnergy: json['maxEnergy'] as int? ?? 300,
    );
  }

  // ── addWish ───────────────────────────────────────────────────────
  @override
  Future<WishItem> addWish({
    required String title,
    required WishCategory category,
  }) async {
    final userId = await _userId();
    final decoded = await _post('/api/wish-room/wishes', {
      'userId': userId,
      'categoryCode': category.name,
      'content': title,
    });
    final wishJson = (decoded['data'] as Map<String, dynamic>)['wish'] as Map<String, dynamic>;
    return _wishFromJson(wishJson);
  }

  // ── setRepresentative ────────────────────────────────────────────
  @override
  Future<void> setRepresentative(
    String wishId, {
    required bool isRepresentative,
  }) async {
    if (!isRepresentative) {
      // 서버는 "대표 해제"라는 별도 액션이 없다(항상 정확히 1개의 대표를
      // 유지하는 단일 대표 규칙) — 다른 소원을 대표로 지정하는 방식으로만
      // 간접적으로 해제되므로, 이 호출은 아무 일도 하지 않는다.
      return;
    }
    final userId = await _userId();
    await _post('/api/wish-room/wishes/$wishId/represent', {'userId': userId});
  }

  // ── prayForWish (care API로 매핑, 설계 배경 4번 참고) ──────────────
  @override
  Future<PrayerSession> prayForWish({
    required String wishId,
    required PrayerType type,
  }) async {
    final userId = await _userId();
    final requestId = _newRequestId();
    final decoded = await _post('/api/wish-room/wishes/$wishId/care', {
      'userId': userId,
      'requestId': requestId,
    });
    final data = decoded['data'] as Map<String, dynamic>;
    final rewardAmount = data['rewardAmount'] as int? ?? 0;
    return PrayerSession(
      id: requestId,
      wishId: wishId,
      pouchUsed: 0, // care는 복주머니를 "소비"하지 않고 오히려 지급한다.
      prayedAt: DateTime.now(),
      resultMessage: rewardAmount > 0
          ? '정성이 닿아 복주머니 $rewardAmount개를 받았어요'
          : '당신의 진심이 빛으로 남았어요',
    );
  }

  /// [소원 깨우기] care(하루 1회 힘주기)와 별개인 복귀 회복 액션. 감쇠가
  /// 실제로 발생한 소원에서만 유효하며, 서버가 `NOTHING_TO_WAKE`로 판정하면
  /// null을 반환한다(§ [WishRoomRepository.wakeWish] 계약 참고). 이제
  /// [WishRoomController.wakeWish] → `wish_room_screen.dart`의 "🥀 소원의
  /// 빛이 조금 약해졌어요" CTA에서 실제로 호출된다.
  @override
  Future<PrayerSession?> wakeWish(String wishId) async {
    final userId = await _userId();
    final requestId = _newRequestId();
    try {
      final decoded = await _post('/api/wish-room/wake', {
        'userId': userId,
        'wishId': wishId,
        'requestId': requestId,
      });
      final data = decoded['data'] as Map<String, dynamic>;
      final rewardAmount = data['rewardAmount'] as int? ?? 0;
      return PrayerSession(
        id: requestId,
        wishId: wishId,
        pouchUsed: 0,
        prayedAt: DateTime.now(),
        resultMessage: '소원이 다시 밝게 빛나요 (+$rewardAmount 복주머니)',
      );
    } on WishRoomApiException catch (e) {
      if (e.reason == null && e.statusCode == 400) {
        // "깨울 필요 없음" — 실패가 아니라 정상적인 무동작 상태.
        return null;
      }
      rethrow;
    }
  }

  /// [소원 게시판 공개] 서버 전용 액션 — 기존 인터페이스에는 없는 신규
  /// 확장 메서드다. 소원방(개인 공간)의 소원을 소원게시판(커뮤니티)에
  /// 공개한다(§ "소원게시판 vs 소원방 분리 규칙" — 자동 공개는 없고
  /// 사용자가 명시적으로 이 메서드를 호출했을 때만 게시된다).
  Future<int?> publishWish(String wishId) async {
    final userId = await _userId();
    final decoded = await _post('/api/wish-room/wishes/$wishId/publish', {'userId': userId});
    final data = decoded['data'] as Map<String, dynamic>;
    return data['publicWishId'] as int?;
  }

  String _newRequestId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = (now * 2654435761) & 0x7fffffff;
    return 'wr_${now}_$rand';
  }

  // ── markGuideSeen ─────────────────────────────────────────────────
  @override
  Future<void> markGuideSeen() async {
    final userId = await _userId();
    await _post('/api/wish-room/guide/seen', {'userId': userId});
  }

  // ── fetchGuideSlides ─────────────────────────────────────────────
  @override
  Future<List<GuideSlide>> fetchGuideSlides() async {
    final decoded = await _get('/api/wish-room/guide');
    final slides = (decoded['data'] as Map<String, dynamic>)['slides'] as List<dynamic>;
    return slides
        .map(
          (s) => GuideSlide(
            title: (s as Map<String, dynamic>)['title'] as String? ?? '',
            body: s['body'] as String? ?? '',
            imageUrl: s['imageUrl'] as String?,
          ),
        )
        .toList();
  }

  // ── unlockSubSlot (설계 배경 5번 - 서버 비용 없이 항상 성공) ────────
  @override
  Future<WishRoom> unlockSubSlot({required bool viaPouch}) async {
    // 서버 정책상 슬롯 잠금이 존재하지 않으므로 복주머니를 건드리지 않고
    // 항상 이미 해금된 최신 상태를 다시 조회해 반환한다.
    final bundle = await fetchInitialData();
    return bundle.room;
  }

  // ── 꾸미기 카탈로그 ──────────────────────────────────────────────
  static const Map<String, CustomizeCategory> _objectCategoryMap = {
    'star_effect': CustomizeCategory.effect,
    'moon_effect': CustomizeCategory.effect,
    'orb_effect': CustomizeCategory.effect,
    'particle': CustomizeCategory.effect,
    'special_animation': CustomizeCategory.objectSkin,
    'decoration': CustomizeCategory.decoration,
  };

  @override
  Future<List<CustomizeItem>> fetchCustomizeCatalog() async {
    final userId = await _userId();
    final decoded = await _get('/api/wish-room/catalog', query: {'userId': '$userId'});
    final data = decoded['data'] as Map<String, dynamic>;
    final themes = (data['themes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final objects = (data['objects'] as List<dynamic>).cast<Map<String, dynamic>>();

    final items = <CustomizeItem>[];
    for (final t in themes) {
      items.add(
        CustomizeItem(
          id: 'theme_${t['id']}',
          name: t['name'] as String,
          category: CustomizeCategory.background,
          unlockType: CustomizeUnlockType.purchase,
          previewEmoji: '🌌',
          pouchPrice: t['pouchPrice'] as int? ?? 0,
          isOwned: t['owned'] as bool? ?? false,
          isApplied: t['applied'] as bool? ?? false,
        ),
      );
    }
    for (final o in objects) {
      final serverCategory = o['category'] as String;
      // energy_charge(소모성 에너지 충전권)는 배치 대상이 아니므로 꾸미기
      // 카탈로그에서 제외한다(서버 customize/apply도 NOT_PLACEABLE로 거부).
      if (serverCategory == 'energy_charge') continue;
      final mapped = _objectCategoryMap[serverCategory] ?? CustomizeCategory.decoration;
      items.add(
        CustomizeItem(
          id: 'object_${o['id']}',
          name: o['name'] as String,
          category: mapped,
          unlockType: CustomizeUnlockType.purchase,
          previewEmoji: _emojiForObjectCategory(serverCategory),
          pouchPrice: o['pouchPrice'] as int? ?? 0,
          isOwned: o['owned'] as bool? ?? false,
          isApplied: o['applied'] as bool? ?? false,
        ),
      );
    }
    return items;
  }

  String _emojiForObjectCategory(String category) {
    switch (category) {
      case 'star_effect':
        return '⭐';
      case 'moon_effect':
        return '🌙';
      case 'orb_effect':
        return '🔮';
      case 'particle':
        return '✨';
      case 'special_animation':
        return '🎆';
      case 'decoration':
        return '🎐';
      default:
        return '✨';
    }
  }

  /// `"theme_<id>"` / `"object_<id>"` 합성 ID를 (itemType, itemId)로 분해.
  ({String itemType, int itemId}) _decodeItemId(String compositeId) {
    final parts = compositeId.split('_');
    if (parts.length != 2) {
      throw WishRoomApiException('올바르지 않은 아이템 ID입니다: $compositeId');
    }
    final itemType = parts[0] == 'theme' ? 'theme' : 'object';
    final itemId = int.tryParse(parts[1]);
    if (itemId == null) {
      throw WishRoomApiException('올바르지 않은 아이템 ID입니다: $compositeId');
    }
    return (itemType: itemType, itemId: itemId);
  }

  @override
  Future<List<CustomizeItem>> purchaseCustomizeItem(String itemId) async {
    final userId = await _userId();
    final decoded = _decodeItemId(itemId);
    await _post('/api/wish-room/shop/purchase', {
      'userId': userId,
      'itemType': decoded.itemType,
      'itemId': decoded.itemId,
      'requestId': _newRequestId(),
    });
    // 서버가 가격을 재조회해 확정 차감했으므로, 최신 카탈로그를 다시
    // 가져와 owned/applied 플래그를 갱신한다(클라이언트가 임의로
    // isOwned=true를 세팅하지 않는다).
    return fetchCustomizeCatalog();
  }

  @override
  Future<List<CustomizeItem>> applyCustomizeItem(String itemId) async {
    final userId = await _userId();
    final decoded = _decodeItemId(itemId);
    await _post('/api/wish-room/customize/apply', {
      'userId': userId,
      'itemType': decoded.itemType,
      'itemId': decoded.itemId,
      'action': 'apply',
    });
    return fetchCustomizeCatalog();
  }

  /// [꾸미기 해제] 기존 인터페이스에는 없는 신규 확장 메서드 — decoration
  /// 카테고리(다중 적용 허용)에서 특정 아이템만 해제할 때 사용한다.
  Future<List<CustomizeItem>> removeCustomizeItem(String itemId) async {
    final userId = await _userId();
    final decoded = _decodeItemId(itemId);
    await _post('/api/wish-room/customize/apply', {
      'userId': userId,
      'itemType': decoded.itemType,
      'itemId': decoded.itemId,
      'action': 'remove',
    });
    return fetchCustomizeCatalog();
  }
}

/// [공용 예외] 서버가 `success:false`로 응답했을 때 던지는 예외.
/// [reason]은 서버가 명시한 실패 코드(예: `INSUFFICIENT_BALANCE`,
/// `ALREADY_OWNED`, `DAILY_LIMIT_REACHED`, `NOT_OWNED`)이며, UI가 이
/// 코드에 따라 다른 안내 문구를 보여줄 수 있도록 보존한다.
class WishRoomApiException implements Exception {
  WishRoomApiException(this.message, {this.reason, this.statusCode});

  final String message;
  final String? reason;
  final int? statusCode;

  @override
  String toString() => message;
}
