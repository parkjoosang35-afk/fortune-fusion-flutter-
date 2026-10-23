// 신당(THE SHRINE) U12 어뷰징 방지 — admin_web 서버 원장 연동 Repository.
//
// [배경] canIssue()/recordIssue()/sign()/verifyShare()는 서버(admin_web)가
// 정본이다(ShrineIssueLedger 테이블, /api/public/shrine/* 4개 엔드포인트).
// 이 클래스는 PouchBoxRepository(lib/features/pouch_box/data/
// pouch_box_repository.dart)와 동일한 패턴 — http + AuthTokenStore(JWT
// Bearer) + EnvConfig.adminApiBaseUrl — 을 그대로 따른다.
//
// [서버 재검증 원칙] record-issue 호출 전 반드시 can-issue로 먼저 확인하되,
// 서버도 record-issue 내부에서 canIssue()를 재검증하므로(admin_web
// _shared.ts) 클라이언트가 can-issue 결과를 변조해 보내도 최종 발급은
// 막힌다 — 이 Repository는 그 재검증을 "신뢰"하고 있는 그대로 호출만 한다.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// 발급 가능 여부 판정 결과. `code`는 'NO_SAJU' | 'ALREADY_ISSUED' | 'DAILY_LIMIT' 중 하나(ok=false일 때).
class ShrineCanIssueResult {
  const ShrineCanIssueResult({required this.ok, this.code, this.reason});
  final bool ok;
  final String? code;
  final String? reason;

  factory ShrineCanIssueResult.fromJson(Map<String, dynamic> j) =>
      ShrineCanIssueResult(
        ok: j['ok'] == true,
        code: j['code'] as String?,
        reason: j['reason'] as String?,
      );
}

class ShrineServerRepository {
  /// 발급 전 사전 확인 — MeaningScreen "월화에게 부적을 부탁하기" 버튼에서 호출.
  Future<ApiResult<ShrineCanIssueResult>> canIssue({
    required String? sajuFp,
    required String storyId,
  }) async {
    if (!await AuthTokenStore.isLoggedIn()) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/shrine/can-issue',
    );
    debugPrint('[ShrineServerRepository] [can-issue] 요청 -> storyId=$storyId');
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'sajuFp': sajuFp, 'storyId': storyId}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '확인할 수 없습니다.';
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(ShrineCanIssueResult.fromJson(data));
    } catch (e) {
      debugPrint('[ShrineServerRepository] [can-issue] 예외 -> $e');
      return ApiResult.fail('확인 중 오류가 발생했어요: $e');
    }
  }

  /// 실제 발급 기록 — ReceiveScreen "부적 간직하기" 버튼에서 호출.
  /// 서버가 canIssue()를 내부에서 재검증하므로 409(code: ALREADY_ISSUED 등)가
  /// 돌아올 수 있다 — 호출부는 반드시 이 실패를 처리해야 한다.
  Future<ApiResult<String>> recordIssue({
    required String sajuFp,
    required String storyId,
    required String composeKey,
  }) async {
    if (!await AuthTokenStore.isLoggedIn()) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/shrine/record-issue',
    );
    debugPrint(
      '[ShrineServerRepository] [record-issue] 요청 -> storyId=$storyId',
    );
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'sajuFp': sajuFp,
              'storyId': storyId,
              'composeKey': composeKey,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '발급 기록에 실패했어요.';
        debugPrint('[ShrineServerRepository] [record-issue] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }
      final serial = (decoded['data'] as Map<String, dynamic>)['serial'] as String;
      return ApiResult.ok(serial);
    } catch (e) {
      debugPrint('[ShrineServerRepository] [record-issue] 예외 -> $e');
      return ApiResult.fail('발급 기록 중 오류가 발생했어요: $e');
    }
  }

  /// 공유 payload 서명 — 로그인 사용자만(공유를 만드는 쪽).
  Future<ApiResult<String>> sign(String payload) async {
    if (!await AuthTokenStore.isLoggedIn()) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/shrine/sign');
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(uri, headers: headers, body: jsonEncode({'payload': payload}))
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '서명에 실패했어요.');
      }
      final sig = (decoded['data'] as Map<String, dynamic>)['sig'] as String;
      return ApiResult.ok(sig);
    } catch (e) {
      debugPrint('[ShrineServerRepository] [sign] 예외 -> $e');
      return ApiResult.fail('서명 중 오류가 발생했어요: $e');
    }
  }

  /// 공유 payload 서명 검증 — 인증 불필요(공유받은 제3자도 호출 가능).
  Future<ApiResult<bool>> verifyShare({
    required String payload,
    required String sig,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/shrine/verify-share',
    );
    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'payload': payload, 'sig': sig}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '검증에 실패했어요.');
      }
      final valid = (decoded['data'] as Map<String, dynamic>)['valid'] == true;
      return ApiResult.ok(valid);
    } catch (e) {
      debugPrint('[ShrineServerRepository] [verify-share] 예외 -> $e');
      return ApiResult.fail('검증 중 오류가 발생했어요: $e');
    }
  }
}
