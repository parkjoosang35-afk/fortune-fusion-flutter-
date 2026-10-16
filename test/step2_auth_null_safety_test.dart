// [엔진 통합 STEP 2 검증] AuthTokenStore.getCurrentUserId()가 비로그인 시
// fallbackUserId(=1)로 폴백하지 않고 명시적으로 null을 반환하는지,
// 로그인 후에는 실제 userId를 정확히 반환하는지, 그리고 HttpAuthGuard가
// 401 수신 시 로컬 세션을 정리(clear)하는지를 코드 레벨에서 검증한다.
//
// (실서버 sintong.kr에 대한 실로그인 E2E는 admin_web 측 회원가입 정책
// 설정 누락(COUNT_POLICY_REQUIRED)으로 현재 테스트 계정 생성이 막혀 있어
// curl 레벨 재현이 불가능했다 — 이는 Flutter 클라이언트 코드와 무관한
// admin_web 서버 설정 이슈다. 대신 서버가 비로그인 요청에 대해 정확히
// `401 + {"success":false,"error":"로그인이 필요합니다."}`를 반환하는 것은
// curl로 실측 확인했고, 클라이언트 쪽 "토큰 보유 여부에 따른 분기 로직"은
// 아래 단위 테스트로 검증한다.)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/auth/auth_token_store.dart';
import 'package:flutter_app/core/api/http_auth_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthTokenStore.clear();
  });

  group('STEP 2 — fallbackUserId 제거 검증', () {
    test('비로그인 상태에서 getCurrentUserId()는 null을 반환한다(과거: 1로 폴백)', () async {
      final userId = await AuthTokenStore.getCurrentUserId();
      expect(userId, isNull);
    });

    test('비로그인 상태에서 isLoggedIn()은 false다', () async {
      final loggedIn = await AuthTokenStore.isLoggedIn();
      expect(loggedIn, isFalse);
    });

    test('로그인 후(save) getCurrentUserId()는 실제 저장된 userId를 반환한다', () async {
      await AuthTokenStore.save(token: 'fake-jwt-token', userId: 42);
      final userId = await AuthTokenStore.getCurrentUserId();
      expect(userId, 42);
      expect(userId, isNot(1)); // 과거 fallbackUserId=1이 아님을 명시적으로 확인
    });

    test('로그인 후 authHeader()는 Bearer 토큰 헤더를 포함한다', () async {
      await AuthTokenStore.save(token: 'fake-jwt-token', userId: 42);
      final header = await AuthTokenStore.authHeader();
      expect(header['Authorization'], 'Bearer fake-jwt-token');
    });

    test('clear() 이후 getCurrentUserId()는 다시 null로 돌아간다', () async {
      await AuthTokenStore.save(token: 'fake-jwt-token', userId: 42);
      await AuthTokenStore.clear();
      final userId = await AuthTokenStore.getCurrentUserId();
      expect(userId, isNull);
    });
  });

  group('STEP 2 — HttpAuthGuard 공통 401 처리 지점 검증', () {
    test('isUnauthorized(401)는 true, 그 외 코드는 false', () {
      expect(HttpAuthGuard.isUnauthorized(401), isTrue);
      expect(HttpAuthGuard.isUnauthorized(200), isFalse);
      expect(HttpAuthGuard.isUnauthorized(403), isFalse);
      expect(HttpAuthGuard.isUnauthorized(500), isFalse);
    });

    test('handleUnauthorized()는 로컬 세션(토큰+userId)을 정리한다', () async {
      await AuthTokenStore.save(token: 'fake-jwt-token', userId: 42);
      expect(await AuthTokenStore.isLoggedIn(), isTrue);

      await HttpAuthGuard.handleUnauthorized(tag: 'test');

      expect(await AuthTokenStore.isLoggedIn(), isFalse);
      expect(await AuthTokenStore.getCurrentUserId(), isNull);
    });

    test('unauthorizedResult()는 세션을 정리하고 UNAUTHORIZED 코드의 실패 결과를 반환한다', () async {
      await AuthTokenStore.save(token: 'fake-jwt-token', userId: 42);

      final result = await HttpAuthGuard.unauthorizedResult<String>(
        tag: 'test',
        message: '로그인이 필요합니다.',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'UNAUTHORIZED');
      expect(result.errorMessage, '로그인이 필요합니다.');
      // 부수효과로 세션도 정리됐는지 확인
      expect(await AuthTokenStore.isLoggedIn(), isFalse);
    });
  });
}
