import 'package:flutter/material.dart';
import 'app_shell.dart';
// [신당(神堂) 통합 — P1 검증용 임시 진입점] 하단바 5번째 탭 정식 등록은
// P6 범위이므로, 지금은 개발/웹 프리뷰 검증을 위해 '/shrine' 라우트만
// 추가한다(사용자 승인 작업순서: P1 구현 직후 analyze·프리뷰 검증 필요).
import '../../features/shrine/presentation/screens/shrine_entry_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/intro/presentation/onboarding_gate_screen.dart';
import '../../features/policy/presentation/policy_notice_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/fortune/shared/presentation/removed_daily_fortune_stub.dart';
import '../../features/mypage/presentation/my_fortune_records_screen.dart';
import '../../features/home/presentation/all_categories_screen.dart';
import '../../features/home/presentation/sintong_home_v2/fortune_engine_intro_screen.dart';
import '../../features/fortune/generic/presentation/generic_fortune_result_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_question_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_card_select_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_loading_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_result_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_history_screen.dart';
import '../../features/fortune/tarot/presentation/oz_home/oz_tarot_home_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_hub_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_intro_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_category_detail_screen.dart';
import '../../features/fortune/tarot/domain/tarot_category_model.dart';
import '../../features/fortune/face/presentation/face_capture_screen.dart';
import '../../features/fortune/face/presentation/face_analyzing_screen.dart';
import '../../features/fortune/face/presentation/face_reading_timeline_screen.dart';
import '../../features/fortune/face/presentation/face_result_screen.dart';
import '../../features/fortune/face/presentation/face_history_screen.dart';
import '../../features/fortune/shared/presentation/reading_archive_screen.dart';
import '../../features/fortune/palm/presentation/palm_capture_screen.dart';
import '../../features/fortune/palm/presentation/palm_analyzing_screen.dart';
import '../../features/fortune/palm/presentation/palm_reading_timeline_screen.dart';
import '../../features/fortune/palm/presentation/palm_result_screen.dart';
import '../../features/fortune/palm/presentation/palm_history_screen.dart';
import '../../features/name_fortune/presentation/name_fortune_input_screen.dart';
import '../../features/name_fortune/presentation/name_fortune_result_screen.dart';
// [궁합(C그룹) 복원] admin_web 실API 연동 화면 복원(git 53ce1ff).
import '../../features/compatibility/domain/compatibility_model.dart';
import '../../features/compatibility/presentation/compatibility_input_screen.dart';
import '../../features/compatibility/presentation/compatibility_result_screen.dart';
// [엔진 통합 지시문 STEP 3] 교차검증 결과 화면.
import '../orchestrator/presentation/cross_check_result_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/attendance/presentation/attendance_calendar_screen.dart';
import '../../features/mission/presentation/mission_screen.dart';
import '../../features/ranking/presentation/ranking_screen.dart';
import '../../features/notification/notifications_screen.dart';
import '../../features/mypage/presentation/settings_screen.dart';
import '../../features/luckybag/domain/luckybag_product_model.dart';
import '../../features/luckybag/domain/luckybag_reward_model.dart';
import '../../features/luckybag/presentation/luckybag_open_animation_screen.dart';
import '../../features/luckybag/presentation/luckybag_result_screen.dart';
import '../../features/luckybag/presentation/luckybag_history_screen.dart';
import '../../features/giftcard/presentation/giftcard_catalog_screen.dart';
import '../../features/giftcard/presentation/giftcard_detail_screen.dart';
import '../../features/giftcard/presentation/giftcard_result_screen.dart';
import '../../features/giftcard/presentation/my_giftcards_screen.dart';
import '../../features/giftcard/domain/giftcard_model.dart';
import '../../features/subscription/presentation/subscription_plans_screen.dart';
import '../../features/subscription/presentation/my_subscription_screen.dart';
import '../../features/wishroom/features/intro/wish_room_intro_screen.dart';
import '../../features/wishroom/features/link/link_invite_screen.dart';
import '../../features/shop/presentation/seal_shop_screen.dart';
import '../../features/shop/presentation/candle_shop_screen.dart';
import '../../features/shop/presentation/talisman_shop_screen.dart';
import '../../features/shop/presentation/treasure_box_screen.dart';
import '../../features/categories/presentation/categories_grid_screen.dart';
import '../../features/lucky/presentation/lucky_items_screen.dart';
import '../../features/pass/presentation/free_pass_gate_screen.dart';
import '../../features/home/domain/jeontong_eighty_matrix.dart';
import '../../features/guinji/presentation/guinji_map_screen.dart';
import '../../features/guinji/presentation/guinji_join_screen.dart';
import '../../features/guinji/presentation/guinji_ranking_screen.dart';
import '../../features/guinji/presentation/guinji_result_card_screen.dart';
import '../../features/guinji/presentation/guinji_share_screen.dart';
import '../../features/guinji/presentation/guinji_onboarding_screen.dart';
import '../../features/guinji/application/guinji_provider.dart';
// [2026 디자인 핸드오프 — Guinji Section.html 8화면 재구현]
// L·I·C·M·N·S·F·Y 8화면. 기존 `/guinji` 계열(온보딩→지도→공유→참여→
// 결과카드, 이미 실 API 연동 완료된 프로덕션 플로우)과는 완전히 별개의
// 데모/재구현 화면이므로, 파일명·클래스명·라우트 네임스페이스를 모두
// 분리한다(`/guinji-map/*`). 과거 세션에서 `guinji_share_screen.dart`
// 파일명이 겹쳐 프로덕션 공유 화면을 실수로 덮어쓴 사고가 있었으므로,
// 이 재구현 화면들은 절대 기존 파일명/클래스명을 재사용하지 않는다.
import '../../features/guinji/presentation/guinji_landing_screen.dart';
import '../../features/guinji/presentation/guinji_input_screen.dart';
import '../../features/guinji/presentation/guinji_calculating_screen.dart';
import '../../features/guinji/presentation/guinji_map_result_screen.dart';
import '../../features/guinji/presentation/guinji_map_share_screen.dart';
import '../../features/guinji/presentation/guinji_guest_result_screen.dart';
import '../../features/guinji/presentation/guinji_map_guest_join_screen.dart';
import '../../features/guinji/navigation/guinji_page_route.dart';
import 'global_bottom_nav_shell.dart';
// [귀인지도 기능 정리 — 관계상세/랭킹] `/guinji-map/*` 신규 디자인 톤으로
// 새로 만든 관계상세(N→상세)·랭킹 화면. M/F 화면에서 진입점으로 연결한다.
import '../../features/guinji/presentation/guinji_map_ranking_screen.dart';
// [결과 공유 기능 — sintong-share-proposal.pdf] `/r/{shareId}` 딥링크
// 도착 화면. `/g/{token}`(귀인지도 게스트 참여)과 동일한 패턴으로 named
// route 진입 전 별도 분기 처리한다(아래 참고).
import '../../features/share/presentation/shared_result_screen.dart';
// [신통방통 정통사주 리뉴얼] 유일한 신규 정통사주 화면. 죽은 saju_v3 및
// 기존 jeontong_eighty UI는 삭제되었으며, 구 라우트들은 모두 이 화면으로
// legacy redirect 처리된다.
import '../../features/saju_renewal/screens/saju_renewal_home_screen.dart';
import '../../features/saju_renewal/screens/saju_intro_screen.dart';
import '../../features/saju_renewal/navigation/saju_dimension_transition.dart';
// [복주머니 마케팅 쿠폰] QR 스캔/딥링크/수동입력 공용 흐름. `/g/`·`/r/`·
// `/w/`와 동일한 와일드카드 선매칭 패턴으로 `/coupon/{token}`을 처리한다.
import '../../features/bokju_coupon/presentation/bokju_coupon_resolve_screen.dart';
import '../../features/bokju_coupon/presentation/bokju_coupon_scan_screen.dart';
import '../../features/bokju_coupon/presentation/bokju_coupon_history_screen.dart';
import 'package:provider/provider.dart';
import 'app_navigator_key.dart';
import '../web/web_nav_bridge.dart';

/// 07단계 §3.2 라우팅 테이블 - Navigator 1.0(onGenerateRoute) 구현
/// 10단계(A안): AI 6대 기능(사주/타로/관상/손금/궁합/AI상담) + 리워드(미션/랭킹)까지
/// 전체 화면이 실제 구현되어 라우팅에 연결된 상태.
class AppRouter {
  AppRouter._();

  // [타로 섹션 전면 개편 §2] 신규 라우트 이름 상수. 화면 내부(홈/허브)에서
  // 문자열 리터럴을 중복 작성하지 않도록 여기서 단일 소스로 정의한다.
  // [엔진 통합 지시문 STEP 3] 교차검증 결과 화면 라우트.
  static const String crossCheckResultRoute = '/cross-check/result';
  static const String tarotHomeRoute = '/tarot/home';
  static const String tarotHubRoute = '/tarot/hub';
  static const String tarotCategoryDetailRoute = '/tarot/category';
  static const String tarotCardSelectRoute = '/tarot/card-select';
  // [타로 인트로 핸드오프 이식] "메인 타로섹션" 진입 시 타로 메인
  // (tarotHomeRoute) 직행 대신 먼저 거치는 5초(+2.6초 사전연출) 로딩 인트로.
  // 기존에 '/tarot/home'을 직접 가리키던 4개 진입점(홈 미니카드, 운세허브
  // 카드운세, 전체보기 트렌딩칩/대표카드)을 전부 이 라우트로 교체하고,
  // 이 화면 자신이 카운트다운 완료 시 tarotHomeRoute로 pushReplacementNamed
  // 한다(원본 README §동작요약 그대로: 인트로 → 타로 메인, replace로 뒤로가기
  // 시 인트로 재노출 방지).
  static const String tarotIntroRoute = '/tarot/intro';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // [PC 랜딩 연동 — 반대 방향 동기화] 앱 내부에서 어떤 라우트로든 이동할
    // 때마다(Navigator.pushNamed 등) 항상 이 함수가 그 settings.name으로
    // 호출되므로, 여기서 한 번 알려주면 모든 내부 네비게이션을 놓치지 않고
    // 포착할 수 있다. 기존 `_page()` 헬퍼가 만드는 MaterialPageRoute에는
    // settings가 안 실려 있어(NavigatorObserver로는 이름을 못 읽음) 이
    // 진입점에서 직접 전달하는 방식을 택했다. 웹이 아니거나 standalone
    // 실행이면 내부에서 조용히 no-op된다(web_nav_bridge.dart 참고).
    notifyRouteName(settings.name);
    // [2026 디자인 핸드오프 — 게스트 딥링크 이중 진입점 통합] named route
    // 이름이 '/g/{token}' 형태로 직접 전달되는 경우(웹 URL 진입, 그리고
    // `GuinjiDeepLinkHandler`가 수신한 OS 레벨 딥링크 모두 최종적으로 이
    // 경로를 통하도록 통일했다 — 아래 참고)를 처리한다.
    //
    // [배경 — 왜 로그인-필요 GuinjiJoinScreen에서 이 화면으로 교체했는가]
    // `Guinji Section.html` flow-map(2230~2245줄)이 명시한 게스트 라우트
    // 문자열이 정확히 `/g/:mapToken`이고, 사용자의 절대 원칙(바이럴 게스트는
    // 회원가입 없이 웹에서 완결된 경험을 해야 함)을 만족시키려면 이 경로가
    // 비로그인 화면([GuinjiMapGuestJoinScreen], `joinAnonymous` 기반)으로
    // 연결돼야 한다. 기존 `GuinjiJoinScreen`(로그인 필요, `joinMap` 기반)은
    // 완전히 별개의 지인 참여 플로우이며 이 경로로는 더 이상 도달하지
    // 않는다 — 그 화면 자체는 삭제하지 않고 보존하지만(향후 다른 진입점
    // 필요 시 재사용 가능), '/g/{token}' 딥링크의 대상에서는 제외한다.
    // `GuinjiDeepLinkHandler`(app_links 패키지, OS 레벨 커스텀 스킴/App
    // Links 수신)도 동일하게 이 화면으로 push하도록 함께 수정했다(해당
    // 파일 참고).
    //
    // 고정 케이스로 매칭되지 않는 '/g/{token}' 형태를 switch 진입 전에 먼저
    // 검사한다(Dart switch는 와일드카드 패턴을 지원하지 않으므로 별도 분기
    // 필요). 토큰이 없는 '/g' 또는 '/g/'만 들어오면 랜딩 화면으로 안전
    // 폴백한다.
    final name = settings.name ?? '';
    if (name == '/g' || name == '/g/') {
      return _page(const GuinjiLandingScreen());
    }
    if (name.startsWith('/g/')) {
      final token = name.substring('/g/'.length);
      if (token.isNotEmpty) {
        return _page(GuinjiMapGuestJoinScreen(token: token));
      }
    }

    // [결과 공유 기능 — sintong-share-proposal.pdf] '/r/{shareId}' 형태를
    // 처리한다. `GuinjiDeepLinkHandler`가 OS 레벨 딥링크(커스텀 스킴
    // `fortunefusion://r/{shareId}` 및 App Links `https://sintong.kr/r/{shareId}`)를
    // 수신했을 때도 최종적으로 이 named route를 통해 도달한다(위 '/g/'와
    // 동일한 이중 진입점 통합 패턴).
    if (name.startsWith('/r/')) {
      final shareId = name.substring('/r/'.length);
      if (shareId.isNotEmpty) {
        return _page(SharedResultScreen(shareId: shareId));
      }
    }

    // [소원방 v2.6] app2/capsule2.jsx › shell2.jsx의 `app.openLink(token)` →
    // `<LinkInvite token={invite}/>`에 대응하는 named route. 웹 원본은
    // `/w/{token}` 형태 공유 링크(shareLink() 로 발급)로 들어오면 이 화면이
    // GET /share/{token}(API_CONTRACT.md S2)으로 방을 조회해 초대장을 보여준다.
    // '/g/'·'/r/'과 동일한 패턴(와일드카드 선매칭)이며, OS 레벨 딥링크는
    // GuinjiDeepLinkHandler가 host 'w'를 수신해 이 named route로 위임한다.
    if (name.startsWith('/w/')) {
      final token = name.substring('/w/'.length);
      if (token.isNotEmpty) {
        return _page(LinkInviteScreen(token: token));
      }
    }

    // [복주머니 마케팅 쿠폰] `/coupon/{token}` — QR 딥링크(웹 URL 진입) 및
    // `GuinjiDeepLinkHandler`가 수신한 OS 레벨 딥링크(`fortunefusion://coupon/{token}`,
    // `https://sintong.kr/coupon/{token}`) 모두 최종적으로 이 경로를 통해
    // [BokjuCouponResolveScreen]으로 도달한다('/g/'·'/r/'·'/w/'와 동일한
    // 와일드카드 선매칭 패턴).
    if (name.startsWith('/coupon/')) {
      final token = name.substring('/coupon/'.length);
      if (token.isNotEmpty) {
        return _pageNamed('/coupon', BokjuCouponResolveScreen(token: token));
      }
    }

    switch (settings.name) {
      case '/splash':
        return _pageNamed('/splash', const SplashScreen());
      // [신당(神堂) 통합 — P1 검증용 임시 진입점. 정식 5번째 탭 연결은 P6.]
      case '/shrine':
        return _pageNamed('/shrine', const ShrineEntryScreen());
      // [인트로 전면 개편] 4단계 인트로(카드1/카드2/CTA) 페이저. 스플래시 이후
      // introSeen=false인 첫 실행 사용자에게만 노출된다.
      //
      // [온보딩 영상 적용 — 개발자 핸드오프 가이드 §4] 이 페이저 진입 전에
      // 5대 핵심기능 소개 영상(27초)을 먼저 보여줘야 하므로,
      // OnboardingGateScreen이 SharedPreferences(`has_seen_onboarding_v1`)
      // 기준으로 "영상 → 이 페이저" 또는 "바로 이 페이저"를 내부적으로
      // 분기한다(카드 인트로 자체의 introSeen 분기는 SplashScreen이 기존
      // 그대로 담당 — 이중 분기 로직이 아니라 한 단계 더 얹는 방식).
      case '/intro':
        return _pageNamed('/intro', const OnboardingGateScreen());
      // [6-5-D] 구 3페이지 온보딩(OnboardingScreen)은 신규 IntroPagerScreen이
      // 완전히 대체했고, 이 named route를 호출하는 코드가 앱 전체(딥링크 포함)
      // 어디에도 없음을 확인해 죽은 라우트만 제거한다. 화면 파일 자체
      // (onboarding_screen.dart)는 향후 참조 가능성을 배제할 수 없어 보존한다.
      case '/login':
        return _pageNamed('/login', const LoginScreen());
      case '/signup':
        return _pageNamed('/signup', const SignupScreen());
      // [2026 디자인 핸드오프 콘텐츠 반영] 인트로 페이지4 CTA 링크
      // `"재미·참고용" 콘텐츠 안내` 대상 라우트(핸드오프 §라우팅
      // onDisclaimerTap()과 동일한 경로 문자열).
      case '/policy/notice':
        return _pageNamed('/policy/notice', const PolicyNoticeScreen());

      case '/home':
        // [하단바 통일 작업] 정통사주/타로/소원방/귀인지도 등 AppShell
        // 바깥의 push 화면에 추가한 [MainBottomNavBar]가 특정 탭으로
        // 곧장 진입시키기 위해 int 인덱스를 arguments로 넘길 수 있다.
        // 기존처럼 arguments 없이 호출되면 그대로 0(홈)으로 시작한다.
        final homeArgs = settings.arguments;
        return _page(AppShell(initialIndex: homeArgs is int ? homeArgs : 0));

      // [귀인지도 Phase G-1: 라우트 스캐폴딩] 홈 배너 캐러셀 Slide 1
      // ("귀인지도") CTA의 진입점. 신통방통_귀인지도_최종_개발계획서_v2.0.md
      // §1은 `/guinji`(첫 진입 시 온보딩, 재방문 시 지도)를 요구하지만, 이
      // Phase에서는 온보딩 화면 1개만 우선 연결한다(재방문 분기·지도 화면은
      // 후속 Phase). go_router가 아닌 기존 Navigator(onGenerateRoute) 관례를
      // 그대로 따른다.
      case '/guinji':
        return _pageNamed('/guinji', const GuinjiOnboardingScreen());
      // [Phase G-3] 지도 메인(S5) — 참여자가 1명 이상 생겼을 때의 코어
      // 화면. 백엔드 API가 아직 없어 실제 진입 흐름(참여 발생 시 자동
      // 전환)은 연결되어 있지 않고, 현재는 빈지도(S4) 화면의 임시 데모
      // 링크로만 접근 가능하다(§검토용, 후속 Phase에서 실데이터 연동).
      case '/guinji/map':
        return _pageNamed('/guinji/map', const GuinjiMapScreen());
      // [Phase G-6] 공유(S8) — 지도메인/빈지도의 초대 CTA에서 이동한다.
      case '/guinji/share':
        return _pageNamed('/guinji/share', const GuinjiShareScreen());
      // [Phase G-7] 지인 참여(S9) — 지인이 초대 링크로 들어와 자신의
      // 사주를 입력하는 화면. 실제 딥링크 파라미터(초대자 ID 등)는
      // 백엔드 §5 완성 후 연결한다.
      case '/guinji/join':
        return _pageNamed('/guinji/join', const GuinjiJoinScreen());
      // [Phase G-8] 결과 카드(S10) — 랭킹(S7)의 "결과 카드로 공유하기"
      // CTA에서 이동한다. 10화면 로드맵의 마지막 화면.
      case '/guinji/result-card':
        return _pageNamed(
          '/guinji/result-card',
          const GuinjiResultCardScreen(),
        );
      // [귀인지도 실구현 — 딥링크/랭킹 라우트 등록] 이전까지 랭킹(S7)은
      // 지도메인(S5) 내부에서 `people`을 직접 전달받는 MaterialPageRoute로만
      // push 가능해 named route(`/guinji/ranking`)가 없었다. 딥링크나 다른
      // 진입 경로에서도 접근할 수 있도록 전역 [GuinjiProvider]에서 people을
      // 직접 읽어오는 named route를 추가한다(지도메인 내부 push는 계속
      // 인자를 넘기는 기존 방식을 유지 — 회귀 없음, 이 라우트는 추가 진입점).
      case '/guinji/ranking':
        return _pageNamed(
          '/guinji/ranking',
          Builder(
            builder: (context) {
              final people = context.watch<GuinjiProvider>().people;
              return GuinjiRankingScreen(people: people);
            },
          ),
        );

      // ══════════════════════════════════════════════════════════════
      // [2026 디자인 핸드오프 — Guinji Section.html 8화면 재구현]
      // `/guinji-map/*` 네임스페이스. design_handoff_guinji_web/
      // "Guinji Section.html" `flow-map`(2230~2245줄)의 8화면(L·I·C·M·N·
      // S·F·Y)을 1:1로 재현한 신규 화면들이다. 기존 `/guinji` 계열
      // (온보딩→지도→공유→참여→결과카드, 이미 실 API 연동된 프로덕션
      // 플로우)과는 완전히 별개이며, 서로의 파일/클래스/라우트를 절대
      // 공유하지 않는다. 아직 GuinjiProvider의 실 API(joinAnonymous 등)
      // 연동 전 단계라 화면 간 이동은 고정 목데이터/네비게이션으로
      // 연결한다(후속 작업: 실데이터 연동).
      //
      //   /guinji-map            → L · Landing
      //   /guinji-map/new        → I · Input
      //   /guinji-map/calc       → C · Calculating
      //   /guinji-map/m          → M · My Map (탭 시 N 바텀시트)
      //   /guinji-map/m/share    → S · Share
      //   /guinji-map/m/friends  → F · Friend List
      //   /guinji-map/guest/result → Y · Guest Result
      // ══════════════════════════════════════════════════════════════
      case '/guinji-map':
        return _guinjiNamed('/guinji-map', const GuinjiLandingScreen());
      case '/guinji-map/new':
        return _guinjiNamed('/guinji-map/new', const GuinjiInputScreen());
      case '/guinji-map/calc':
        // [흐름 정합성] 이 라우트는 호스트가 I(입력)에서 자기 정보만 제출한
        // 직후(createMapWithInput 성공)에만 진입한다 — 아직 지인이 참여하지
        // 않아 "관계"가 존재하지 않으므로, 기본값(게스트 2인 관계 계산 문구)
        // 대신 "내 사주 계산" 전용 문구로 오버라이드한다. 게스트 참여 흐름
        // (guinji_map_guest_join_screen.dart)은 이 라우트를 타지 않고 직접
        // MaterialPageRoute로 push하므로 기본값(관계 계산 문구)이 그대로
        // 유지된다 — 회귀 없음.
        return _guinjiNamed(
          '/guinji-map/calc',
          GuinjiCalculatingScreen(
            title: '내 지도를\n펼치고 있어요',
            subtitle: '사주 여덟 글자를 읽는 중',
            onComplete: () => appNavigatorKey.currentState
                ?.pushReplacementNamed('/guinji-map/m'),
          ),
        );
      case '/guinji-map/m':
        return _guinjiNamed(
          '/guinji-map/m',
          Builder(
            builder: (context) {
              final provider = context.watch<GuinjiProvider>();
              return GuinjiMapResultScreen(
                ownerName: provider.mapName ?? '나',
                people: provider.people,
                // [흐름 정합성] I에서 실제 계산된 내 사주 요약을 M화면
                // "나는 어떤 사람인지" 카드에 전달한다. 아직 계산되지
                // 않았거나 SajuRules 미로드 시 null → 섹션 자동 숨김.
                ownerSajuSummary: provider.ownerSajuSummary,
                ownerFacePath: provider.ownerFacePath,
              );
            },
          ),
        );
      case '/guinji-map/m/share':
        return _guinjiNamed(
          '/guinji-map/m/share',
          Builder(
            builder: (context) {
              final provider = context.watch<GuinjiProvider>();
              return GuinjiMapShareScreen(
                ownerName: provider.mapName ?? '나',
                mapToken: provider.mapToken ?? '',
                joinedCount: provider.people.length,
                retentionGoal: provider.milestoneGoal ?? 3,
                milestoneReached: provider.milestoneReached,
                milestoneRewardPoint: provider.milestoneRewardPoint,
                onKakaoShare: () => shareGuinjiMapInvite(
                  context,
                  provider.mapToken,
                  target: GuinjiShareTarget.kakao,
                  hostName: provider.mapName,
                ),
                onSmsShare: () => shareGuinjiMapInvite(
                  context,
                  provider.mapToken,
                  target: GuinjiShareTarget.sms,
                ),
                onMoreShare: () => shareGuinjiMapInvite(
                  context,
                  provider.mapToken,
                  target: GuinjiShareTarget.more,
                ),
              );
            },
          ),
        );
      // [핸드오프 §05-3 `RankScreen` 1:1 이식] "유형별 목록"은 랭킹
      // 화면의 두 번째 탭이다(기존 F화면과 통합) — 별도 화면이 아니므로
      // `/guinji-map/m/friends`는 랭킹 화면을 `initialTab: 1`로 열도록
      // 리다이렉트한다(구 라우트 경로 하위호환 유지).
      case '/guinji-map/m/friends':
        return _guinjiNamed(
          '/guinji-map/m/friends',
          Builder(
            builder: (context) {
              final provider = context.watch<GuinjiProvider>();
              return GuinjiMapRankingScreen(
                people: provider.people,
                ownerName: provider.mapName ?? '나',
                initialTab: 1,
                onMemberDelete: (person) async {
                  final ok = await provider.deleteMember(person.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error ?? '삭제에 실패했습니다.')),
                    );
                  }
                },
              );
            },
          ),
        );
      case '/guinji-map/m/ranking':
        // [귀인지도 기능 정리 — 랭킹] 신규 디자인 계열 최초의 랭킹
        // 진입점. 구계열(`/guinji/ranking`)과 동일하게 전역
        // [GuinjiProvider]에서 실제 people을 읽어 전달한다.
        return _guinjiNamed(
          '/guinji-map/m/ranking',
          Builder(
            builder: (context) {
              final provider = context.watch<GuinjiProvider>();
              return GuinjiMapRankingScreen(
                people: provider.people,
                ownerName: provider.mapName ?? '나',
                onMemberDelete: (person) async {
                  final ok = await provider.deleteMember(person.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error ?? '삭제에 실패했습니다.')),
                    );
                  }
                },
              );
            },
          ),
        );
      case '/guinji-map/guest/result':
        return _guinjiNamed(
          '/guinji-map/guest/result',
          const GuinjiGuestResultScreen(
            hostName: '지민',
            relationKey: 'CHEON_GWII',
            score: 92,
          ),
        );
      // [오늘의 운세 표준 플로우] 기존 진입점(홈 카드/전체보기 등)은 그대로
      // 두고, 새 4단계 플로우의 진입 화면(intro)으로 라우팅한다.
      case '/home/daily-fortune-detail':
      case '/fortune/today/intro':
        return _pageNamed(
          '/fortune/today/intro',
          const RemovedDailyFortuneStub(),
        );
      case '/fortune/today/input':
        return _pageNamed(
          '/fortune/today/input',
          const RemovedDailyFortuneStub(),
        );
      case '/fortune/today/loading':
        return _pageNamed(
          '/fortune/today/loading',
          const RemovedDailyFortuneStub(),
        );
      case '/fortune/today/result':
        return _pageNamed(
          '/fortune/today/result',
          const RemovedDailyFortuneStub(),
        );
      case '/home/all-categories':
        return _pageNamed('/home/all-categories', const AllCategoriesScreen());

      // [신통방통 메인 "전체보기" → "운세 엔진" 교체] 하단 시트 헤더
      // 버튼이 이 라우트로 이동한다(sintong_v2_sheet.dart). 기존
      // '/home/all-categories' 라우트/화면은 다른 진입점
      // (generic_fortune_result_screen.dart 등)이 여전히 참조하므로
      // 삭제하지 않고 그대로 둔다 — 이 라우트는 완전히 신규로 추가.
      case '/home/fortune-engine':
        return _pageNamed(
          '/home/fortune-engine',
          const FortuneEngineIntroScreen(),
        );

      // ── [신규 화면 3개] 80종 전체 보기 / 개운 아이템 / 프리패스 안내 ──
      // 기존 55개 case는 순서·내용 변경 없이 그대로 두고, 이 3개만 삽입한다.
      case '/categories-grid':
        return _pageNamed('/categories-grid', const CategoriesGridScreen());
      case '/lucky-items':
        return _pageNamed('/lucky-items', const LuckyItemsScreen());
      // [프리패스 진입 화면 개편 · DEV-2026-1011-01, 2026-10-11] §5.1
      // 전수조사 결과 이 라우트로 들어오는 진입점은 현재 코드베이스에
      // 없다(과거 유일한 진입점이었던 sintong_free_pass_bar.dart가
      // showPassRequiredSheet()[쿠팡파트너스 팝업] 직접 호출로 변경됨).
      // 라우트/화면 파일 자체는 삭제하지 않는다(리소스 정리는 별도 이슈).
      case '/free-pass-gate':
        return _pageNamed('/free-pass-gate', const FreePassGateScreen());

      // ── [신통방통 정통사주 리뉴얼 — 기존 메뉴/시스템 정리] 아래 구
      // 라우트들(기존 "정통사주 69종" jeontong_eighty UI + 죽은 베타
      // saju_v3)은 신규 정통사주(saju_renewal) 하나로 완전히 통합되어
      // 화면 자체는 삭제되었다. 과거 북마크/딥링크/
      // `PendingResultAccessReturn.returnRoute` 복귀값 등으로 구 경로가
      // 들어올 가능성이 있으므로, 깨지는 대신 안전하게 `/saju-renewal`로
      // 리다이렉트하는 legacy fallback만 유지한다.
      // (jeontong_eighty의 UI 레이어는 삭제되었지만, 귀인지도(guinji)가
      // 실제로 의존하는 계산 엔진·공유 값 객체 레이어 — manseryeok 엔진,
      // jeontong_eighty_matrix.dart의 JeontongCategoryEntry 타입,
      // jeontong_eighty_report_builder.dart의
      // buildProfileAndSajuResultViaPhase1to4() 등 — 는 그대로 보존됨)
      case JeontongEightyMatrix.browseRoute:
      case JeontongEightyMatrix.gateRoute:
      case JeontongEightyMatrix.loadingRoute:
      case JeontongEightyMatrix.resultRoute:
      case '/jeontong/input':
      case '/jeontong/eighty/grid':
      case '/saju/v3':
        return _pageNamed('/saju/v3', const SajuRenewalHomeScreen());

      case '/my/fortune-records':
        return _pageNamed(
          '/my/fortune-records',
          const MyFortuneRecordsScreen(),
        );

      // [신통방통 정통사주 리뉴얼 — STEP 6.5] Topic Engine 기반 신규 "사주
      // 이야기" 흐름 진입점. STEP1~6 백엔드(saju_engine_v3.3/topics-select/
      // interpret)는 무수정, 이 라우트는 그 결과를 소비하는 클라이언트
      // 화면(SajuRenewalHomeScreen)만 연결한다. 기존 saju_v3('/saju/v3',
      // 69종 그리드)와 완전히 별개이며 그 라우트/화면은 무수정.
      //
      // [디자인 핸드오프 00 셸 — 진입 전환] docs/03 §00 "진입 전환(300ms,
      // ease.dimension)": 셸 화면 위에 01 화면이 "탭 지점을 원점으로"
      // 원형 확산한다. 정통사주로 들어가는 진입점은 홈탭 칩/시트카드,
      // 운세탭 카드, 전체보기 그리드, 마이페이지, 딥링크 등 여러 곳에
      // 흩어져 있으므로(단일 "진입 카드" 하나가 아님), 각 호출부를 일일이
      // 고치지 않고 이 라우트 한 곳에서 전환을 공통 적용한다. 호출부가
      // `pushNamed('/saju-renewal', arguments: tapOffset)`처럼 탭 지점의
      // 전역 좌표(Offset)를 넘기면 그 지점에서, 넘기지 않으면(기존 호출부
      // 대부분) 문서가 명시한 기본값(가로 중앙, 세로 62%)에서 확산한다.
      // [v4 디자인 핸드오프 — 00-I 정통사주 인트로 삽입점] docs/03 §00-I
      // "노출: 정통사주 섹션 최초 진입 1회(영구 플래그 saju_intro_seen).
      // 이후 셸 카드 → 01 직행." — 원형 확산(M-01) 전환 자체는 항상
      // 동일하게 재생하고, 그 안에서 드러나는 화면만 [SajuEntryGate]가
      // 플래그를 보고 00-I/01로 분기한다(최초 1회는 00-I, 이후는 01).
      case '/saju-renewal':
        {
          final origin = settings.arguments is Offset
              ? settings.arguments as Offset
              : null;
          return sajuDimensionEnterRoute(
            (_) => const SajuEntryGate(),
            origin: origin,
          );
        }

      // ── [운섹션 87 카테고리 통합] 공용 결과 화면 ──
      // 전용 화면이 아직 없는 카테고리(K/V/O 일부/X/G/B/D/R)의 단일 진입점.
      // arguments로 카테고리 id(String, 예: 'K-001')를 전달한다.
      case '/fortune/category':
        return _pageNamed(
          '/fortune/category',
          GenericFortuneResultScreen(categoryId: settings.arguments as String?),
        );

      // ── 궁합 [궁합(C그룹) 신규 구현] ──
      // admin_web `/api/public/compatibility/*`는 이미 완전 구현되어
      // 있었으나(무료 정책까지 반영) Flutter 클라이언트가 없었다. 전체보기의
      // C그룹(7개) 항목이 여기로 딥링크된다. arguments로 CompatibilityType을
      // 전달하면 해당 유형이 미리 선택된다(없으면 기본 love).
      case '/compatibility/input':
        {
          final args = settings.arguments;
          final initialType = args is CompatibilityType ? args : null;
          final restoredInput = args is Map<String, dynamic>
              ? args['restoredInput'] as Map<String, dynamic>?
              : null;
          return _pageNamed(
            '/compatibility/input',
            CompatibilityInputScreen(
              initialType: initialType,
              restoredInput: restoredInput,
              resumeResultAccess:
                  args is Map<String, dynamic> &&
                  args['resumeResultAccess'] == true,
            ),
          );
        }
      case '/compatibility/result':
        return _pageNamed(
          '/compatibility/result',
          const CompatibilityResultScreen(),
        );

      // ── [엔진 통합 지시문 STEP 3] 교차검증 결과 화면. 사주/타로/관상/
      // 손금/궁합 결과화면 각각의 CTA에서 1탭으로 도달한다.
      case crossCheckResultRoute:
        return _pageNamed(
          crossCheckResultRoute,
          const CrossCheckResultScreen(),
        );

      // ── [신통방통 정통사주 리뉴얼 — 기존 AI 사주 정리] 기존 AI/LLM 기반
      // 사주(`lib/features/fortune/saju/`)는 완전히 제거되었다. 과거
      // 북마크, 마이페이지 "사주 히스토리", `PendingResultAccessReturn.
      // returnRoute` 등에 남아있을 수 있는 구 경로를 전부 안전하게
      // `/saju-renewal`로 리다이렉트한다(initialTopics/restoredInput 등
      // 구 인자는 더 이상 사용하지 않고 무시한다).
      case '/ai-fortune/saju/input':
      case '/ai-fortune/saju/loading':
      case '/ai-fortune/saju/result':
      case '/ai-fortune/saju/history':
        return _pageNamed(
          '/ai-fortune/saju/history',
          const SajuRenewalHomeScreen(),
        );

      // ── AI 타로 [타로 섹션 전면 개편 §2 신규 진입점] ──
      // ①타로 메인 홈. 기존 홈/운세탭의 진입점(/ai-fortune/tarot/question)은
      // 그대로 두고, 이 라우트가 새로운 "정문" 역할을 한다(P2 단계에서
      // 기존 진입점들을 이 라우트로 전환할 예정).
      case tarotHomeRoute:
        // [handoff-home 이식] 타로 메인 홈만 새 디자인(OzTarotHomeScreen)으로
        // 교체한다. 기존 [TarotHomeScreen] 위젯 자체는 [enterTarotCategory]
        // 공용 함수(화면02 TarotHubScreen이 참조)를 여전히 정의하고 있어
        // 파일을 삭제하지 않고 그대로 보존한다(다른 화면 영향 없음).
        return _pageNamed('/tarot/home', const OzTarotHomeScreen());
      // [타로 인트로 핸드오프 이식] 타로 메인 진입 직전 표시하는 스플래시.
      // 카운트다운 완료 시 이 화면 자신이 [tarotHomeRoute]로 이동한다.
      case tarotIntroRoute:
        return _pageNamed('/tarot/intro', const TarotIntroScreen());
      // ②서브 카테고리 허브. arguments로 TarotCategoryGroup을 받으면 해당
      // 그룹 칩이 선택된 상태로 시작하고, 없으면(직접 진입) 전체를 보여준다.
      case tarotHubRoute:
        return _pageNamed(
          '/tarot/hub',
          TarotHubScreen(
            initialGroup: settings.arguments is TarotCategoryGroup
                ? settings.arguments as TarotCategoryGroup
                : null,
            // [문제5 수정] 홈 배너('popular'/'new')에서 문자열 arguments로
            // 진입한 경우, 실제 인기/최신 카테고리만 필터링해 보여준다.
            specialFilter: settings.arguments is String
                ? settings.arguments as String
                : null,
          ),
        );
      // ③카테고리 상세 진입. arguments로 카테고리 id(String)를 받는다.
      case tarotCategoryDetailRoute:
        return _pageNamed(
          '/tarot/category',
          TarotCategoryDetailScreen(categoryId: settings.arguments as String?),
        );

      // ── AI 타로 (기존 플로우) ──
      case '/ai-fortune/tarot/question':
        {
          // [운세 카테고리 확장] 전체보기에서 관리자 카테고리(YES/NO,
          // 감정관계운 등)를 탭했을 때 {'initialSpreadType': ..,
          // 'initialTopic': ..} 형태의 인자로 딥링크된다. 없거나 형식이
          // 다르면 null로 전달되어 기존 기본 동작과 동일하다.
          final args = settings.arguments;
          String? initialSpreadType;
          String? initialTopic;
          if (args is Map) {
            initialSpreadType = args['initialSpreadType'] as String?;
            initialTopic = args['initialTopic'] as String?;
          }
          return _pageNamed(
            '/ai-fortune/tarot/question',
            TarotQuestionScreen(
              initialSpreadType: initialSpreadType,
              initialTopic: initialTopic,
            ),
          );
        }
      // ⑤ 카드 선택 화면(신규, §7 P2). 세션 컨트롤러의 상태머신을 그대로
      // UI로 옮긴 화면으로, 별도 인자 없이 전역 TarotSessionController
      // 상태만 참조한다.
      case tarotCardSelectRoute:
        return _pageNamed('/tarot/card-select', const TarotCardSelectScreen());
      case '/ai-fortune/tarot/loading':
        return _pageNamed(
          '/ai-fortune/tarot/loading',
          const TarotLoadingScreen(),
        );
      case '/ai-fortune/tarot/result':
        return _pageNamed(
          '/ai-fortune/tarot/result',
          TarotResultScreen(resultId: settings.arguments as String?),
        );
      case '/ai-fortune/tarot/history':
        return _pageNamed(
          '/ai-fortune/tarot/history',
          const TarotHistoryScreen(),
        );

      // ── AI 관상 ──
      case '/ai-fortune/face/capture':
        return _pageNamed(
          '/ai-fortune/face/capture',
          const FaceCaptureScreen(),
        );
      case '/ai-fortune/face/analyzing':
        return _pageNamed(
          '/ai-fortune/face/analyzing',
          const FaceAnalyzingScreen(),
        );
      // [v7 통합 — Option B] 분석 성공 직후 → 결과 화면 사이에 끼우는
      // 부위별 타이핑 리딩 화면. 히스토리 재열람 경로는 거치지 않는다.
      case '/ai-fortune/face/reading':
        return _pageNamed(
          '/ai-fortune/face/reading',
          const FaceReadingTimelineScreen(),
        );
      case '/ai-fortune/face/result':
        return _pageNamed(
          '/ai-fortune/face/result',
          FaceResultScreen(resultId: settings.arguments as String?),
        );
      case '/ai-fortune/face/history':
        return _pageNamed(
          '/ai-fortune/face/history',
          const FaceHistoryScreen(),
        );
      // [v7 통합] "풀이만 보관하고 나가기"로 쌓인 로컬 보관함(관상/손금 공용).
      case '/ai-fortune/reading-archive':
        return _pageNamed(
          '/ai-fortune/reading-archive',
          const ReadingArchiveScreen(),
        );

      // ── AI 손금 ──
      case '/ai-fortune/palm/capture':
        return _pageNamed(
          '/ai-fortune/palm/capture',
          const PalmCaptureScreen(),
        );
      case '/ai-fortune/palm/analyzing':
        return _pageNamed(
          '/ai-fortune/palm/analyzing',
          const PalmAnalyzingScreen(),
        );
      // [v7 통합 — Option B] face와 동일한 패턴.
      case '/ai-fortune/palm/reading':
        return _pageNamed(
          '/ai-fortune/palm/reading',
          const PalmReadingTimelineScreen(),
        );
      case '/ai-fortune/palm/result':
        return _pageNamed(
          '/ai-fortune/palm/result',
          PalmResultScreen(resultId: settings.arguments as String?),
        );
      case '/ai-fortune/palm/history':
        return _pageNamed(
          '/ai-fortune/palm/history',
          const PalmHistoryScreen(),
        );

      // ── 이름 운세(성명학) [운세 카테고리 확장 - 신규] ──
      case '/ai-fortune/name/input':
        {
          // [결과보기 통합 권한 시스템 v1.0, §7] 쿠팡 복귀 복원 흐름 —
          // saju/input과 동일한 패턴으로 {'restoredInput': {...}}를 받는다.
          final args = settings.arguments;
          Map<String, dynamic>? restoredInput;
          if (args is Map) {
            final restoredRaw = args['restoredInput'];
            if (restoredRaw is Map) {
              restoredInput = restoredRaw.cast<String, dynamic>();
            }
          }
          return _pageNamed(
            '/ai-fortune/name/input',
            NameFortuneInputScreen(restoredInput: restoredInput),
          );
        }
      case '/ai-fortune/name/result':
        return _pageNamed(
          '/ai-fortune/name/result',
          const NameFortuneResultScreen(),
        );

      // ── 리워드 ──
      case '/reward/wallet':
        return _pageNamed('/reward/wallet', const WalletScreen());
      case '/reward/attendance':
        // [복주머니 화면 재구성] 미션/복주머니열기/개봉이력 삭제 후
        // 출석체크만 남기면서 신설한 "이번 달 출석 달력" 화면.
        return _pageNamed(
          '/reward/attendance',
          const AttendanceCalendarScreen(),
        );
      case '/reward/missions':
        return _pageNamed('/reward/missions', const MissionScreen());
      case '/reward/ranking':
        return _pageNamed('/reward/ranking', const RankingScreen());
      case '/reward/luckybag/open':
        return _pageNamed(
          '/reward/luckybag/open',
          LuckyBagOpenAnimationScreen(
            product: settings.arguments as LuckyBagProductModel,
          ),
        );
      case '/reward/luckybag/result':
        final args = settings.arguments as Map<String, dynamic>;
        return _pageNamed(
          '/reward/luckybag/result',
          LuckyBagResultScreen(
            result: args['result'] as LuckyBagOpenResult,
            product: args['product'] as LuckyBagProductModel,
          ),
        );
      case '/reward/luckybag/history':
        return _pageNamed(
          '/reward/luckybag/history',
          const LuckyBagHistoryScreen(),
        );
      case '/reward/giftcard':
        return _pageNamed('/reward/giftcard', const GiftcardCatalogScreen());
      case '/reward/giftcard/detail':
        return _pageNamed(
          '/reward/giftcard/detail',
          GiftcardDetailScreen(
            product: settings.arguments as GiftcardProductModel,
          ),
        );
      case '/reward/giftcard/result':
        return _pageNamed(
          '/reward/giftcard/result',
          GiftcardResultScreen(issue: settings.arguments as GiftcardIssueModel),
        );
      case '/reward/giftcard/my':
        return _pageNamed('/reward/giftcard/my', const MyGiftcardsScreen());

      // ── [복주머니 마케팅 쿠폰] QR 스캔 진입점 + 내 쿠폰함 ──
      // 지갑 화면("쿠폰 등록" 버튼 등)에서 이 라우트로 진입해 카메라
      // 스캔(실패 시 수동 코드입력으로 자동 폴백)을 시작한다. 스캔/입력
      // 완료 후에는 '/coupon/{token}' 경로(위 와일드카드 분기)로 이어진다.
      case '/reward/coupon/scan':
        return _pageNamed('/reward/coupon/scan', const BokjuCouponScanScreen());
      case '/reward/coupon/my':
        return _pageNamed('/reward/coupon/my', const BokjuCouponHistoryScreen());

      // ── 마이 ──
      case '/my/notifications':
        return _pageNamed('/my/notifications', const NotificationsScreen());
      case '/my/settings':
        return _pageNamed('/my/settings', const SettingsScreen());
      case '/my/subscription/plans':
        return _pageNamed(
          '/my/subscription/plans',
          const SubscriptionPlansScreen(),
        );
      case '/my/subscription':
        return _pageNamed('/my/subscription', const MySubscriptionScreen());

      // ── 소원방 v2.6 [전면 재구축 완료] design_handoff_sintong_wishroom_flutter.zip
      // 기반 신규 모듈(lib/features/wishroom/)로 완전히 교체되었다. 구버전
      // (lib/features/wish_room/, WishRoomEntryGate/WishRoomOnboardingScreen)은
      // 신규 모듈 실동작(회원인증/복주머니/광고 연동 포함 전체 라이프사이클)을
      // Playwright E2E로 끝까지 검증 완료한 뒤 삭제했다. '/wish-room'·
      // '/wish-wall'·'/onboarding' 모두 신규 진입점 [WishRoomIntroScreen]
      // (서버 introMode 판단 → 풀/숏 인트로 또는 바로 [WishRoomShell])으로
      // 연결한다.
      case '/wish-room':
      case '/wish-wall':
      case '/onboarding':
        return _pageNamed('/onboarding', const WishRoomIntroScreen());

      // ── 상점(복주머니 확장 Phase02-B) [인장/촛불/부적 3개 상점 + 보물함]
      // admin_web `/api/public/shop/*`, `/api/public/inventory` 실 API 연동.
      // dev-spec.html이 제시한 `/luckybag/seal-shop` 등 경로는 실제
      // 앱에 존재하지 않는 레거시 기획문서 네이밍이어서, 기존
      // 라우팅 컨벤션(`/shop/...`)을 따라 신규 정의한다.
      case '/shop/seals':
        return _pageNamed('/shop/seals', const SealShopScreen());
      case '/shop/candles':
        return _pageNamed('/shop/candles', const CandleShopScreen());
      case '/shop/talismans':
        return _pageNamed('/shop/talismans', const TalismanShopScreen());
      case '/shop/treasure':
        return _pageNamed('/shop/treasure', const TreasureBoxScreen());

      // [2026-11 홈 화면 정리] "내 기록 (읽기 전용)" 진입점(홈 화면 시계
      // 아이콘) 및 이 라우트를 사용자 요청으로 완전히 제거했다.
      // (구 라우트: '/history/readonly' -> HistoryReadOnlyScreen)

      default:
        // [P3 legacy 제거] 미사용 legacy HomeScreen(home_screen.dart) 대신
        // 실제 홈 탭을 포함한 AppShell(5탭 IndexedStack)로 폴백한다.
        return _page(const AppShell());
    }
  }

  /// [귀인지도 전환 배경 플래시 수정] `/guinji-map/*`는 전부 다크(#0B0B0D)
  /// 화면이므로, 페이드 스루 전환에서 앱 전역 흰 배경이 비치지 않도록
  /// 슬라이드 불투명 전환으로 교체한다. 원인 분석은 guinji_page_route.dart.
  static Route<dynamic> _guinjiPage(Widget child) =>
      guinjiPageRoute<dynamic>(child);
  static PageRoute<dynamic> _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }

  /// [전역 하단바 자동 부착 — 사용자 요청 2026-10-14] named route로 열리는
  /// 화면은 여기서 한 번에 전역 하단바 셸로 감싼다(제외 목록은 셸 참고).
  /// 직접 MaterialPageRoute로 push되는 화면은 기존 수동 하단바를 유지.
  static Route<dynamic> _pageNamed(String name, Widget child) =>
      _page(wrapWithGlobalBottomNav(name, child));

  static Route<dynamic> _guinjiNamed(String name, Widget child) =>
      _guinjiPage(wrapWithGlobalBottomNav(name, child));
}
