import 'package:flutter/material.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/intro/presentation/intro_pager_screen.dart';
import '../../features/policy/presentation/policy_notice_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/profile_check_screen.dart';
import '../../features/fortune/shared/presentation/removed_daily_fortune_stub.dart';
import '../../features/mypage/presentation/my_fortune_records_screen.dart';
import '../../features/home/presentation/all_categories_screen.dart';
import '../../features/fortune/generic/presentation/generic_fortune_result_screen.dart';
import '../../features/fortune/saju/presentation/saju_input_screen.dart';
import '../../features/fortune/saju/presentation/saju_loading_screen.dart';
import '../../features/fortune/saju/presentation/saju_result_screen.dart';
import '../../features/fortune/saju/presentation/saju_history_screen.dart';
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
import '../../features/fortune/face/presentation/face_result_screen.dart';
import '../../features/fortune/face/presentation/face_history_screen.dart';
import '../../features/fortune/palm/presentation/palm_capture_screen.dart';
import '../../features/fortune/palm/presentation/palm_analyzing_screen.dart';
import '../../features/fortune/palm/presentation/palm_result_screen.dart';
import '../../features/fortune/palm/presentation/palm_history_screen.dart';
import '../../features/name_fortune/presentation/name_fortune_input_screen.dart';
import '../../features/name_fortune/presentation/name_fortune_result_screen.dart';
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
import '../../features/wish_room/presentation/wish_room_entry_gate.dart';
import '../../features/wish_room/presentation/wish_room_onboarding_screen.dart';
import '../../features/shop/presentation/seal_shop_screen.dart';
import '../../features/shop/presentation/candle_shop_screen.dart';
import '../../features/shop/presentation/talisman_shop_screen.dart';
import '../../features/shop/presentation/treasure_box_screen.dart';
import '../../features/categories/presentation/categories_grid_screen.dart';
import '../../features/lucky/presentation/lucky_items_screen.dart';
import '../../features/pass/presentation/free_pass_gate_screen.dart';
import '../../features/home/presentation/jeontong_eighty_screen.dart';
import '../../features/home/presentation/jeontong_eighty_result_screen.dart';
import '../../features/home/presentation/jeontong_eighty_grid_screen.dart';
import '../../features/home/presentation/jeontong_eighty_loading_screen.dart';
import '../../features/home/presentation/jeontong_talisman_gate_screen.dart';
import '../../features/home/presentation/jeontong_input_screen.dart';
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
import '../../features/guinji/presentation/guinji_friend_list_screen.dart';
import '../../features/guinji/presentation/guinji_guest_result_screen.dart';
import '../../features/guinji/presentation/guinji_map_guest_join_screen.dart';
// [귀인지도 기능 정리 — 관계상세/랭킹] `/guinji-map/*` 신규 디자인 톤으로
// 새로 만든 관계상세(N→상세)·랭킹 화면. M/F 화면에서 진입점으로 연결한다.
import '../../features/guinji/presentation/guinji_map_relation_detail_screen.dart';
import '../../features/guinji/presentation/guinji_map_ranking_screen.dart';
import 'package:provider/provider.dart';
import '../auth/auth_token_store.dart';
import 'app_navigator_key.dart';

/// 07단계 §3.2 라우팅 테이블 - Navigator 1.0(onGenerateRoute) 구현
/// 10단계(A안): AI 6대 기능(사주/타로/관상/손금/궁합/AI상담) + 리워드(미션/랭킹)까지
/// 전체 화면이 실제 구현되어 라우팅에 연결된 상태.
class AppRouter {
  AppRouter._();

  // [타로 섹션 전면 개편 §2] 신규 라우트 이름 상수. 화면 내부(홈/허브)에서
  // 문자열 리터럴을 중복 작성하지 않도록 여기서 단일 소스로 정의한다.
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

    switch (settings.name) {
      case '/splash':
        return _page(const SplashScreen());
      // [인트로 전면 개편] 4단계 인트로(카드1/카드2/CTA) 페이저. 스플래시 이후
      // introSeen=false인 첫 실행 사용자에게만 노출된다.
      case '/intro':
        return _page(const IntroPagerScreen());
      // [6-5-D] 구 3페이지 온보딩(OnboardingScreen)은 신규 IntroPagerScreen이
      // 완전히 대체했고, 이 named route를 호출하는 코드가 앱 전체(딥링크 포함)
      // 어디에도 없음을 확인해 죽은 라우트만 제거한다. 화면 파일 자체
      // (onboarding_screen.dart)는 향후 참조 가능성을 배제할 수 없어 보존한다.
      case '/login':
        return _page(const LoginScreen());
      case '/signup':
        return _page(const SignupScreen());
      case '/signup/profile-check':
        return _page(const ProfileCheckScreen());
      // [2026 디자인 핸드오프 콘텐츠 반영] 인트로 페이지4 CTA 링크
      // `"재미·참고용" 콘텐츠 안내` 대상 라우트(핸드오프 §라우팅
      // onDisclaimerTap()과 동일한 경로 문자열).
      case '/policy/notice':
        return _page(const PolicyNoticeScreen());

      case '/home':
        // [하단바 통일 작업] 정통사주/타로/소원방/귀인지도 등 AppShell
        // 바깥의 push 화면에 추가한 [MainBottomNavBar]가 특정 탭으로
        // 곧장 진입시키기 위해 int 인덱스를 arguments로 넘길 수 있다.
        // 기존처럼 arguments 없이 호출되면 그대로 0(홈)으로 시작한다.
        final homeArgs = settings.arguments;
        return _page(
          AppShell(initialIndex: homeArgs is int ? homeArgs : 0),
        );

      // [귀인지도 Phase G-1: 라우트 스캐폴딩] 홈 배너 캐러셀 Slide 1
      // ("귀인지도") CTA의 진입점. 신통방통_귀인지도_최종_개발계획서_v2.0.md
      // §1은 `/guinji`(첫 진입 시 온보딩, 재방문 시 지도)를 요구하지만, 이
      // Phase에서는 온보딩 화면 1개만 우선 연결한다(재방문 분기·지도 화면은
      // 후속 Phase). go_router가 아닌 기존 Navigator(onGenerateRoute) 관례를
      // 그대로 따른다.
      case '/guinji':
        return _page(const GuinjiOnboardingScreen());
      // [Phase G-3] 지도 메인(S5) — 참여자가 1명 이상 생겼을 때의 코어
      // 화면. 백엔드 API가 아직 없어 실제 진입 흐름(참여 발생 시 자동
      // 전환)은 연결되어 있지 않고, 현재는 빈지도(S4) 화면의 임시 데모
      // 링크로만 접근 가능하다(§검토용, 후속 Phase에서 실데이터 연동).
      case '/guinji/map':
        return _page(const GuinjiMapScreen());
      // [Phase G-6] 공유(S8) — 지도메인/빈지도의 초대 CTA에서 이동한다.
      case '/guinji/share':
        return _page(const GuinjiShareScreen());
      // [Phase G-7] 지인 참여(S9) — 지인이 초대 링크로 들어와 자신의
      // 사주를 입력하는 화면. 실제 딥링크 파라미터(초대자 ID 등)는
      // 백엔드 §5 완성 후 연결한다.
      case '/guinji/join':
        return _page(const GuinjiJoinScreen());
      // [Phase G-8] 결과 카드(S10) — 랭킹(S7)의 "결과 카드로 공유하기"
      // CTA에서 이동한다. 10화면 로드맵의 마지막 화면.
      case '/guinji/result-card':
        return _page(const GuinjiResultCardScreen());
      // [귀인지도 실구현 — 딥링크/랭킹 라우트 등록] 이전까지 랭킹(S7)은
      // 지도메인(S5) 내부에서 `people`을 직접 전달받는 MaterialPageRoute로만
      // push 가능해 named route(`/guinji/ranking`)가 없었다. 딥링크나 다른
      // 진입 경로에서도 접근할 수 있도록 전역 [GuinjiProvider]에서 people을
      // 직접 읽어오는 named route를 추가한다(지도메인 내부 push는 계속
      // 인자를 넘기는 기존 방식을 유지 — 회귀 없음, 이 라우트는 추가 진입점).
      case '/guinji/ranking':
        return _page(
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
        return _page(const GuinjiLandingScreen());
      case '/guinji-map/new':
        return _page(const GuinjiInputScreen());
      case '/guinji-map/calc':
        // [흐름 정합성] 이 라우트는 호스트가 I(입력)에서 자기 정보만 제출한
        // 직후(createMapWithInput 성공)에만 진입한다 — 아직 지인이 참여하지
        // 않아 "관계"가 존재하지 않으므로, 기본값(게스트 2인 관계 계산 문구)
        // 대신 "내 사주 계산" 전용 문구로 오버라이드한다. 게스트 참여 흐름
        // (guinji_map_guest_join_screen.dart)은 이 라우트를 타지 않고 직접
        // MaterialPageRoute로 push하므로 기본값(관계 계산 문구)이 그대로
        // 유지된다 — 회귀 없음.
        return _page(
          GuinjiCalculatingScreen(
            title: '내 사주를\n정성껏 살펴보고 있어요',
            subtitle: '만세력을 계산하고\n오행·십성·합충을 분석 중입니다',
            onComplete: () => appNavigatorKey.currentState
                ?.pushReplacementNamed('/guinji-map/m'),
          ),
        );
      case '/guinji-map/m':
        return _page(
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
              );
            },
          ),
        );
      case '/guinji-map/m/share':
        return _page(
          Builder(
            builder: (context) {
              final provider = context.watch<GuinjiProvider>();
              return GuinjiMapShareScreen(
                ownerName: provider.mapName ?? '나',
                mapToken: provider.mapToken ?? '',
                joinedCount: provider.people.length,
                onKakaoShare: () => shareGuinjiMapInvite(
                  context,
                  provider.mapToken,
                  target: GuinjiShareTarget.kakao,
                ),
                onSmsShare: () => shareGuinjiMapInvite(
                  context,
                  provider.mapToken,
                  target: GuinjiShareTarget.sms,
                ),
                onInstagramShare: () => shareGuinjiMapInvite(
                  context,
                  provider.mapToken,
                  target: GuinjiShareTarget.instagram,
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
      case '/guinji-map/m/friends':
        return _page(
          Builder(
            builder: (context) {
              final people = context.watch<GuinjiProvider>().people;
              // [귀인지도 기능 정리 — F화면 상세 연결] friends는 점수
              // 내림차순으로 정렬된 GuinjiFriendEntry 목록이므로, 동일하게
              // people을 점수 내림차순 정렬해두면 rank(1-base) - 1 인덱스로
              // 원본 GuinjiPerson과 1:1 매핑된다(guinjiFriendEntriesFromPeople
              // 내부 정렬 로직과 동일한 기준 재사용).
              final sortedPeople = [...people]
                ..sort((a, b) => b.score.compareTo(a.score));
              return GuinjiFriendListScreen(
                friends: guinjiFriendEntriesFromPeople(people),
                onFriendTap: (entry) {
                  final idx = entry.rank - 1;
                  if (idx < 0 || idx >= sortedPeople.length) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GuinjiMapRelationDetailScreen(
                        person: sortedPeople[idx],
                      ),
                    ),
                  );
                },
                // [멤버 삭제 — "이름/생년월일을 잘못 넣어서 잘못 나올 때
                // 삭제"] 지도 소유자가 F(친구목록) 화면에서 직접 삭제할
                // 수 있게 한다. 확인 다이얼로그는 화면 내부(_confirmDelete)
                // 에서 이미 거쳤으므로 여기서는 곧바로 서버 호출한다.
                onFriendDelete: (entry) async {
                  final memberId = entry.memberId;
                  if (memberId == null) return;
                  final provider = context.read<GuinjiProvider>();
                  final ok = await provider.deleteMember(memberId);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(provider.error ?? '삭제에 실패했습니다.'),
                      ),
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
        return _page(
          Builder(
            builder: (context) {
              final provider = context.watch<GuinjiProvider>();
              return GuinjiMapRankingScreen(
                people: provider.people,
                ownerName: provider.mapName ?? '나',
              );
            },
          ),
        );
      case '/guinji-map/guest/result':
        return _page(
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
        return _page(const RemovedDailyFortuneStub());
      case '/fortune/today/input':
        return _page(const RemovedDailyFortuneStub());
      case '/fortune/today/loading':
        return _page(const RemovedDailyFortuneStub());
      case '/fortune/today/result':
        return _page(const RemovedDailyFortuneStub());
      case '/home/all-categories':
        return _page(const AllCategoriesScreen());

      // ── [신규 화면 3개] 80종 전체 보기 / 개운 아이템 / 프리패스 안내 ──
      // 기존 55개 case는 순서·내용 변경 없이 그대로 두고, 이 3개만 삽입한다.
      case '/categories-grid':
        return _page(const CategoriesGridScreen());
      case '/lucky-items':
        return _page(const LuckyItemsScreen());
      case '/free-pass-gate':
        return _page(const FreePassGateScreen());

      // ── [정통사주 80종 개편] 홈 "운세" 카드 진입점 - 대카테고리/소카테고리
      // 진열 화면 + 전용 결과 화면. AI 타로/관상/손금/상담 라우트는 이 작업과
      // 무관하며 아래에 그대로 유지된다(변경 없음). ──
      case JeontongEightyMatrix.browseRoute:
        return _page(const JeontongEightyScreen());
      // [부적게이트] "운세" 섹션 진입점(홈 카드/전체보기/운세허브)에서
      // [browseRoute](69종 목록)로 가기 직전에 표시하는 인터랙티브 게이트.
      // 카테고리 선택 이전 단계이므로 categoryId를 받지 않는다. 애니메이션
      // 완료 후 이 화면이 [browseRoute]로 `pushReplacementNamed`한다(뒤로가기
      // 시 게이트를 다시 보지 않고 곧장 이전 화면으로 돌아가게 하기 위함).
      case JeontongEightyMatrix.gateRoute:
        return _page(const JeontongTalismanGateScreen());
      // [운세 섹션 4단계 흐름 - 화면3 로딩] "사주보기" 제출 직후 결과로
      // 곧장 가지 않고 반드시 이 로딩 화면을 먼저 거친다(handoff 원본
      // saju_loading_screen.dart 디자인 재현). arguments로 categoryId
      // (String?)를 그대로 받아 결과 화면 이동 시 다시 전달한다. 이 화면은
      // 부적게이트와 무관 — 애니메이션 완료 후 곧장 [resultRoute]로 이동한다.
      case JeontongEightyMatrix.loadingRoute:
        return _page(
          JeontongEightyLoadingScreen(
            categoryId: settings.arguments as String?,
          ),
        );
      case JeontongEightyMatrix.resultRoute:
        return _page(
          JeontongEightyResultScreen(categoryId: settings.arguments as String?),
        );
      // [정통사주 80종 · MVP 라스트 마일 - Mission 1] 정통사주 전용 생년월일시
      // 입력 화면. 이 라우트가 신설되기 전까지는 사용자가 자신의 생년월일시를
      // 입력할 UI 자체가 없어 계산 엔진(SajuEngine)과 그리드 화면이 있어도
      // "서비스"로 기능하지 못했다. 기존 `/jeontong/eighty`(browseRoute,
      // 아코디언) 라우트/화면은 이 신설과 무관하게 그대로 둔다(회귀 방지).
      case '/jeontong/input':
        return _page(
          JeontongInputScreen(categoryId: settings.arguments as String?),
        );

      // [정통사주 80종 그리드 신설] 8개 섹션 카드가 항상 펼쳐진 상태로
      // 80종 전체를 한 화면에서 훑어보는 신규 라우트. 기존 `/jeontong/eighty`
      // (아코디언 방식, 홈 "운세" 카드가 이미 사용 중)와는 별개이며 그
      // 라우트/화면은 무수정으로 그대로 둔다(회귀 방지).
      case '/jeontong/eighty/grid':
        return _page(
          JeontongEightyGridScreen(
            userId:
                (AuthTokenStore.cachedUserIdOrNull ??
                        AuthTokenStore.fallbackUserId)
                    .toString(),
          ),
        );

      // [2026-11 홈 화면 정리] "/jeontong/overview"는 방금 제거한 "내 기록
      // (읽기 전용)" 화면의 "한눈에 미리보기" 버튼에서만 진입 가능했던
      // 라우트였다. 그 화면이 삭제되어 더 이상 진입 경로가 없으므로 함께
      // 제거한다(HistoryJeontongOverviewScreen 파일 자체도 삭제).

      case '/my/fortune-records':
        return _page(const MyFortuneRecordsScreen());

      // ── [운섹션 87 카테고리 통합] 공용 결과 화면 ──
      // 전용 화면이 아직 없는 카테고리(K/V/O 일부/X/G/B/D/R)의 단일 진입점.
      // arguments로 카테고리 id(String, 예: 'K-001')를 전달한다.
      case '/fortune/category':
        return _page(
          GenericFortuneResultScreen(categoryId: settings.arguments as String?),
        );

      // ── 궁합 [궁합(C그룹) 신규 구현] ──
      // admin_web `/api/public/compatibility/*`는 이미 완전 구현되어
      // 있었으나(무료 정책까지 반영) Flutter 클라이언트가 없었다. 전체보기의
      // C그룹(7개) 항목이 여기로 딥링크된다. arguments로 CompatibilityType을
      // 전달하면 해당 유형이 미리 선택된다(없으면 기본 love).
      case '/compatibility/input':
        return _page(const RemovedDailyFortuneStub());
      case '/compatibility/result':
        return _page(const RemovedDailyFortuneStub());

      // ── AI 사주 ──
      case '/ai-fortune/saju/input':
        {
          // [운세 카테고리 확장] 전체보기에서 관리자 카테고리를 탭했을 때
          // {'initialTopics': ['재물', ...]} 형태의 인자로 딥링크된다.
          // arguments가 없거나(기존 모든 진입 경로) 형식이 다르면 그대로
          // null로 전달되어 기존 기본 동작(종합 선택)과 동일하다.
          final args = settings.arguments;
          List<String>? initialTopics;
          if (args is Map) {
            final raw = args['initialTopics'];
            if (raw is List) {
              initialTopics = raw.map((e) => e.toString()).toList();
            }
          }
          return _page(SajuInputScreen(initialTopics: initialTopics));
        }
      case '/ai-fortune/saju/loading':
        return _page(const SajuLoadingScreen());
      case '/ai-fortune/saju/result':
        return _page(SajuResultScreen(resultId: settings.arguments as String?));
      case '/ai-fortune/saju/history':
        return _page(const SajuHistoryScreen());

      // ── AI 타로 [타로 섹션 전면 개편 §2 신규 진입점] ──
      // ①타로 메인 홈. 기존 홈/운세탭의 진입점(/ai-fortune/tarot/question)은
      // 그대로 두고, 이 라우트가 새로운 "정문" 역할을 한다(P2 단계에서
      // 기존 진입점들을 이 라우트로 전환할 예정).
      case tarotHomeRoute:
        // [handoff-home 이식] 타로 메인 홈만 새 디자인(OzTarotHomeScreen)으로
        // 교체한다. 기존 [TarotHomeScreen] 위젯 자체는 [enterTarotCategory]
        // 공용 함수(화면02 TarotHubScreen이 참조)를 여전히 정의하고 있어
        // 파일을 삭제하지 않고 그대로 보존한다(다른 화면 영향 없음).
        return _page(const OzTarotHomeScreen());
      // [타로 인트로 핸드오프 이식] 타로 메인 진입 직전 표시하는 스플래시.
      // 카운트다운 완료 시 이 화면 자신이 [tarotHomeRoute]로 이동한다.
      case tarotIntroRoute:
        return _page(const TarotIntroScreen());
      // ②서브 카테고리 허브. arguments로 TarotCategoryGroup을 받으면 해당
      // 그룹 칩이 선택된 상태로 시작하고, 없으면(직접 진입) 전체를 보여준다.
      case tarotHubRoute:
        return _page(
          TarotHubScreen(
            initialGroup: settings.arguments is TarotCategoryGroup
                ? settings.arguments as TarotCategoryGroup
                : null,
          ),
        );
      // ③카테고리 상세 진입. arguments로 카테고리 id(String)를 받는다.
      case tarotCategoryDetailRoute:
        return _page(
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
          return _page(
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
        return _page(const TarotCardSelectScreen());
      case '/ai-fortune/tarot/loading':
        return _page(const TarotLoadingScreen());
      case '/ai-fortune/tarot/result':
        return _page(
          TarotResultScreen(resultId: settings.arguments as String?),
        );
      case '/ai-fortune/tarot/history':
        return _page(const TarotHistoryScreen());

      // ── AI 관상 ──
      case '/ai-fortune/face/capture':
        return _page(const FaceCaptureScreen());
      case '/ai-fortune/face/analyzing':
        return _page(const FaceAnalyzingScreen());
      case '/ai-fortune/face/result':
        return _page(FaceResultScreen(resultId: settings.arguments as String?));
      case '/ai-fortune/face/history':
        return _page(const FaceHistoryScreen());

      // ── AI 손금 ──
      case '/ai-fortune/palm/capture':
        return _page(const PalmCaptureScreen());
      case '/ai-fortune/palm/analyzing':
        return _page(const PalmAnalyzingScreen());
      case '/ai-fortune/palm/result':
        return _page(PalmResultScreen(resultId: settings.arguments as String?));
      case '/ai-fortune/palm/history':
        return _page(const PalmHistoryScreen());

      // ── 이름 운세(성명학) [운세 카테고리 확장 - 신규] ──
      case '/ai-fortune/name/input':
        return _page(const NameFortuneInputScreen());
      case '/ai-fortune/name/result':
        return _page(const NameFortuneResultScreen());

      // ── 리워드 ──
      case '/reward/wallet':
        return _page(const WalletScreen());
      case '/reward/attendance':
        // [복주머니 화면 재구성] 미션/복주머니열기/개봉이력 삭제 후
        // 출석체크만 남기면서 신설한 "이번 달 출석 달력" 화면.
        return _page(const AttendanceCalendarScreen());
      case '/reward/missions':
        return _page(const MissionScreen());
      case '/reward/ranking':
        return _page(const RankingScreen());
      case '/reward/luckybag/open':
        return _page(
          LuckyBagOpenAnimationScreen(
            product: settings.arguments as LuckyBagProductModel,
          ),
        );
      case '/reward/luckybag/result':
        final args = settings.arguments as Map<String, dynamic>;
        return _page(
          LuckyBagResultScreen(
            result: args['result'] as LuckyBagOpenResult,
            product: args['product'] as LuckyBagProductModel,
          ),
        );
      case '/reward/luckybag/history':
        return _page(const LuckyBagHistoryScreen());
      case '/reward/giftcard':
        return _page(const GiftcardCatalogScreen());
      case '/reward/giftcard/detail':
        return _page(
          GiftcardDetailScreen(
            product: settings.arguments as GiftcardProductModel,
          ),
        );
      case '/reward/giftcard/result':
        return _page(
          GiftcardResultScreen(issue: settings.arguments as GiftcardIssueModel),
        );
      case '/reward/giftcard/my':
        return _page(const MyGiftcardsScreen());

      // ── 마이 ──
      case '/my/notifications':
        return _page(const NotificationsScreen());
      case '/my/settings':
        return _page(const SettingsScreen());
      case '/my/subscription/plans':
        return _page(const SubscriptionPlansScreen());
      case '/my/subscription':
        return _page(const MySubscriptionScreen());

      // ── 소원방 [Phase01 뼈대 정리] 구버전 소원벽(wish_wall_board_screen,
      // 진짜 죽은 화면)은 lib/features/_archive/wish_wall_board/로 아카이브
      // 되었다. '/wish-room'과 '/wish-wall' 모두 신규 V2 소원방
      // 게이트([WishRoomEntryGate] — 온보딩 미완료 시 01 온보딩 화면을
      // 먼저 보여주고, 완료했으면 [WishRoomHomeScreen])로 연결한다.
      case '/wish-room':
      case '/wish-wall':
        return _page(const WishRoomEntryGate());
      case '/onboarding':
        // [Phase 01 · 2단계 · orphan 화면 연결] 딥링크 등으로 이 라우트에
        // 직접 진입하는 경우를 위한 독립 경로. [WishRoomEntryGate]와 동일한
        // [markWishRoomOnboardingSeen] 플래그를 공유해야 게이트와 상태가
        // 어긋나지 않는다.
        return _page(
          WishRoomOnboardingScreen(
            onEnter: () async {
              await markWishRoomOnboardingSeen();
              appNavigatorKey.currentState?.pushReplacementNamed('/wish-room');
            },
          ),
        );

      // ── 상점(복주머니 확장 Phase02-B) [인장/촛불/부적 3개 상점 + 보물함]
      // admin_web `/api/public/shop/*`, `/api/public/inventory` 실 API 연동.
      // dev-spec.html이 제시한 `/luckybag/seal-shop` 등 경로는 실제
      // 앱에 존재하지 않는 레거시 기획문서 네이밍이어서, 기존
      // 라우팅 컨벤션(`/shop/...`)을 따라 신규 정의한다.
      case '/shop/seals':
        return _page(const SealShopScreen());
      case '/shop/candles':
        return _page(const CandleShopScreen());
      case '/shop/talismans':
        return _page(const TalismanShopScreen());
      case '/shop/treasure':
        return _page(const TreasureBoxScreen());

      // [2026-11 홈 화면 정리] "내 기록 (읽기 전용)" 진입점(홈 화면 시계
      // 아이콘) 및 이 라우트를 사용자 요청으로 완전히 제거했다.
      // (구 라우트: '/history/readonly' -> HistoryReadOnlyScreen)

      default:
        // [P3 legacy 제거] 미사용 legacy HomeScreen(home_screen.dart) 대신
        // 실제 홈 탭을 포함한 AppShell(5탭 IndexedStack)로 폴백한다.
        return _page(const AppShell());
    }
  }

  static PageRoute<dynamic> _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
