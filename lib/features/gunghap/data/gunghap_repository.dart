import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// [긴급 검수 지시 §4 — Flutter UX 보완]
///
/// 기존 코드는 모든 예외를 `ApiResult.fail('...중 오류가 발생했습니다: $e')`
/// 형태로 처리해, `ClientException: Failed to fetch, uri=...` 같은 원시
/// Dart/브라우저 예외 문자열이 그대로 사용자 화면(AppToast)에 노출되는
/// 문제가 있었다(2026-11-03 운영 서버 궁합지도 API 404 감사 과정에서 발견).
///
/// 이 헬퍼는 "서버에 요청 자체가 도달하지 못한" 네트워크/연결 계층
/// 예외(DNS 실패, 연결 거부, CORS 차단으로 인한 fetch 실패, 타임아웃 등)를
/// 감지해 깨끗한 한국어 메시지 + 전용 에러코드(`NETWORK_ERROR`)로 치환한다.
/// 그 외 예외(JSON 파싱 실패 등 서버는 응답했으나 처리 중 발생한 문제)는
/// 기존처럼 맥락별 메시지를 유지하되, 원시 예외 텍스트는 노출하지 않는다.
///
/// [분류 근거] `package:http`는 웹에서 fetch 실패 시
/// `http.ClientException`을, 네이티브(Android)에서는 `SocketException`을
/// 던진다. `.timeout()`은 `TimeoutException`을 던진다. 세 가지 모두
/// "서비스 연결이 원활하지 않습니다" 범주로 묶는다.
ApiResult<T> gunghapNetworkOrGenericFailure<T>(
  Object e,
  String contextMessage,
) {
  final isNetworkFailure =
      e is http.ClientException ||
      e is SocketException ||
      e is TimeoutException;
  debugPrint('[GunghapRepository] 예외 발생 (network=$isNetworkFailure) -> $e');
  if (isNetworkFailure) {
    return ApiResult.fail('서비스 연결이 원활하지 않습니다.', code: 'NETWORK_ERROR');
  }
  return ApiResult.fail(contextMessage, code: 'UNKNOWN_ERROR');
}

/// 궁합지도(Gunghap Map) — 백엔드 5개 공개 API 대응 Repository.
///
/// [백엔드 대응 — admin_web `src/app/api/public/gunghap/*`]
/// - `POST /api/public/gunghap/invites` → [createInvite] (인증 필요)
/// - `GET  /api/public/gunghap/g/{token}` → [fetchInviteToken] (인증 불필요)
/// - `POST /api/public/gunghap/g/{token}/join` → [joinAnonymous] (인증 불필요)
/// - `GET  /api/public/gunghap/results/{resultId}` → [fetchResult] (인증 필요, 소유자 전용)
/// - `POST /api/public/gunghap/results/{resultId}/unlock` → [unlock] (인증 필요, 소유자 전용)
///
/// [guinji_repository.dart와 동일한 패턴] 이 Repository는 귀인지도
/// `GuinjiRepository`와 완전히 동일한 구조(ApiResult 래핑, authHeader
/// 선택적 주입, 15초 타임아웃, statusCode/`success` 이중 체크)를 따른다
/// — §6 "기존 귀인지도 엔진의 검증된 기능을 분석하여 재사용한다" 원칙에
/// 따라 새로운 통신 패턴을 발명하지 않는다.
///
/// [절대 원칙 — 바이럴 게스트] [fetchInviteToken]과 [joinAnonymous]는
/// 절대 [AuthTokenStore.authHeader]를 호출하지 않는다(백엔드가 이 두
/// 라우트는 `requireUser` 없이 익명으로 열어뒀기 때문 — 초대 발송자가
/// 상대방의 생년월일을 미리 알 필요가 없는 구조를 유지하는 핵심 축).
/// 반대로 [createInvite]/[fetchResult]/[unlock]은 항상
/// [AuthTokenStore.authHeader]를 포함한다(백엔드 `requireUser` 강제).
class GunghapRepository {
  /// POST /gunghap/invites — 초대장 생성(초대자 본인 인증 필수).
  ///
  /// [중요] 이 엔드포인트는 상대방(게스트)의 어떠한 정보도 입력받지
  /// 않는다 — body에는 초대자 본인의 `saju`만 담긴다.
  ///
  /// 반환: {inviteId, token, sharePath}
  Future<ApiResult<Map<String, dynamic>>> createInvite({
    String? ownerName,
    required Map<String, dynamic> saju,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/invites',
    );
    debugPrint('[GunghapRepository] [createInvite] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
            body: jsonEncode({
              if (ownerName != null) 'ownerName': ownerName,
              'saju': saju,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GunghapRepository] [createInvite] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '초대장 생성에 실패했습니다.';
        debugPrint('[GunghapRepository] [createInvite] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '초대장을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  /// GET /gunghap/g/{token} — 초대 토큰 유효성 확인(게스트 딥링크 진입 시
  /// 최초 호출, 인증 불필요).
  ///
  /// 반환: {ownerName, joined, resultId}
  Future<ApiResult<Map<String, dynamic>>> fetchInviteToken(String token) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/g/$token',
    );
    debugPrint('[GunghapRepository] [fetchInviteToken] 요청 -> $uri (인증 헤더 없음)');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '초대 링크를 확인할 수 없습니다.';
        debugPrint('[GunghapRepository] [fetchInviteToken] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '초대 링크를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  /// POST /gunghap/g/{token}/join — 게스트(비로그인) 본인 사주정보 제출.
  ///
  /// [절대 원칙] 이 메서드는 [AuthTokenStore.authHeader]를 절대 사용하지
  /// 않는다 — 회원가입 없이 제출 즉시 궁합 결과(무료 등급)가 나온다
  /// (admin_web `g/[token]/join/route.ts` 참고 — 실제 만세력 계산은
  /// 서버가 수행, idempotent).
  ///
  /// 반환: {resultId, ownerName, guestName, relationType, relationTypeLabel,
  /// relationTypeDesc, chemistryScore, grade, gradeCode, timeUnknown,
  /// dayMasterKr, dayMasterElement, categories: [{categoryId, grade,
  /// gradeCode}] (8개, 무료 등급만), unlockCost, joined:true}
  Future<ApiResult<Map<String, dynamic>>> joinAnonymous({
    required String token,
    required String name,
    required String birthDate, // 'YYYY-MM-DD'
    String calendarType = 'solar', // 'solar' | 'lunar'
    bool isLeapMonth = false, // calendarType == 'lunar'일 때만 유효
    String? birthTime, // 'HH:mm' | null (모르면 null)
    required String gender, // 'male' | 'female'
    required bool agreePolicy,
    required bool agreeAge14,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/g/$token/join',
    );
    debugPrint('[GunghapRepository] [joinAnonymous] 요청 -> $uri (인증 헤더 없음)');

    try {
      // [주의] 여기서는 AuthTokenStore.authHeader()를 절대 호출하지 않는다.
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'birthDate': birthDate,
              'calendarType': calendarType,
              'isLeapMonth': isLeapMonth,
              'birthTime': birthTime,
              'gender': gender,
              'agreePolicy': agreePolicy,
              'agreeAge14': agreeAge14,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '제출에 실패했습니다.';
        debugPrint('[GunghapRepository] [joinAnonymous] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(e, '제출하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  /// GET /gunghap/results/{resultId} — 궁합 결과 조회(초대자 본인 인증
  /// 필수, 소유자 전용).
  ///
  /// 반환: {resultId, ownerName, guestName, relationType, relationTypeLabel,
  /// relationTypeDesc, chemistryScore, grade, gradeCode, categories (8개,
  /// 무료 등급만), unlocked, unlockCost, detail? (8개 전체 서술, unlocked일
  /// 때만)}
  Future<ApiResult<Map<String, dynamic>>> fetchResult(String resultId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/results/$resultId',
    );
    debugPrint('[GunghapRepository] [fetchResult] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .get(uri, headers: {'Accept': 'application/json', ...authHeader})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GunghapRepository] [fetchResult] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합 결과 조회에 실패했습니다.';
        debugPrint('[GunghapRepository] [fetchResult] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '궁합 결과를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  /// POST /gunghap/results/{resultId}/unlock — 상세 보고서 잠금해제
  /// (100 복주머니 차감, 초대자 본인 인증 필수, 멱등).
  ///
  /// [절대 원칙] 실제 차감은 서버 트랜잭션(`spendLuckPouch`) 내부에서만
  /// 발생한다 — 이 Repository는 요청/결과 조회만 수행한다. 이미 해금한
  /// 결과를 다시 호출해도 서버가 `alreadyUnlocked:true, amountCharged:0`로
  /// 응답해 중복 차감이 발생하지 않는다.
  ///
  /// 반환: {unlocked:true, alreadyUnlocked, amountCharged, balanceAfter?,
  /// detail: [8개, {categoryId, grade, relationshipFeature, strength,
  /// conflictRisk, improvement}]}
  Future<ApiResult<Map<String, dynamic>>> unlock(String resultId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/results/$resultId/unlock',
    );
    debugPrint('[GunghapRepository] [unlock] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GunghapRepository] [unlock] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '잠금해제에 실패했습니다.';
        debugPrint('[GunghapRepository] [unlock] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '잠금해제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }
}
