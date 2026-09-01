import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/guinji/presentation/guinji_map_guest_join_screen.dart';
import 'app_navigator_key.dart';

/// [귀인지도 딥링크 버그수정 — Phase A] `fortunefusion://g/{token}` 커스텀
/// URI 스킴으로 앱이 열렸을 때(콜드 스타트/백그라운드 복귀 모두) 게스트
/// 참여+입력 화면([GuinjiMapGuestJoinScreen])으로 이동시키는 전역 리스너.
///
/// [배경] `AndroidManifest.xml`에 이 스킴에 대한 intent-filter를 등록해도,
/// Flutter 쪽에서 실제로 그 링크를 "수신"해서 라우팅하는 코드가 없으면
/// 아무 일도 일어나지 않는다(OS가 앱을 실행만 시켜줄 뿐, 어떤 화면을 보여줄지는
/// 앱이 직접 처리해야 함). `app_links` 패키지가 이 수신 역할을 담당한다.
///
/// [기존 `/g/{token}` named route 파싱(app_router.dart)과의 관계] 그 로직은
/// Flutter 앱 *내부*에서 이미 실행 중인 상태로 `Navigator.pushNamed('/g/xxx')`
/// 같은 호출이 발생했을 때만 동작하는 것으로, OS 레벨 딥링크 수신과는 완전히
/// 별개다. 이 핸들러가 "실제 OS가 앱을 열어준" 이벤트를 받아 그 토큰을 꺼내
/// [GuinjiMapGuestJoinScreen]으로 직접 push한다.
///
/// [2026 디자인 핸드오프 — 로그인-필요 GuinjiJoinScreen에서 교체됨] 과거
/// 이 핸들러는 로그인을 요구하는 `GuinjiJoinScreen`으로 이동시켰으나,
/// 바이럴 게스트 절대 원칙(회원가입 불필요 + 웹 완결 경험)을 만족시키기
/// 위해 인증이 필요 없는 `joinAnonymous` 기반 화면으로 전환했다.
/// `GuinjiJoinScreen`(로그인 필요, 지인 참여 전용) 자체는 삭제하지 않고
/// 보존한다 — 이 딥링크의 대상에서만 제외될 뿐이다.
class GuinjiDeepLinkHandler {
  GuinjiDeepLinkHandler._();

  static final AppLinks _appLinks = AppLinks();

  /// 앱 시작 시(`main.dart` 또는 `App.initState`) 1회 호출한다. 콜드 스타트
  /// 시점의 초기 링크(`getInitialLink`)와, 앱이 이미 떠 있는 상태에서 다시
  /// 딥링크로 열린 경우(`uriLinkStream`)를 모두 처리한다.
  static Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GuinjiDeepLinkHandler] 초기 링크 조회 실패: $e');
      }
    }

    _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('[GuinjiDeepLinkHandler] 스트림 오류: $e');
        }
      },
    );
  }

  /// 두 가지 형태를 처리한다:
  ///   1) `fortunefusion://g/{token}` — 커스텀 스킴(host가 'g').
  ///      pathSegments[0]이 곧 token.
  ///   2) `https://sintong.kr/g/{token}` — [Phase B] 운영 도메인 App Links.
  ///      pathSegments가 ['g', token] 형태(호스트가 도메인이라 'g'가 첫
  ///      경로 세그먼트로 들어옴)이므로 인덱스가 다르다.
  /// 그 외 스킴/호스트는 이 앱이 아직 사용하지 않으므로 무시한다.
  static void _handleUri(Uri uri) {
    String? token;

    if (uri.scheme == 'fortunefusion' && uri.host == 'g') {
      // fortunefusion://g/{token} → path가 '/{token}', pathSegments[0]이 token.
      final segments = uri.pathSegments;
      token = segments.isNotEmpty ? segments.first : null;
    } else if (uri.scheme == 'https' &&
        uri.host == 'sintong.kr' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'g') {
      // https://sintong.kr/g/{token} → pathSegments가 ['g', token].
      token = uri.pathSegments[1];
    } else {
      return;
    }

    if (token == null || token.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = appNavigatorKey.currentState;
      if (navState == null) return;
      navState.push(
        MaterialPageRoute(
          builder: (_) => GuinjiMapGuestJoinScreen(token: token!),
        ),
      );
    });
  }
}
