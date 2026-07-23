import 'package:flutter/material.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/profile_check_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/fortune/daily/presentation/daily_fortune_detail_screen.dart';
import '../../features/fortune/saju/presentation/saju_input_screen.dart';
import '../../features/fortune/saju/presentation/saju_loading_screen.dart';
import '../../features/fortune/saju/presentation/saju_result_screen.dart';
import '../../features/fortune/saju/presentation/saju_history_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_question_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_loading_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_result_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_history_screen.dart';
import '../../features/fortune/face/presentation/face_capture_screen.dart';
import '../../features/fortune/face/presentation/face_analyzing_screen.dart';
import '../../features/fortune/face/presentation/face_result_screen.dart';
import '../../features/fortune/face/presentation/face_history_screen.dart';
import '../../features/fortune/palm/presentation/palm_capture_screen.dart';
import '../../features/fortune/palm/presentation/palm_analyzing_screen.dart';
import '../../features/fortune/palm/presentation/palm_result_screen.dart';
import '../../features/fortune/palm/presentation/palm_history_screen.dart';
import '../../features/compatibility/presentation/compatibility_input_screen.dart';
import '../../features/compatibility/presentation/compatibility_result_screen.dart';
import '../../features/consultation/presentation/consultation_type_screen.dart';
import '../../features/consultation/presentation/consultation_chat_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/mission/presentation/mission_screen.dart';
import '../../features/ranking/presentation/ranking_screen.dart';
import '../../features/notification/notifications_screen.dart';
import '../../features/mypage/presentation/settings_screen.dart';
import '../../features/amulet/presentation/amulet_shop_screen.dart';
import '../../features/amulet/presentation/my_amulets_screen.dart';
import '../../features/amulet/presentation/amulet_generate_screen.dart';
import '../../features/amulet/presentation/amulet_gift_screen.dart';
import '../../features/luckybag/domain/luckybag_product_model.dart';
import '../../features/luckybag/domain/luckybag_reward_model.dart';
import '../../features/luckybag/presentation/luckybag_shop_screen.dart';
import '../../features/luckybag/presentation/luckybag_open_animation_screen.dart';
import '../../features/luckybag/presentation/luckybag_result_screen.dart';
import '../../features/luckybag/presentation/luckybag_history_screen.dart';
import '../../features/community/domain/wish_post_model.dart';
import '../../features/community/presentation/wish_detail_screen.dart';

/// 07단계 §3.2 라우팅 테이블 - Navigator 1.0(onGenerateRoute) 구현
/// 10단계(A안): AI 6대 기능(사주/타로/관상/손금/궁합/AI상담) + 리워드(미션/랭킹)까지
/// 전체 화면이 실제 구현되어 라우팅에 연결된 상태.
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
      case '/signup':
        return _page(const SignupScreen());
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

      // ── AI 타로 ──
      case '/ai-fortune/tarot/question':
        return _page(const TarotQuestionScreen());
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

      // ── AI 궁합 ──
      case '/ai-fortune/compatibility/input':
        return _page(const CompatibilityInputScreen());
      case '/ai-fortune/compatibility/result':
        return _page(const CompatibilityResultScreen());

      // ── AI상담 ──
      case '/ai-fortune/consultation/type':
        return _page(const ConsultationTypeScreen());
      case '/ai-fortune/consultation/chat':
        return _page(const ConsultationChatScreen());

      // ── 리워드 ──
      case '/reward/wallet':
        return _page(const WalletScreen());
      case '/reward/missions':
        return _page(const MissionScreen());
      case '/reward/ranking':
        return _page(const RankingScreen());
      case '/reward/luckybag':
        return _page(const LuckyBagShopScreen());
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
      case '/reward/amulet':
        return _page(const AmuletShopScreen());
      case '/reward/amulet/my':
        return _page(const MyAmuletsScreen());
      case '/reward/amulet/generate':
        return _page(const AmuletGenerateScreen());
      case '/reward/amulet/gift':
        return _page(const AmuletGiftScreen());

      // ── 커뮤니티 ──
      case '/community/wish/detail':
        return _page(
          WishDetailScreen(post: settings.arguments as WishPostModel),
        );

      // ── 마이 ──
      case '/my/notifications':
        return _page(const NotificationsScreen());
      case '/my/settings':
        return _page(const SettingsScreen());

      default:
        return _page(const HomeScreen());
    }
  }

  static PageRoute<dynamic> _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
