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

/// 궁합지도(Gunghap Map) — 백엔드 8개 공개 API 대응 Repository.
///
/// [백엔드 대응 — admin_web `src/app/api/public/gunghap/*`]
/// - `POST /api/public/gunghap/invites` → [createInvite] (인증 필요)
/// - `GET  /api/public/gunghap/g/{token}` → [fetchInviteToken] (인증 불필요)
/// - `POST /api/public/gunghap/g/{token}/join` → [joinAnonymous] (인증 불필요)
/// - `GET  /api/public/gunghap/results/{resultId}` → [fetchResult] (인증 필요, 소유자 전용)
/// - `POST /api/public/gunghap/results/{resultId}/unlock` → [unlock] (인증 필요, 소유자 전용)
/// - `POST /api/public/gunghap/direct` → [createDirect] (인증 필요, Phase 4)
/// - `GET  /api/public/gunghap/my-results` → [fetchMyResults] (인증 필요, Phase 4)
/// - `DELETE /api/public/gunghap/results/{resultId}` → [deleteResult] (인증 필요, 소유자 전용, Phase 4)
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

  /// POST /gunghap/direct — 상대방에게 초대장을 보내지 않고 로그인 회원
  /// 본인이 직접 상대방 정보를 입력해 즉시 궁합 결과를 생성(인증 필수).
  ///
  /// [B안 비대칭 신뢰 구조] 호출자 본인의 사주는 [mySaju]로 이미 계산된
  /// `GuinjiSajuInput` 형태 JSON을 그대로 전달한다(초대장 생성과 동일하게
  /// 클라이언트가 [JeontongReportBuilder]로 미리 계산 — `GunghapProvider`
  /// 참고). 상대방 정보는 원본 그대로(`partner*` 필드) 전송하며, 서버가
  /// `calculateSaju()`로 상대방 사주를 계산한다 — 클라이언트는 상대방
  /// 사주를 계산하지 않는다.
  ///
  /// [멱등성 — requestKey] [requestKey]는 호출부(Provider)가 "확인" 버튼을
  /// 누를 때마다 새로 생성하는 세션 범위 UUID다. 동일 `requestKey` +
  /// 동일 로그인 사용자로 재호출(예: 네트워크 재시도)하면 서버가 기존
  /// 저장된 결과를 그대로 반환한다(`created:false`, 재계산/재생성 없음).
  /// 사용자가 "다시 입력해서 같은 상대를 또 조회"하는 의도적 재조회는
  /// 호출부가 새 `requestKey`를 생성해 전달하므로 항상 새 결과가
  /// 만들어진다 — 이 구분은 전적으로 requestKey 값 자체에 달려 있으며
  /// Repository는 그 값을 그대로 전달만 한다.
  ///
  /// [절대 금지] 이 메서드는 초대장을 생성하지 않는다 — `invites`
  /// 엔드포인트를 호출하지 않으며, 응답에도 `token`/`sharePath`가 없다.
  ///
  /// 반환: {resultId, resultType:'DIRECT', ownerName, guestName,
  /// relationType, relationTypeLabel, relationTypeDesc, chemistryScore,
  /// grade, gradeCode, timeUnknown, dayMasterKr, dayMasterElement,
  /// categories: [{categoryId, grade, gradeCode}] (8개, 무료 등급만),
  /// unlockCost, created}
  Future<ApiResult<Map<String, dynamic>>> createDirect({
    required String requestKey,
    required Map<String, dynamic> mySaju,
    String? myName,
    required String partnerName,
    required String partnerBirthDate, // 'YYYY-MM-DD'
    String partnerCalendarType = 'solar', // 'solar' | 'lunar'
    bool partnerIsLeapMonth = false, // calendarType == 'lunar'일 때만 유효
    String? partnerBirthTime, // 'HH:mm' | null (모르면 null)
    required String partnerGender, // 'male' | 'female'
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/direct',
    );
    debugPrint('[GunghapRepository] [createDirect] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
            body: jsonEncode({
              'requestKey': requestKey,
              'mySaju': mySaju,
              if (myName != null) 'myName': myName,
              'partnerName': partnerName,
              'partnerBirthDate': partnerBirthDate,
              'partnerCalendarType': partnerCalendarType,
              'partnerIsLeapMonth': partnerIsLeapMonth,
              'partnerBirthTime': partnerBirthTime,
              'partnerGender': partnerGender,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GunghapRepository] [createDirect] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합 생성에 실패했습니다.';
        debugPrint('[GunghapRepository] [createDirect] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '궁합을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  /// GET /gunghap/my-results — 궁합스토리: 로그인 회원 본인의 DIRECT +
  /// INVITE 궁합 결과를 모두 조회(인증 필수, 최신순 정렬은 서버가 수행).
  ///
  /// [절대 원칙] 이 메서드는 로컬 저장소나 하드코딩 데이터를 전혀 쓰지
  /// 않는다 — 서버 DB에 실제 저장된 결과만 반환한다.
  ///
  /// 반환: {items: [{resultId, resultType:'DIRECT'|'INVITE', ownerName,
  /// guestName, relationTypeLabel, grade, gradeCode, categoryCount,
  /// createdAt(ISO8601)}], total}
  ///
  /// [주의 — ownerName 항상 null인 DIRECT] DIRECT 결과는 `ownerName`이
  /// 항상 null이다(로그인 사용자 본인이 곧 owner라 별도 저장하지 않는
  /// 설계). "상대방 이름"은 resultType과 무관하게 항상 `guestName`을
  /// 사용해야 한다 — `ownerName`을 상대방 이름으로 오인해 쓰지 말 것.
  Future<ApiResult<Map<String, dynamic>>> fetchMyResults() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/my-results',
    );
    debugPrint('[GunghapRepository] [fetchMyResults] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .get(uri, headers: {'Accept': 'application/json', ...authHeader})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GunghapRepository] [fetchMyResults] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합스토리를 불러오지 못했습니다.';
        debugPrint('[GunghapRepository] [fetchMyResults] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '궁합스토리를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  /// DELETE /gunghap/results/{resultId} — 궁합 결과 소프트 삭제(인증 필수,
  /// 소유자 전용). DIRECT/INVITE 모두 동일 엔드포인트를 사용한다(서버가
  /// `resolveGunghapResultOwnerId()`로 소유자를 통합 판별).
  ///
  /// 실패 코드: 404 'NOT_FOUND'(이미 삭제됐거나 존재하지 않음), 403
  /// 'FORBIDDEN'(내가 만든 결과가 아님).
  ///
  /// 반환: {resultId, deleted:true}
  Future<ApiResult<Map<String, dynamic>>> deleteResult(String resultId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/gunghap/results/$resultId',
    );
    debugPrint('[GunghapRepository] [deleteResult] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .delete(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GunghapRepository] [deleteResult] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '삭제에 실패했습니다.';
        debugPrint('[GunghapRepository] [deleteResult] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      return gunghapNetworkOrGenericFailure(
        e,
        '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }
}
