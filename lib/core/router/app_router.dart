import 'package:flutter/material.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/intro/presentation/intro_pager_screen.dart';
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
import '../../features/fortune/tarot/presentation/tarot_home_screen.dart';
import '../../features/fortune/tarot/presentation/tarot_hub_screen.dart';
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
import '../../features/consultation/presentation/consultation_type_screen.dart';
import '../../features/consultation/presentation/consultation_chat_screen.dart';
import '../../features/wish_counsel/presentation/wish_counsel_home_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/mission/presentation/mission_screen.dart';
import '../../features/ranking/presentation/ranking_screen.dart';
import '../../features/notification/notifications_screen.dart';
import '../../features/mypage/presentation/settings_screen.dart';
import '../../features/luckybag/domain/luckybag_product_model.dart';
import '../../features/luckybag/domain/luckybag_reward_model.dart';
import '../../features/luckybag/presentation/luckybag_shop_screen.dart';
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
import '../../features/wish_wall_board/presentation/wish_wall_board_screen.dart';
import '../../features/categories/presentation/categories_grid_screen.dart';
import '../../features/lucky/presentation/lucky_items_screen.dart';
import '../../features/pass/presentation/free_pass_gate_screen.dart';
import '../../features/home/presentation/jeontong_eighty_screen.dart';
import '../../features/home/presentation/jeontong_eighty_result_screen.dart';
import '../../features/home/domain/jeontong_eighty_matrix.dart';

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

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return _page(const SplashScreen());
      // [인트로 전면 개편] 4단계 인트로(카드1/카드2/CTA) 페이저. 스플래시 이후
      // introSeen=false인 첫 실행 사용자에게만 노출된다.
      case '/intro':
        return _page(const IntroPagerScreen());
      // [인트로 전면 개편] 구 3페이지 온보딩은 더 이상 진입 흐름에서 쓰이지
      // 않지만("갈아엎지 말고 유지" 원칙에 따라 파일/라우트 자체는 보존),
      // 로그인 강제 로직이 있던 구 진입점이라 스플래시는 더 이상 이 라우트로
      // 보내지 않는다(신규 IntroPagerScreen이 대체).
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
      case JeontongEightyMatrix.resultRoute:
        return _page(
          JeontongEightyResultScreen(categoryId: settings.arguments as String?),
        );

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
        return _page(const TarotHomeScreen());
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

      // ── AI상담 ──
      case '/ai-fortune/consultation/type':
        return _page(const ConsultationTypeScreen());
      case '/ai-fortune/consultation/chat':
        return _page(const ConsultationChatScreen());

      // ── 상담 (Midnight Comfort, 신통방통소원방 옆 신규 섹션) ──
      case '/wish-counsel/home':
        return _page(const WishCounselHomeScreen());

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

      // ── 소원벽 [코인/포인트 잔재 정리] 신통방통 소원방(wish_room,
      // 복주머니와 별개인 직구 자체 화폐)는 사용자 지시로 완전히 삭제되고,
      // 유일한 재화인 복주머니만 쓰는 소원벽으로 통합한다 ──
      case '/wish-room':
      case '/wish-wall':
        return _page(const WishWallBoardScreen());

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
