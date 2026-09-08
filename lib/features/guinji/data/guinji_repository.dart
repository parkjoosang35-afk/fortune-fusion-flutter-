import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// 귀인지도(Guinji Map) — 백엔드 5개 공개 API 대응 Repository.
///
/// [백엔드 대응]
/// - `POST /api/public/guinji/maps` → [createMap]
/// - `GET  /api/public/guinji/maps/me` → [fetchMyMap]
/// - `POST /api/public/guinji/maps/{mapId}/members` → [joinMap]
/// - `GET  /api/public/guinji/g/{token}` → [fetchInvite]
/// - `POST /api/public/guinji/unlocks` → [unlock]
///
/// [attendance_repository.dart와의 차이] 이 5개 라우트는 모두 `requireUser`로
/// JWT 인증을 강제하므로(admin_web `_shared.ts`), 매 요청에
/// `AuthTokenStore.authHeader()`로 얻은 `Authorization: Bearer <token>`
/// 헤더를 반드시 포함한다(attendance는 `userId` 쿼리/바디만으로 인증 없이
/// 호출 가능한 구버전 패턴이라 다름 — 신규 API는 전부 인증 필수).
class GuinjiRepository {
  /// POST /guinji/maps — 내 귀인지도 생성(이미 있으면 기존 지도를 그대로 반환, 멱등).
  /// 반환: {mapId, token, isNew}
  Future<ApiResult<Map<String, dynamic>>> createMap({
    String? name,
    required Map<String, dynamic> saju,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/maps',
    );
    debugPrint('[GuinjiRepository] [createMap] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
            body: jsonEncode({if (name != null) 'name': name, 'saju': saju}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '지도 생성에 실패했습니다.';
        debugPrint('[GuinjiRepository] [createMap] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [createMap] 예외 -> $e');
      return ApiResult.fail('지도 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /guinji/maps/me — 내 지도 + 멤버 + 관계 목록 조회.
  /// 지도가 없으면 data:null인 채로 success:true를 반환한다(에러 아님).
  Future<ApiResult<Map<String, dynamic>?>> fetchMyMap() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/maps/me',
    );
    debugPrint('[GuinjiRepository] [fetchMyMap] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .get(uri, headers: {'Accept': 'application/json', ...authHeader})
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '지도 조회에 실패했습니다.';
        debugPrint('[GuinjiRepository] [fetchMyMap] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>?;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [fetchMyMap] 예외 -> $e');
      return ApiResult.fail('지도 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /guinji/maps/{mapId}/members — 지인(guest)이 자신의 사주로 지도에 참여.
  /// 반환: {memberId, relationship:{relationType, chemistryScore, ohaengEvidence}}
  Future<ApiResult<Map<String, dynamic>>> joinMap({
    required String mapId,
    required String name,
    required String solarLunar, // 'solar' | 'lunar'
    required String birthDate, // 'YYYY-MM-DD'
    String? birthTime, // 'HH:mm' | null
    required Map<String, dynamic> saju,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/maps/$mapId/members',
    );
    debugPrint('[GuinjiRepository] [joinMap] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
            body: jsonEncode({
              'name': name,
              'solarLunar': solarLunar,
              'birthDate': birthDate,
              'birthTime': birthTime,
              'saju': saju,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '참여에 실패했습니다.';
        debugPrint('[GuinjiRepository] [joinMap] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [joinMap] 예외 -> $e');
      return ApiResult.fail('참여 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /guinji/g/{token} — 초대 링크 유효성 확인(딥링크 진입 시 최초 호출).
  /// 반환: {mapId, ownerName, joined, expired}
  /// [주의] 404 응답도 body에 `code`(NOT_FOUND|EXPIRED)가 담겨 있으므로
  /// statusCode만으로 판단하지 않고 항상 body를 파싱해 errorCode로 넘긴다.
  ///
  /// [버그 수정 — 딥링크 비로그인 진입] 백엔드(`_shared.ts` requireUser)는
  /// 귀인지도 전 API에 로그인을 강제하므로, 카톡 등으로 공유 링크를 받은
  /// 지인이 앱에 로그인하지 않은 상태로 딥링크에 진입하면 이 API가 401을
  /// 반환한다. 이전에는 이 401도 다른 에러(NOT_FOUND/EXPIRED)와 동일하게
  /// "초대 링크를 확인할 수 없습니다"로 뭉뚱그려져, 정작 가장 흔한 진입
  /// 경로(비로그인 지인의 최초 클릭)에서 사용자가 로그인 화면으로 안내받지
  /// 못하고 막다른 길에 갇히는 문제가 있었다. statusCode==401을 명시적으로
  /// `UNAUTHORIZED` 코드로 구분해 반환하고, 호출부(GuinjiJoinScreen)가 이
  /// 코드를 보고 로그인 유도 흐름으로 분기하도록 한다.
  Future<ApiResult<Map<String, dynamic>>> fetchInvite(String token) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/g/$token',
    );
    debugPrint('[GuinjiRepository] [fetchInvite] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .get(uri, headers: {'Accept': 'application/json', ...authHeader})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        debugPrint('[GuinjiRepository] [fetchInvite] 401 -> 로그인 필요');
        return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '초대 링크를 확인할 수 없습니다.';
        debugPrint('[GuinjiRepository] [fetchInvite] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [fetchInvite] 예외 -> $e');
      return ApiResult.fail('초대 링크 확인 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /guinji/g/{token}/join — 게스트(비로그인) 웹 참여.
  ///
  /// [바이럴 게스트 원칙 — 절대] 이 메서드는 [AuthTokenStore.authHeader]를
  /// 절대 사용하지 않는다. 카톡 등으로 초대 링크를 받은 지인이 회원가입 없이
  /// 웹에서 이름·생년월일만 입력하면 그 자리에서 (1) 관계 결과가 나오고
  /// (2) 실제로 지도에 반영된다(admin_web `g/[token]/join/route.ts` 참고 —
  /// 로그인 불필요, DB 실저장, idempotent). 포인트는 지급되지 않는다.
  ///
  /// 반환: {ownerName, relationType, chemistryScore, timeUnknown,
  /// dayMasterKr, dayMasterElement, joined:true, mapSummary:{total,counts}}
  Future<ApiResult<Map<String, dynamic>>> joinAnonymous({
    required String token,
    required String name,
    required String birthDate, // 'YYYY-MM-DD'
    String calendarType = 'solar', // 'solar' | 'lunar'
    String? birthTime, // 'HH:mm' | null (모르면 null)
    required String gender, // 'male' | 'female'
    required bool agreePolicy,
    required bool agreeAge14,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/g/$token/join',
    );
    debugPrint('[GuinjiRepository] [joinAnonymous] 요청 -> $uri (인증 헤더 없음)');

    try {
      // [주의] 여기서는 AuthTokenStore.authHeader()를 절대 호출하지 않는다
      // (게스트 웹 참여는 로그인 상태와 완전히 무관해야 한다).
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'birthDate': birthDate,
              'calendarType': calendarType,
              'birthTime': birthTime,
              'gender': gender,
              'agreePolicy': agreePolicy,
              'agreeAge14': agreeAge14,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '참여에 실패했습니다.';
        debugPrint('[GuinjiRepository] [joinAnonymous] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [joinAnonymous] 예외 -> $e');
      return ApiResult.fail('참여 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /guinji/g/{token}/preview — 게스트가 지도에 실제로 참여(저장)하지
  /// 않고 관계 결과만 먼저 미리 본다(admin_web `g/[token]/preview/route.ts`
  /// 참고 — 인증 불필요, DB 미저장, 순수 계산). I(Input) 화면에서 "결과
  /// 먼저 보기" 같은 선택적 미리보기 UX에 사용할 수 있다.
  ///
  /// [바이럴 게스트 원칙] 이 메서드도 [AuthTokenStore.authHeader]를
  /// 사용하지 않는다.
  ///
  /// 반환: {ownerName, relationType, chemistryScore, isPreview:true,
  /// timeUnknown, dayMasterKr, dayMasterElement}
  Future<ApiResult<Map<String, dynamic>>> previewAnonymous({
    required String token,
    required String name,
    required String birthDate, // 'YYYY-MM-DD'
    String calendarType = 'solar',
    String? birthTime,
    required String gender,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/g/$token/preview',
    );
    debugPrint('[GuinjiRepository] [previewAnonymous] 요청 -> $uri (인증 헤더 없음)');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'birthDate': birthDate,
              'calendarType': calendarType,
              'birthTime': birthTime,
              'gender': gender,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '미리보기에 실패했습니다.';
        debugPrint('[GuinjiRepository] [previewAnonymous] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [previewAnonymous] 예외 -> $e');
      return ApiResult.fail('미리보기 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /guinji/g/{token}/relation-summary — 비식별 집계만 반환
  /// (admin_web `g/[token]/relation-summary/route.ts` 참고 — 인증 불필요,
  /// 개인정보 노출 없음). L(Landing) 화면의 "지금까지 이런 인연들이" 같은
  /// 통계 노출에 사용할 수 있다.
  ///
  /// 반환: {total, counts}
  Future<ApiResult<Map<String, dynamic>>> fetchRelationSummary(
    String token,
  ) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/g/$token/relation-summary',
    );
    debugPrint('[GuinjiRepository] [fetchRelationSummary] 요청 -> $uri (인증 헤더 없음)');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '통계 조회에 실패했습니다.';
        debugPrint('[GuinjiRepository] [fetchRelationSummary] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [fetchRelationSummary] 예외 -> $e');
      return ApiResult.fail('통계 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// DELETE /guinji/maps/{mapId}/members/{memberId} — 소유자가 잘못
  /// 입력된 멤버를 삭제(소프트 삭제)한다.
  ///
  /// [배경] 사용자가 격노하며 지적: "상대방이 생년월일을 잘못 넣거나
  /// 이름을 잘못 넣어서 귀인지도가 잘못 나올 때 삭제하는 게 없다" —
  /// 지도 소유자만 자기 지도의 멤버를 지울 수 있다(서버가
  /// `map.ownerId === auth.userId`를 확인, 타인의 지도는 403). 완전
  /// 삭제가 아니라 `GuinjiMapMember.status="removed"`로 바뀌는 소프트
  /// 삭제이며, 삭제 즉시 관계 집계·그래프에서도 제외된다.
  ///
  /// 반환: {alreadyRemoved: bool} — 이미 삭제된 멤버를 다시 호출해도
  /// 에러가 아니라 멱등하게 성공 처리된다(중복 클릭/재시도 안전).
  Future<ApiResult<Map<String, dynamic>>> deleteMember({
    required String mapId,
    required String memberId,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/maps/$mapId/members/$memberId',
    );
    debugPrint('[GuinjiRepository] [deleteMember] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .delete(uri, headers: {'Content-Type': 'application/json', ...authHeader})
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '삭제에 실패했습니다.';
        debugPrint('[GuinjiRepository] [deleteMember] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [deleteMember] 예외 -> $e');
      return ApiResult.fail('삭제 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /guinji/unlocks — 관계 상세의 스페셜 해설 해금(광고 또는 포인트).
  /// 반환: {unlocked: true, remainingToday}
  Future<ApiResult<Map<String, dynamic>>> unlock({
    required String memberId,
    required String method, // 'ad' | 'point'
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/guinji/unlocks',
    );
    debugPrint('[GuinjiRepository] [unlock] 요청 -> $uri ($method)');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
            body: jsonEncode({'memberId': memberId, 'method': method}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '해금에 실패했습니다.';
        debugPrint('[GuinjiRepository] [unlock] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[GuinjiRepository] [unlock] 예외 -> $e');
      return ApiResult.fail('해금 처리 중 오류가 발생했습니다: $e');
    }
  }
}
