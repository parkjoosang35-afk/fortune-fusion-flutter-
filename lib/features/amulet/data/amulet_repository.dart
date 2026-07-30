import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/amulet_item_model.dart';
import '../domain/amulet_model.dart';
import '../domain/user_amulet_model.dart';

/// 06단계 §4.8 `/v1/amulets/*` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/amulets/{shop,my}`, `POST /api/public/amulets/{purchase,use,generate,gift}`)를 호출한다.
///
/// [실API 전환 - 갭 처리] admin_web UserAmulet 스키마에는 isEquipped 컬럼이 없어
/// "장착" 기능에 대응하는 서버 API가 없다. equip()은 서버 호출 없이
/// AmuletProvider에서 클라이언트 로컬 상태로만 처리한다(본 Repository에는 정의하지 않음).
class AmuletRepository {
  /// 홈 배너 요약용 — 서버에 전용 요약 API가 없어, 보유 목록 중 가장 최근 held 항목을
  /// 요약으로 사용한다. 보유 부적이 없으면 hasActive=false로 안내 카드만 노출한다.
  Future<ApiResult<AmuletSummary>> getActiveSummary() async {
    final result = await getMyAmulets();
    if (!result.success) {
      return ApiResult.ok(
        const AmuletSummary(hasActive: false, name: '', iconEmoji: '🧧'),
      );
    }
    final held = result.data!
        .where((a) => a.status == UserAmuletStatus.held)
        .toList();
    if (held.isEmpty) {
      return ApiResult.ok(
        const AmuletSummary(hasActive: false, name: '', iconEmoji: '🧧'),
      );
    }
    final latest = held.first;
    return ApiResult.ok(
      AmuletSummary(
        hasActive: true,
        name: latest.item.name,
        iconEmoji: latest.item.iconEmoji,
      ),
    );
  }

  /// GET /api/public/amulets/shop
  Future<ApiResult<List<AmuletItemModel>>> getShopItems() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/amulets/shop',
    );
    debugPrint('[AmuletRepository] [shop] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '부적 상점 목록을 불러오지 못했습니다.';
        debugPrint('[AmuletRepository] [shop] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final list = (decoded['data'] as List<dynamic>)
          .map((e) => AmuletItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[AmuletRepository] [shop] 예외 -> $e');
      return ApiResult.fail('부적 상점 목록을 불러오지 못했습니다: $e');
    }
  }

  /// GET /api/public/amulets/my
  Future<ApiResult<List<UserAmuletModel>>> getMyAmulets() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/amulets/my?userId=$userId',
    );
    debugPrint('[AmuletRepository] [my] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '보유 부적 목록을 불러오지 못했습니다.';
        debugPrint('[AmuletRepository] [my] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final list = (decoded['data'] as List<dynamic>)
          .map((e) => UserAmuletModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[AmuletRepository] [my] 예외 -> $e');
      return ApiResult.fail('보유 부적 목록을 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/amulets/purchase — 서버가 지갑 차감까지 트랜잭션으로 처리한다.
  /// [주의] 호출부(화면)는 더 이상 WalletProvider.spend()를 선행 호출하지 않고,
  /// 성공 시 반환된 balanceAfter로 WalletProvider 잔액을 직접 동기화해야 한다
  /// (중복 차감 방지 — amulet_shop_screen.dart / amulet_generate_screen.dart 참조).
  Future<ApiResult<Map<String, dynamic>>> purchase(String itemId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/amulets/purchase',
    );
    debugPrint('[AmuletRepository] [purchase] 요청 -> itemId=$itemId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'itemId': itemId}),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '부적 구매에 실패했습니다.';
        debugPrint('[AmuletRepository] [purchase] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AmuletRepository] [purchase] 예외 -> $e');
      return ApiResult.fail('부적 구매 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/amulets/use
  Future<ApiResult<void>> use(String userAmuletId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/amulets/use',
    );
    debugPrint('[AmuletRepository] [use] 요청 -> userAmuletId=$userAmuletId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userAmuletId': userAmuletId}),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '부적 사용에 실패했습니다.';
        debugPrint('[AmuletRepository] [use] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[AmuletRepository] [use] 예외 -> $e');
      return ApiResult.fail('부적 사용 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/amulets/generate — [주의] purchase()와 동일하게 서버가 아직
  /// 별도 차감을 하지 않으므로(현재 라우트는 무료 지급), 호출부에서 필요 시 별도
  /// WalletProvider.spend()를 유지해야 한다(향후 서버측 과금 로직 추가 여지 있음).
  Future<ApiResult<Map<String, dynamic>>> generate(String baseItemId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/amulets/generate',
    );
    debugPrint('[AmuletRepository] [generate] 요청 -> baseItemId=$baseItemId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'baseItemId': baseItemId}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '부적 생성에 실패했습니다.';
        debugPrint('[AmuletRepository] [generate] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AmuletRepository] [generate] 예외 -> $e');
      return ApiResult.fail('부적 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/amulets/gift
  Future<ApiResult<void>> gift(
    String userAmuletId,
    String toUserNickname,
    String? message,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/amulets/gift',
    );
    debugPrint('[AmuletRepository] [gift] 요청 -> userAmuletId=$userAmuletId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'userAmuletId': userAmuletId,
              'toUserNickname': toUserNickname,
              if (message != null) 'message': message,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '부적 선물에 실패했습니다.';
        debugPrint('[AmuletRepository] [gift] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[AmuletRepository] [gift] 예외 -> $e');
      return ApiResult.fail('부적 선물 중 오류가 발생했습니다: $e');
    }
  }
}
