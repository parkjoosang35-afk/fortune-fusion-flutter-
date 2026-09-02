import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/guinji/presentation/guinji_map_guest_join_screen.dart';
import '../../features/home/domain/jeontong_eighty_matrix.dart';
import 'app_navigator_key.dart';
import 'app_router.dart';

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
///
/// [귀인지도 바이럴 랜딩 - ServiceGrid 신설] 바이럴 랜딩페이지
/// (admin_web `/g/[token]`)에 "소원방/타로/정통사주/오늘의 운세" 4개
/// 카드를 추가하면서, 각 카드가 "즉시 이동"하도록 신규 스킴
/// `fortunefusion://svc/{key}` (및 `https://sintong.kr/svc/{key}`)를
/// 함께 처리한다. key → 실제 Flutter named route 매핑은
/// [_serviceRouteFor]에 있다. `/g/{token}`(게스트 참여) 흐름과는
/// 완전히 독립적인 별도 host이므로 서로 간섭하지 않는다.
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
  ///   3) `fortunefusion://svc/{key}` / `https://sintong.kr/svc/{key}` —
  ///      [ServiceGrid 신설] 바이럴 랜딩페이지의 소원방/타로/정통사주/
  ///      오늘의 운세 카드. key는 [_serviceRouteFor]가 실제 named route로
  ///      변환한다.
  /// 그 외 스킴/호스트는 이 앱이 아직 사용하지 않으므로 무시한다.
  static void _handleUri(Uri uri) {
    // ── 1)+2) 게스트 참여(`g`) ──────────────────────────────────────
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
    }

    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navState = appNavigatorKey.currentState;
        if (navState == null) return;
        navState.push(
          MaterialPageRoute(
            builder: (_) => GuinjiMapGuestJoinScreen(token: token!),
          ),
        );
      });
      return;
    }

    // ── 3) ServiceGrid(`svc`) ───────────────────────────────────────
    String? serviceKey;
    if (uri.scheme == 'fortunefusion' && uri.host == 'svc') {
      // fortunefusion://svc/{key} → pathSegments[0]이 key.
      final segments = uri.pathSegments;
      serviceKey = segments.isNotEmpty ? segments.first : null;
    } else if (uri.scheme == 'https' &&
        uri.host == 'sintong.kr' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'svc') {
      // https://sintong.kr/svc/{key} → pathSegments가 ['svc', key].
      serviceKey = uri.pathSegments[1];
    }

    if (serviceKey == null || serviceKey.isEmpty) return;
    final routeName = _serviceRouteFor(serviceKey);
    if (routeName == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = appNavigatorKey.currentState;
      if (navState == null) return;
      navState.pushNamed(routeName);
    });
  }

  /// [ServiceGrid 신설] 바이럴 랜딩페이지 카드 key → 실제 Flutter named
  /// route 매핑. 각 목적지는 이미 존재하는 정상 진입점과 동일한 라우트를
  /// 그대로 재사용한다(신규 화면을 만들지 않음):
  ///   - `wish-room`  → `/wish-room`(소원방 게이트, home_screen과 동일)
  ///   - `tarot`      → [AppRouter.tarotIntroRoute](타로 인트로 스플래시,
  ///                    home_screen 진입점과 동일)
  ///   - `jeontong`   → [JeontongEightyMatrix.gateRoute](정통사주 부적
  ///                    게이트, home_screen "정통사주" 카드와 동일)
  ///   - `today`      → 오늘의 운세는 2026-08-13 결정으로 정통사주
  ///                    80항목에 통합되었으므로(RemovedDailyFortuneStub
  ///                    참고) 동일하게 정통사주 게이트로 보낸다.
  static String? _serviceRouteFor(String key) {
    switch (key) {
      case 'wish-room':
        return '/wish-room';
      case 'tarot':
        return AppRouter.tarotIntroRoute;
      case 'jeontong':
      case 'today':
        return JeontongEightyMatrix.gateRoute;
      default:
        return null;
    }
  }
}
