import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/router/app_navigator_key.dart';

import 'features/auth/application/auth_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/wallet/application/wallet_provider.dart';
import 'features/wallet/data/wallet_repository.dart';
import 'features/fortune_ad/application/fortune_ad_provider.dart';
import 'features/fortune_ad/data/fortune_ad_repository.dart';
import 'features/notification/notification_provider.dart';
import 'features/notification/data/notification_repository.dart';
import 'features/attendance/application/attendance_provider.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/fortune/daily/application/daily_fortune_provider.dart';
import 'features/fortune/daily/data/daily_fortune_repository.dart';
import 'features/fortune/saju/application/saju_provider.dart';
import 'features/fortune/saju/data/saju_repository.dart';
import 'features/fortune/tarot/application/tarot_provider.dart';
import 'features/fortune/tarot/application/tarot_session_controller.dart';
import 'features/fortune/tarot/application/tarot_audio_controller.dart';
import 'features/fortune/tarot/data/tarot_repository.dart';
import 'features/fortune/face/application/face_provider.dart';
import 'features/fortune/face/data/face_repository.dart';
import 'features/fortune/palm/application/palm_provider.dart';
import 'features/fortune/palm/data/palm_repository.dart';
import 'features/name_fortune/application/name_fortune_provider.dart';
import 'features/name_fortune/data/name_fortune_repository.dart';
import 'features/compatibility/application/compatibility_provider.dart';
import 'features/compatibility/data/compatibility_repository.dart';
import 'features/home/application/fortune_category_provider.dart';
import 'features/home/data/fortune_category_repository.dart';
import 'features/home/application/home_page_config_provider.dart';
import 'features/home/data/page_config_repository.dart';
import 'features/consultation/application/consultation_provider.dart';
import 'features/consultation/data/consultation_repository.dart';
import 'features/mission/application/mission_provider.dart';
import 'features/mission/data/mission_repository.dart';
import 'features/ranking/application/ranking_provider.dart';
import 'features/ranking/data/ranking_repository.dart';
import 'features/community/application/wish_post_provider.dart';
import 'features/community/application/wish_castle_config_provider.dart';
import 'features/community/data/wish_post_repository.dart';
import 'features/community/application/community_post_provider.dart';
import 'features/community/data/community_post_repository.dart';
import 'features/luckybag/application/luckybag_provider.dart';
import 'features/luckybag/data/luckybag_repository.dart';
import 'features/giftcard/application/giftcard_provider.dart';
import 'features/giftcard/data/giftcard_repository.dart';
import 'features/subscription/application/subscription_provider.dart';
import 'features/subscription/data/subscription_repository.dart';
import 'features/ad_banner/application/ad_banner_provider.dart';
import 'features/ad_banner/data/ad_banner_repository.dart';
import 'features/lucky_number/application/lucky_number_provider.dart';
import 'features/lucky_number/data/lucky_number_repository.dart';
import 'features/healing_quote/application/healing_quote_provider.dart';
import 'features/healing_quote/data/healing_quote_repository.dart';
import 'features/pass/application/pass_provider.dart';
import 'features/pass/application/open_pass_reward_controller.dart';
import 'features/pass/data/pass_repository.dart';
import 'features/pass/data/open_pass_repository.dart';
import 'features/intro/application/intro_state_provider.dart';
import 'features/intro/application/intro_config_provider.dart';
import 'features/intro/data/intro_config_repository.dart';
import 'features/luckpouch/application/luck_pouch_provider.dart';
import 'core/domain/access/access_checker.dart';
import 'core/widgets/luck_pouch_toast.dart';
import 'features/wish_room/application/wish_room_provider.dart';

/// 07단계 §2.1 앱 루트 - MultiProvider 전역 등록 + MaterialApp 라우팅 연결
/// 10단계(A안): 모든 Repository는 Mock 구현이며, 향후 실제 API 연동 시
/// 이 파일에서 Repository 생성부만 교체하면 Provider/Presentation 레이어는 변경 없이 재사용된다.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── 전역 Provider(앱 전체에서 상시 참조) ──
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        // [인트로 전면 개편] 첫 진입(스플래시→인트로→홈) 흐름의 로컬 완료 상태
        // (introSeen/skipped/continueAsGuest)와, admin_web에서 발행한 인트로
        // 문구/보상수량 설정. 둘 다 SplashScreen/IntroPagerScreen에서 즉시
        // 참조하므로 다른 화면 Provider보다 앞쪽에 등록한다.
        ChangeNotifierProvider(create: (_) => IntroStateProvider()),
        ChangeNotifierProvider(
          create: (_) => IntroConfigProvider(IntroConfigRepository()),
        ),
        // [자율 정리 - 정책 위반 무력화] 신통방통은 "적립률(등급 배율)" 개념이
        // 없는 무료 광고형 구조다(복주머니는 항상 1:1 지급). 과거 등급 배율을
        // WalletProvider에 주입하던 ProxyProvider 연결을 제거하고 단순
        // ChangeNotifierProvider로 되돌린다(WalletProvider.earn()은 배율 없이
        // 항상 요청한 금액 그대로 지급).
        ChangeNotifierProvider(create: (_) => WalletProvider(WalletRepository())),
        // [신통방통 복주머니 광고 적립 시스템] 지갑 화면의 "광고 보고 충전" 카드가
        // 참조하는 광고 목록 전역 상태. WalletProvider와 별도 원장이지만 지급
        // 자체는 WalletProvider.load()로 재조회하는 동일한 서버-확정 패턴을 쓴다.
        ChangeNotifierProvider(
          create: (_) => FortuneAdProvider(FortuneAdRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(NotificationRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(AttendanceRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyFortuneProvider(DailyFortuneRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => LuckyBagProvider(LuckyBagRepository()),
        ),
        // CMS 제휴광고 배너 — admin_web `/api/public/banners` 실 API 연동(Mock 아님)
        ChangeNotifierProvider(
          create: (_) => AdBannerProvider(AdBannerRepository()),
        ),
        // [사용자 요청] "오늘의 행운숫자"는 광고가 아닌 별도 관리자 콘텐츠 —
        // admin_web `/api/public/lucky-number` 실 API 연동(AdBannerProvider와 분리)
        ChangeNotifierProvider(
          create: (_) => LuckyNumberProvider(LuckyNumberRepository()),
        ),
        // [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고 대체한 힐링 문구 기능 —
        // admin_web `/api/public/healing-quotes` 실 API 연동, 1분마다 자동 순환.
        ChangeNotifierProvider(
          create: (_) => HealingQuoteProvider(HealingQuoteRepository()),
        ),
        // [신규] 열림패스(AlarmPass) — admin_web `/api/public/pass/*` 실 API 연동.
        // 홈 화면 상단 상태바 + 열림패스 섹션에서 공유하는 전역 상태.
        ChangeNotifierProvider(create: (_) => PassProvider(PassRepository())),
        // [재화 구조 정리 및 재연결] 복주머니 — WalletProvider(실 Wallet/PointHistory
        // 원장) 위에 얹힌 얇은 위임 래퍼로 재구성했다(§8 금지 원칙은 "자산을 뒤섞지
        // 않는다"는 원래 의미로, 복주머니가 곧 유일한 실사용자 재화가 된 지금은
        // 프리패스와 복주머니가 섞이지 않도록 하는 데 적용된다). LuckPouchProvider
        // 인스턴스 자체의 identity는 WishRoomProvider 등이 생성 시점에 한 번만
        // 참조를 들고 있으므로 update에서 새로 만들지 않고 in-place로 갱신한다.
        ChangeNotifierProxyProvider<WalletProvider, LuckPouchProvider>(
          create: (context) =>
              LuckPouchProvider(context.read<WalletProvider>()),
          update: (_, wallet, previous) {
            previous!.updateWallet(wallet);
            return previous;
          },
        ),
        // [재화 구조 정리 및 재연결] 열림패스 접근 체크 로직.
        // 과거 "3대 자산(열림패스/행복머니/복주머니)" 설계 잔재로 WalletProvider·
        // LuckPouchProvider까지 의존성으로 들고 있었으나, 상점/커뮤니티 진입은
        // 잔액을 체크하지 않고 항상 허용하는 구조여서 실제로는 죽은 코드였다.
        // 최종 2-자산 구조(프리패스+복주머니) 정리에 맞춰 PassProvider 단일
        // 의존으로 단순화한다 — 화면은 여전히 context.read<AccessChecker>()로만
        // 접근한다.
        ProxyProvider<PassProvider, AccessChecker>(
          update: (_, pass, __) => AccessChecker(pass: pass),
        ),
        // [열림패스 첨부/광고소스 연동] admin_web에 등록된 첨부파일/광고소스가
        // 실제 광고 시청→지급/실패 플로우를 그대로 이끌어가도록 하는 오케스트레이터.
        // 상태 없는 서비스(ChangeNotifier 아님)이므로 Provider로 등록하며,
        // PassProvider가 교체될 때마다 최신 인스턴스로 갈아끼운다.
        ProxyProvider<PassProvider, OpenPassRewardController>(
          update: (_, pass, __) => OpenPassRewardController(
            repository: OpenPassRepository(),
            passProvider: pass,
          ),
        ),
        // ── 기능별 Provider ──
        ChangeNotifierProvider(create: (_) => SajuProvider(SajuRepository())),
        ChangeNotifierProvider(create: (_) => TarotProvider(TarotRepository())),
        // [타로 리뉴얼] 타로 세션 흐름(카테고리 선택→질문→셔플→카드선택→결과)
        // 전용 상태머신. 기존 TarotProvider(결과 조회/히스토리)와 책임 분리.
        ChangeNotifierProvider(create: (_) => TarotSessionController()),
        // [타로 리뉴얼 §11 P5] 타로 전용 SFX 재생/음소거 상태 관리.
        ChangeNotifierProvider(create: (_) => TarotAudioController()),
        ChangeNotifierProvider(create: (_) => FaceProvider(FaceRepository())),
        ChangeNotifierProvider(create: (_) => PalmProvider(PalmRepository())),
        // [운세 카테고리 확장] 이름 운세(성명학) - 신규 카테고리 Provider.
        ChangeNotifierProvider(
          create: (_) => NameFortuneProvider(NameFortuneRepository()),
        ),
        // [궁합(C그룹) 신규 구현] admin_web API는 이미 완성되어 있었으나
        // Flutter 클라이언트가 없던 궁합 기능의 전역 Provider.
        ChangeNotifierProvider(
          create: (_) => CompatibilityProvider(CompatibilityRepository()),
        ),
        // [운세 카테고리 확장] 전체보기(all_categories_screen.dart) 화면이
        // 관리자 기준 그룹/정렬/노출/추천 데이터를 로드하는 전역 Provider.
        ChangeNotifierProvider(
          create: (_) => FortuneCategoryProvider(FortuneCategoryRepository()),
        ),
        // [메인화면 관리자 편집기] admin_web `/cms/page-configs/home`에서
        // 발행(publish)한 홈 화면 구성을 로드해 HomeScreenCosmic이 동적으로
        // 렌더링하도록 하는 전역 Provider. 조회 실패 시 로컬 캐시로 폴백하고,
        // 캐시도 없으면 HomeScreenCosmic이 기존 정적 레이아웃으로 대신 폴백한다.
        ChangeNotifierProvider(
          create: (_) => HomePageConfigProvider(HomePageConfigRepository()),
        ),
        // 07단계(추가) §3.5 - ConsultationProvider가 사주 계산/타로 카드뽑기를
        // 채팅 흐름 안에서 수행하려면 SajuProvider/TarotProvider 인스턴스가 필요하다.
        // 새 Provider를 만들지 않고 위에서 이미 등록한 인스턴스를 attachFortuneProviders로
        // 주입해, 사주/타로 히스토리 화면과 동일한 상태(LoadState)를 공유한다.
        ChangeNotifierProxyProvider2<
          SajuProvider,
          TarotProvider,
          ConsultationProvider
        >(
          create: (_) => ConsultationProvider(ConsultationRepository()),
          update: (_, saju, tarot, consultation) =>
              consultation!..attachFortuneProviders(saju, tarot),
        ),
        ChangeNotifierProvider(
          create: (_) => MissionProvider(MissionRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => RankingProvider(RankingRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => WishPostProvider(WishPostRepository()),
        ),
        // [소원성(Wish Castle) 확장] 촛불 레벨 임계값/복주머니 단위/AI 응원문구 등
        // admin_web CMS 설정을 전역에서 1회 로드해 보관(community_screen 진입 시 로드).
        ChangeNotifierProvider(
          create: (_) => WishCastleConfigProvider(WishPostRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CommunityPostProvider(CommunityPostRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => GiftcardProvider(GiftcardRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(SubscriptionRepository()),
        ),
        // [신통방통 소원방 재개발] 신규 소원방 모듈(복주머니/달빛 조각 경제)
        // 전역 상태. 기존 LuckPouchProvider(실화폐 "복주머니")와는 이름은
        // 같지만 완전히 별개 시스템이며, wish_room 모듈 내부에서만 참조한다.
        // init()은 Hive box를 열어야 하므로 비동기이며, WishRoomShell 진입
        // 시점(FutureBuilder)에서 최초 1회 호출한다.
        ChangeNotifierProvider(create: (_) => WishRoomProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'Fortune Fusion',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            themeMode: themeProvider.mode,
            initialRoute: '/splash',
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) =>
                LuckPouchToastOverlay(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
