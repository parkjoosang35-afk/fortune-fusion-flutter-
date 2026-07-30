import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';

import 'features/auth/application/auth_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/wallet/application/wallet_provider.dart';
import 'features/wallet/data/wallet_repository.dart';
import 'features/notification/notification_provider.dart';
import 'features/attendance/application/attendance_provider.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/fortune/daily/application/daily_fortune_provider.dart';
import 'features/fortune/daily/data/daily_fortune_repository.dart';
import 'features/fortune/saju/application/saju_provider.dart';
import 'features/fortune/saju/data/saju_repository.dart';
import 'features/fortune/tarot/application/tarot_provider.dart';
import 'features/fortune/tarot/data/tarot_repository.dart';
import 'features/fortune/face/application/face_provider.dart';
import 'features/fortune/face/data/face_repository.dart';
import 'features/fortune/palm/application/palm_provider.dart';
import 'features/fortune/palm/data/palm_repository.dart';
import 'features/compatibility/application/compatibility_provider.dart';
import 'features/compatibility/data/compatibility_repository.dart';
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
import 'features/amulet/application/amulet_provider.dart';
import 'features/amulet/data/amulet_repository.dart';
import 'features/matching/application/matching_provider.dart';
import 'features/matching/data/matching_repository.dart';
import 'features/giftcard/application/giftcard_provider.dart';
import 'features/giftcard/data/giftcard_repository.dart';
import 'features/subscription/application/subscription_provider.dart';
import 'features/subscription/data/subscription_repository.dart';
import 'features/ad_banner/application/ad_banner_provider.dart';
import 'features/ad_banner/data/ad_banner_repository.dart';
import 'features/lucky_number/application/lucky_number_provider.dart';
import 'features/lucky_number/data/lucky_number_repository.dart';
import 'features/pass/application/pass_provider.dart';
import 'features/pass/data/pass_repository.dart';

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
        // Phase2-1b: AuthProvider의 등급 배율(pointEarnMultiplier)을 WalletProvider에 주입.
        // AuthProvider가 갱신될 때마다 WalletProvider.updateMultiplier가 호출된다.
        ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
          create: (_) => WalletProvider(WalletRepository()),
          update: (_, auth, wallet) =>
              wallet!..updateMultiplier(auth.pointEarnMultiplier),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(AttendanceRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyFortuneProvider(DailyFortuneRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => LuckyBagProvider(LuckyBagRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => AmuletProvider(AmuletRepository()),
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
        // [신규] 알림패스(AlarmPass) — admin_web `/api/public/pass/*` 실 API 연동.
        // 홈 화면 상단 상태바 + 알림패스 섹션에서 공유하는 전역 상태.
        ChangeNotifierProvider(create: (_) => PassProvider(PassRepository())),

        // ── 기능별 Provider ──
        ChangeNotifierProvider(create: (_) => SajuProvider(SajuRepository())),
        ChangeNotifierProvider(create: (_) => TarotProvider(TarotRepository())),
        ChangeNotifierProvider(create: (_) => FaceProvider(FaceRepository())),
        ChangeNotifierProvider(create: (_) => PalmProvider(PalmRepository())),
        ChangeNotifierProvider(
          create: (_) => CompatibilityProvider(CompatibilityRepository()),
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
          create: (_) => MatchingProvider(MatchingRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => GiftcardProvider(GiftcardRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(SubscriptionRepository()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Fortune Fusion',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            initialRoute: '/splash',
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
