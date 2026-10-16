import 'package:flutter/foundation.dart';

import '../auth/auth_token_store.dart';
import 'api_result.dart';

/// [신통방통 엔진 통합 — STEP 2 "28개 Repository 공통 401 처리 지점"]
///
/// 지금까지 각 Repository(`TarotRepository`/`FaceRepository`/`PalmRepository`/
/// `CompatibilityRepository`/`SajuRenewalApi` 등)는 401(토큰 만료/무효) 응답을
/// 서버가 내려준 일반 에러 메시지("~실패했습니다")와 구분하지 않고 그대로
/// 삼켰다. 그 결과 토큰이 만료돼도 사용자는 "분석에 실패했습니다"만 보고
/// 왜 실패했는지, 다시 로그인해야 하는지 알 수 없었다.
///
/// 이 클래스는 `AuthRepository.restoreSession()`이 이미 쓰고 있는
/// "401이면 로컬 세션을 정리하고 null/실패 반환" 패턴을 모든 Repository가
/// 공유할 수 있는 단일 지점으로 추출한 것이다. **리프레시 토큰은 도입하지
/// 않는다**(기존 과설계 방지 원칙 유지) — 401을 받으면 그냥 세션을 비우고
/// "로그인이 필요합니다"로 안내해 재로그인을 유도한다.
///
/// 사용법: 각 Repository가 http 응답을 받은 직후,
/// ```dart
/// if (HttpAuthGuard.isUnauthorized(response.statusCode)) {
///   await HttpAuthGuard.handleUnauthorized(tag: 'TarotRepository');
///   return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
/// }
/// ```
/// 형태로 호출한다(기존 에러 처리 분기보다 먼저 검사해야 한다).
class HttpAuthGuard {
  HttpAuthGuard._();

  static bool isUnauthorized(int statusCode) => statusCode == 401;

  /// 401을 받았을 때 공통으로 수행할 작업: 로컬에 저장된 (이미 무효가 된)
  /// 토큰/세션을 정리한다. 화면단 네비게이션(로그인 화면으로 이동)은 이
  /// 클래스의 책임이 아니다 — 각 화면이 `ApiResult.errorCode == 'UNAUTHORIZED'`를
  /// 보고 안내 문구를 띄우거나 로그인 화면으로 유도하는 것은 호출부의 몫으로
  /// 남겨둔다(Repository 계층이 Navigator를 알 필요가 없도록 — 계층 분리 원칙).
  static Future<void> handleUnauthorized({required String tag}) async {
    debugPrint('[HttpAuthGuard] [$tag] 401 수신 — 로컬 세션을 정리합니다.');
    await AuthTokenStore.clear();
  }

  /// 401 공통 처리 + 표준 실패 ApiResult를 한 번에 만들어주는 헬퍼.
  /// 각 Repository의 상태코드 분기에서 이 메서드만 호출하면 된다.
  static Future<ApiResult<T>> unauthorizedResult<T>({
    required String tag,
    String message = '로그인이 필요합니다.',
  }) async {
    await handleUnauthorized(tag: tag);
    return ApiResult.fail(message, code: 'UNAUTHORIZED');
  }
}
