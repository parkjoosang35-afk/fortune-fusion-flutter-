import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
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
import 'features/community/data/wish_post_repository.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(create: (_) => WalletProvider(WalletRepository())),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider(AttendanceRepository())),
        ChangeNotifierProvider(create: (_) => DailyFortuneProvider(DailyFortuneRepository())),

        // ── 기능별 Provider ──
        ChangeNotifierProvider(create: (_) => SajuProvider(SajuRepository())),
        ChangeNotifierProvider(create: (_) => TarotProvider(TarotRepository())),
        ChangeNotifierProvider(create: (_) => FaceProvider(FaceRepository())),
        ChangeNotifierProvider(create: (_) => PalmProvider(PalmRepository())),
        ChangeNotifierProvider(create: (_) => CompatibilityProvider(CompatibilityRepository())),
        ChangeNotifierProvider(create: (_) => ConsultationProvider(ConsultationRepository())),
        ChangeNotifierProvider(create: (_) => MissionProvider(MissionRepository())),
        ChangeNotifierProvider(create: (_) => RankingProvider(RankingRepository())),
        ChangeNotifierProvider(create: (_) => WishPostProvider(WishPostRepository())),
      ],
      child: MaterialApp(
        title: 'Fortune Fusion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: '/splash',
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
