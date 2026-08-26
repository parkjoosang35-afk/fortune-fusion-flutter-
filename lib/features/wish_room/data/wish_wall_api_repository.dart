import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/wish_wall_models.dart';
import 'wish_wall_repository.dart';

/// 소원방(Wish Wall) 실 API Repository — [WishWallRepository] 구현체.
///
/// [6-1-F 최종 결정] admin_web 공개 API(총 8개 기능 + 기존 reports 재사용)에
/// 대응한다. 서버 API가 없는 기능(hideWish/blockUser/updateWishStatus/
/// deleteWish/submitDailyPrayer)은 서버를 호출하지 않고 로컬 처리 또는
/// no-op으로 구현한다(신규 DB/API 금지 원칙).
///
/// [절대 원칙] API 성공 시에만 실제 데이터를 반환한다. API 실패 시 예외를
/// 던져 화면이 오류/재시도를 표시하도록 하며, [MockWishWallRepository]로
/// 몰래 폴백하지 않는다.
class ApiWishWallRepository implements WishWallRepository {
  static const String _kHiddenWishIdsKey = 'wish_wall_hidden_ids';
  static const String _kBlockedAuthorIdsKey = 'wish_wall_blocked_author_ids';

  String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/wishes';

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final auth = await AuthTokenStore.authHeader();
    return {if (json) 'Content-Type': 'application/json', ...auth};
  }

  Never _fail(String context, Object error) {
    debugPrint('[ApiWishWallRepository] [$context] 실패 -> $error');
    throw Exception('$context 요청에 실패했습니다: $error');
  }

  // ── 로컬 전용 숨김/차단 목록(SharedPreferences) ──────────────────────
  Future<Set<String>> _loadLocalSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const []).toSet();
  }

  Future<void> _saveLocalSet(String key, Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value.toList());
  }

  Future<Set<String>> _hiddenWishIds() => _loadLocalSet(_kHiddenWishIdsKey);
  Future<Set<String>> _blockedAuthorIds() =>
      _loadLocalSet(_kBlockedAuthorIdsKey);

  Future<List<WishPost>> _applyLocalFilters(List<WishPost> source) async {
    final hidden = await _hiddenWishIds();
    final blocked = await _blockedAuthorIds();
    if (hidden.isEmpty && blocked.isEmpty) return source;
    return source
        .where((w) => !hidden.contains(w.id) && !blocked.contains(w.authorId))
        .toList();
  }

  // ── DTO -> WishPost 매핑 ──────────────────────────────────────────
  WishCategory _parseCategory(String raw) {
    return WishCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => WishCategory.etc,
    );
  }

  WishVisibility _parseVisibility(String raw) {
    return WishVisibility.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => WishVisibility.anonymous,
    );
  }

  WishPost _fromJson(Map<String, dynamic> json) {
    final authorName = json['authorName'] as String? ?? '익명';
    return WishPost(
      id: json['id'] as String,
      authorId: json['authorId'] as String? ?? '',
      authorName: authorName,
      // 서버 DTO에는 아바타 이모지 개념이 없어 고정 기본값을 사용한다
      // (WishPost.displayName은 isAnonymous일 때 authorName 대신 '익명'을
      // 쓰므로 화면 표시에는 영향이 없다).
      authorAvatarEmoji: '👤',
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      categoryId: _parseCategory(json['categoryId'] as String? ?? 'etc'),
      text: json['text'] as String? ?? '',
      glassLevel: (json['glassLevel'] as num?)?.toDouble() ?? 0.0,
      visibility: _parseVisibility(
        json['visibility'] as String? ?? 'anonymous',
      ),
      isGratitude: json['isGratitude'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      supportCount: json['supportCount'] as int? ?? 0,
      prayerCount: json['prayerCount'] as int? ?? 0,
      pouchCount: json['pouchCount'] as int? ?? 0,
      hasSupportedByMe: false,
      hasPrayedToday: false,
      hasNewReaction: false,
      // [Phase02-A 클라이언트 연동] 서버 toWishDto()가 내려주는 상태머신
      // 필드. wishState가 없으면(구버전 응답 등) 'sealed'로 안전하게 대체.
      wishState: json['wishState'] as String? ?? 'sealed',
      sealedAt: DateTime.tryParse(json['sealedAt'] as String? ?? ''),
      unlockAt: DateTime.tryParse(json['unlockAt'] as String? ?? ''),
      fulfilledAt: DateTime.tryParse(json['fulfilledAt'] as String? ?? ''),
      openedBoxAt: DateTime.tryParse(json['openedBoxAt'] as String? ?? ''),
    );
  }

  @override
  Future<List<WishPost>> fetchFeed({String? categoryFilter}) async {
    final query = <String, String>{};
    if (categoryFilter != null && categoryFilter != 'all') {
      query['category'] = categoryFilter;
    }
    final uri = Uri.parse(
      _base,
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail('fetchFeed', decoded['error'] ?? 'HTTP ${response.statusCode}');
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
      return _applyLocalFilters(list);
    } catch (e) {
      _fail('fetchFeed', e);
    }
  }

  @override
  Future<WishPost?> fetchDetail(String wishId) async {
    final uri = Uri.parse('$_base/$wishId');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail('fetchDetail', decoded['error'] ?? 'HTTP ${response.statusCode}');
      }
      return _fromJson(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      _fail('fetchDetail', e);
    }
  }

  @override
  Future<WishPost> createWish({
    required WishCategory categoryId,
    required double glassLevel,
    required String text,
    required WishVisibility visibility,
  }) async {
    final result = await createWishWithReward(
      categoryId: categoryId,
      glassLevel: glassLevel,
      text: text,
      visibility: visibility,
    );
    return result.wish;
  }

  @override
  Future<({WishPost wish, int grantedAmount})> createWishWithReward({
    required WishCategory categoryId,
    required double glassLevel,
    required String text,
    required WishVisibility visibility,
  }) async {
    final uri = Uri.parse(_base);
    try {
      final headers = await _authHeaders(json: true);
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'category': categoryId.name,
              'content': text,
              'glassLevel': glassLevel,
              'visibility': visibility.name,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail('createWish', decoded['error'] ?? 'HTTP ${response.statusCode}');
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final wish = _fromJson(data);
      final grantedAmount = data['grantedAmount'] as int? ?? 0;
      return (wish: wish, grantedAmount: grantedAmount);
    } catch (e) {
      _fail('createWish', e);
    }
  }

  /// [6-1-F 최종 결정] 서버 API 없음 — Repository 호환용 안전한 no-op.
  @override
  Future<void> updateWishStatus(String wishId, {bool? isGratitude}) async {}

  /// [6-1-F 최종 결정] 서버 삭제 API 없음 — 관리자 삭제는 기존
  /// community/reports의 Wish 처리 구조를 그대로 사용한다. 안전한 no-op.
  @override
  Future<void> deleteWish(String wishId) async {}

  @override
  Future<WishPost> support(String wishId) async {
    final uri = Uri.parse('$_base/$wishId/support');
    try {
      final headers = await _authHeaders(json: true);
      final response = await http
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail('support', decoded['error'] ?? 'HTTP ${response.statusCode}');
      }
      final wish = _fromJson(decoded['data'] as Map<String, dynamic>);
      wish.hasSupportedByMe = true;
      return wish;
    } catch (e) {
      _fail('support', e);
    }
  }

  /// [6-1-F 최종 결정] 기도는 이번 단계에서 DB/API로 만들지 않는다. 서버 호출
  /// 없이 로컬에서 즉시 성공 처리해 UI 피드백(애니메이션+"기도를 보냈어요")만
  /// 제공한다. 서버 재조회 없이 로컬로 fetchDetail을 다시 호출해 최신 상태를
  /// 유지하되, prayerCount/hasPrayedToday는 이번 결정에 따라 서버에 반영되지
  /// 않으므로 화면에서만 토글해 표시한다.
  @override
  Future<WishPost> submitDailyPrayer(String wishId) async {
    final wish = await fetchDetail(wishId);
    if (wish == null) {
      throw Exception('소원을 찾을 수 없습니다');
    }
    if (!wish.hasPrayedToday) {
      wish.hasPrayedToday = true;
    }
    return wish;
  }

  @override
  Future<List<WishPost>> fetchMyWishes() async {
    final uri = Uri.parse('$_base/my');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'fetchMyWishes',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      return (decoded['data'] as List<dynamic>)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _fail('fetchMyWishes', e);
    }
  }

  @override
  Future<List<WishComment>> fetchComments(String wishId) async {
    final uri = Uri.parse('$_base/$wishId/comments');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'fetchComments',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      return (decoded['data'] as List<dynamic>).map((e) {
        final map = e as Map<String, dynamic>;
        return WishComment(
          id: map['id'] as String,
          wishId: map['wishId'] as String? ?? wishId,
          authorName: map['authorName'] as String? ?? '',
          text: map['text'] as String? ?? '',
          createdAt:
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
          isMine: map['isMine'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      _fail('fetchComments', e);
    }
  }

  @override
  Future<WishComment> createComment(String wishId, String text) async {
    final uri = Uri.parse('$_base/$wishId/comments');
    try {
      final headers = await _authHeaders(json: true);
      final response = await http
          .post(uri, headers: headers, body: jsonEncode({'text': text}))
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'createComment',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      final map = decoded['data'] as Map<String, dynamic>;
      return WishComment(
        id: map['id'] as String,
        wishId: map['wishId'] as String? ?? wishId,
        authorName: map['authorName'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        isMine: map['isMine'] as bool? ?? true,
      );
    } catch (e) {
      _fail('createComment', e);
    }
  }

  @override
  Future<void> reportWish(String wishId, String reason) async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/reports');
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final headers = await _authHeaders(json: true);
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              'targetType': 'wish',
              'targetId': wishId,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail('reportWish', decoded['error'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      _fail('reportWish', e);
    }
  }

  /// [6-1-F 최종 결정] 서버 영구 저장 없음 — 현재 기기(SharedPreferences)에서만
  /// 숨김 처리한다. 신규 DB/필드/테이블/API 없음.
  @override
  Future<void> hideWish(String wishId) async {
    final hidden = await _hiddenWishIds();
    hidden.add(wishId);
    await _saveLocalSet(_kHiddenWishIdsKey, hidden);
  }

  /// [6-1-F 최종 결정] 신규 DB/API/테이블 없음 — 기존 Mock 코드의 차단 동작
  /// 범위(해당 작성자의 게시물을 현재 화면에서 감춤)를 그대로 로컬 저장으로
  /// 유지한다.
  @override
  Future<void> blockUser(String authorId) async {
    final blocked = await _blockedAuthorIds();
    blocked.add(authorId);
    await _saveLocalSet(_kBlockedAuthorIdsKey, blocked);
  }

  @override
  Future<WishPost> incrementPouch(String wishId, int amount) async {
    final uri = Uri.parse('$_base/$wishId/bokju');
    try {
      final headers = await _authHeaders(json: true);
      final response = await http
          .post(uri, headers: headers, body: jsonEncode({'amount': amount}))
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'incrementPouch',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      final wish = _fromJson(decoded['data'] as Map<String, dynamic>);
      wish.hasNewReaction = true;
      return wish;
    } catch (e) {
      _fail('incrementPouch', e);
    }
  }

  // ── [복주머니 확장 Phase02-A 클라이언트 연동] 소원함 상태머신 API ──────

  @override
  Future<List<WishPost>> fetchPendingBoxOpenings() async {
    final uri = Uri.parse('$_base/pending-openings');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'fetchPendingBoxOpenings',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      return (decoded['data'] as List<dynamic>)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _fail('fetchPendingBoxOpenings', e);
    }
  }

  @override
  Future<WishPost?> markBoxOpened(String wishId) async {
    final uri = Uri.parse('$_base/$wishId/opened');
    try {
      final headers = await _authHeaders(json: true);
      final response = await http
          .patch(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'markBoxOpened',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      return _fromJson(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      _fail('markBoxOpened', e);
    }
  }

  @override
  Future<({WishPost wish, int grantedAmount})> markWishFulfilled(
    String wishId,
  ) async {
    final uri = Uri.parse('$_base/$wishId/fulfilled');
    try {
      final headers = await _authHeaders(json: true);
      final response = await http
          .patch(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        _fail(
          'markWishFulfilled',
          decoded['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final wish = _fromJson(data);
      final grantedAmount = data['grantedAmount'] as int? ?? 0;
      return (wish: wish, grantedAmount: grantedAmount);
    } catch (e) {
      _fail('markWishFulfilled', e);
    }
  }
}
