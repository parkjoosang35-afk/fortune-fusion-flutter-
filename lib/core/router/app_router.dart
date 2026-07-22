import 'package:flutter/material.dart';
import '../widgets/coming_soon_screen.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_check_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/fortune/daily/presentation/daily_fortune_detail_screen.dart';
import '../../features/fortune/saju/presentation/saju_input_screen.dart';
import '../../features/fortune/saju/presentation/saju_loading_screen.dart';
import '../../features/fortune/saju/presentation/saju_result_screen.dart';
import '../../features/fortune/saju/presentation/saju_history_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/notification/notifications_screen.dart';

/// 07단계 §3.2 라우팅 테이블 - Navigator 1.0(onGenerateRoute) 구현
/// 62개 화면 인벤토리 중, 10단계(A안) 1차 구현 범위(Auth/Home/Saju/Wallet/Notification)는
/// 실제 화면으로 연결하고, 나머지 AI 기능(타로/관상/손금/궁합/AI상담)은
/// ComingSoonScreen으로 라우팅을 미리 연결해 둔다(추후 실제 화면으로 교체 예정).
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return _page(const SplashScreen());
      case '/onboarding':
        return _page(const OnboardingScreen());
      case '/login':
        return _page(const LoginScreen());
      case '/signup/profile-check':
        return _page(const ProfileCheckScreen());

      case '/home':
        return _page(const AppShell());
      case '/home/daily-fortune-detail':
        return _page(const DailyFortuneDetailScreen());

      // ── AI 사주 ──
      case '/ai-fortune/saju/input':
        return _page(const SajuInputScreen());
      case '/ai-fortune/saju/loading':
        return _page(const SajuLoadingScreen());
      case '/ai-fortune/saju/result':
        return _page(SajuResultScreen(resultId: settings.arguments as String?));
      case '/ai-fortune/saju/history':
        return _page(const SajuHistoryScreen());

      // ── AI 타로/관상/손금/궁합/AI상담 (준비중 - 라우팅만 선연결) ──
      case '/ai-fortune/tarot/question':
        return _page(const ComingSoonScreen(title: '타로', icon: Icons.style_rounded));
      case '/ai-fortune/face/capture':
        return _page(const ComingSoonScreen(title: '관상', icon: Icons.face_retouching_natural_rounded));
      case '/ai-fortune/palm/capture':
        return _page(const ComingSoonScreen(title: '손금', icon: Icons.back_hand_rounded));
      case '/ai-fortune/compatibility/input':
        return _page(const ComingSoonScreen(title: '궁합', icon: Icons.favorite_rounded));
      case '/ai-fortune/consultation/type':
        return _page(const ComingSoonScreen(title: 'AI상담', icon: Icons.chat_bubble_rounded));

      // ── 리워드 ──
      case '/reward/wallet':
        return _page(const WalletScreen());
      case '/reward/missions':
        return _page(const ComingSoonScreen(title: '미션', icon: Icons.checklist_rounded));
      case '/reward/ranking':
        return _page(const ComingSoonScreen(title: '랭킹', icon: Icons.leaderboard_rounded));

      // ── 마이 ──
      case '/my/notifications':
        return _page(const NotificationsScreen());

      default:
        return _page(const HomeScreen());
    }
  }

  static PageRoute<dynamic> _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
