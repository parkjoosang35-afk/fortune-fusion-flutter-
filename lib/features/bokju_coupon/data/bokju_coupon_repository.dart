import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/bokju_coupon_model.dart';

/// [복주머니 마케팅 쿠폰 — Flutter 연동] admin_web 공개 API
/// (`GET /api/public/bokju-coupons/resolve`, `POST
/// /api/public/bokju-coupons/redeem`, `GET /api/public/bokju-coupons/my`)를
/// 호출한다. `features/wallet/data/wallet_repository.dart`의 Repository
/// 패턴(헤더 구성, 타임아웃, success 플래그 검사, debugPrint 로깅)을 그대로
/// 따른다.
///
/// [인증 필수] 서버의 세 엔드포인트 모두 `requireUser()`로 JWT 인증을
/// 강제하므로, 호출 전 반드시 [AuthTokenStore.isLoggedIn]을 먼저 확인해야
/// 한다(미로그인 시 서버를 호출하지 않고 바로 실패를 반환 — Provider가
/// 로그인 화면으로 안내).
class BokjuCouponRepository {
  /// GET /api/public/bokju-coupons/resolve?token=... — 비파괴 미리보기 조회.
  Future<ApiResult<BokjuCouponPreview>> resolve(String token) async {
    if (!await AuthTokenStore.isLoggedIn()) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'LOGIN_REQUIRED');
    }

    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/bokju-coupons/resolve',
    ).replace(queryParameters: {'token': token});
    debugPrint('[BokjuCouponRepository] [resolve] 요청 시작 -> token=$token');

    try {
      final headers = {
        'Accept': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '쿠폰을 조회하지 못했습니다.';
        debugPrint('[BokjuCouponRepository] [resolve] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      debugPrint('[BokjuCouponRepository] [resolve] 성공 -> $data');
      return ApiResult.ok(BokjuCouponPreview.fromJson(data));
    } catch (e) {
      debugPrint('[BokjuCouponRepository] [resolve] 예외 -> $e');
      return ApiResult.fail('쿠폰 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/bokju-coupons/redeem — 실제 등록(적립) 처리.
  ///
  /// [idempotencyKey] 네트워크 재시도 시 동일 키로 재전송하면 재지급 없이
  /// 최초 결과가 그대로 반환된다(서버 `BokjuCouponRedemption.requestId`
  /// UNIQUE 제약). 호출부(Provider)가 "등록하기" 버튼 1회 탭당 1개의 키를
  /// 생성해 전달하고, 동일 버튼 탭에 대한 자동 재시도에는 같은 키를
  /// 재사용해야 한다. [generateIdempotencyKey]로 생성할 수 있다.
  Future<ApiResult<BokjuCouponRedeemResult>> redeem(
    String token, {
    required String idempotencyKey,
  }) async {
    if (!await AuthTokenStore.isLoggedIn()) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'LOGIN_REQUIRED');
    }

    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/bokju-coupons/redeem',
    );
    debugPrint(
      '[BokjuCouponRepository] [redeem] 요청 시작 -> token=$token, '
      'idempotencyKey=$idempotencyKey',
    );

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'token': token,
              'idempotencyKey': idempotencyKey,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '쿠폰 등록에 실패했습니다.';
        debugPrint(
          '[BokjuCouponRepository] [redeem] 실패 -> code=${decoded['code']}, '
          'error=$error',
        );
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      debugPrint('[BokjuCouponRepository] [redeem] 성공 -> $data');
      return ApiResult.ok(BokjuCouponRedeemResult.fromJson(data));
    } catch (e) {
      debugPrint('[BokjuCouponRepository] [redeem] 예외 -> $e');
      return ApiResult.fail('쿠폰 등록 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /api/public/bokju-coupons/my — 내가 등록 성공한 쿠폰 이력.
  Future<ApiResult<List<BokjuCouponHistoryItem>>> getMyHistory() async {
    if (!await AuthTokenStore.isLoggedIn()) {
      return ApiResult.ok(const []);
    }

    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/bokju-coupons/my',
    );
    debugPrint('[BokjuCouponRepository] [my] 요청 시작');

    try {
      final headers = {
        'Accept': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '쿠폰 이력을 불러오지 못했습니다.';
        debugPrint('[BokjuCouponRepository] [my] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final itemsRaw = (data['redemptions'] as List<dynamic>? ?? []);
      final items = itemsRaw
          .map((e) =>
              BokjuCouponHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[BokjuCouponRepository] [my] 성공 -> ${items.length}건');
      return ApiResult.ok(items);
    } catch (e) {
      debugPrint('[BokjuCouponRepository] [my] 예외 -> $e');
      return ApiResult.fail('쿠폰 이력 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// [멱등키 생성] uuid 패키지 없이(Flutter/Dart 버전 고정 환경에 새 의존성을
  /// 늘리지 않기 위해) 타임스탬프(마이크로초) + 암호학적 보안 난수를 조합해
  /// 전역적으로 유일에 가까운 문자열을 만든다. 서버는 이 값을
  /// `BokjuCouponRedemption.requestId`(UNIQUE)로만 사용하므로 RFC 4122
  /// 형식일 필요는 없다 — 유일성만 보장되면 충분하다.
  static String generateIdempotencyKey() {
    final rand = Random.secure();
    final randomPart = List.generate(16, (_) => rand.nextInt(16))
        .map((n) => n.toRadixString(16))
        .join();
    return 'bc_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }
}
