// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_v2_screen.dart
// [신통방통 홈 v2 전면 교체 — design_handoff_sintong_main.zip]
//
// 사용자가 두 번째로 업로드한 디자인 핸드오프(README.md "신통방통 메인
// 스크린")를 그대로 재현한 새 홈 화면. 기존 v1(화이트 프리미엄,
// sintong_home/) 대신 이 화면을 [AppShell] 0번 탭에 배선한다.
//
// [원칙 — 기존 데이터/Provider 로직 보존] 지갑/알림/출석/프리패스/
// 웰컴리워드/HomePageConfig 검증 등 기존 initState 로직은 v1
// home_screen.dart와 동일하게 그대로 유지한다. 이 화면이 새로 바꾸는
// 것은 오직 "무엇을 어떻게 그리는지"(시각 레이어)이며, "언제 어떤
// 데이터를 로드하는지"는 바꾸지 않는다.
//
// [CMS 동적 섹션 미적용] 이 새 디자인은 정적 5슬라이드 히어로+고정
// 3카드 시트 구조라 admin_web의 섹션 순서/노출 커스터마이징
// (HomePageConfigProvider)과 구조적으로 호환되지 않는다. 사용자가
// "완전 교체"를 선택했으므로 이번 교체에서는 v1의 동적 섹션 렌더링
// 분기를 유지하지 않고, 정적 레이아웃으로 전환한다(CMS 설정 로드
// 자체는 향후 재사용을 위해 그대로 트리거만 해둔다 — 화면에는 반영
// 안 함).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../healing_quote/application/healing_quote_provider.dart';
import '../../../wallet/application/wallet_provider.dart';
import '../../../attendance/application/attendance_provider.dart';
import '../../../notification/notification_provider.dart';
import '../../../pass/application/pass_provider.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/home_page_config_provider.dart';
import '../widgets/welcome_reward_modal.dart';
import 'sintong_home_v2_tokens.dart';
import 'widgets/sintong_hero_carousel.dart';
import 'widgets/sintong_v2_topbar.dart';
import 'widgets/sintong_chip_row.dart';
import 'widgets/sintong_v2_sheet.dart';

class SintongHomeV2Screen extends StatefulWidget {
  const SintongHomeV2Screen({super.key});

  @override
  State<SintongHomeV2Screen> createState() => _SintongHomeV2ScreenState();
}

class _SintongHomeV2ScreenState extends State<SintongHomeV2Screen> {
  final _heroKey = GlobalKey<SintongHeroCarouselState>();
  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<PassProvider>().load();
      context.read<NotificationProvider>().load();
      context.read<HealingQuoteProvider>().load();
      // CMS 홈 섹션 구성은 v2 정적 레이아웃에서 화면에 반영하지 않지만,
      // 다른 화면(all_categories 등)이 캐시를 공유해 참조할 수 있으므로
      // 로드 자체는 그대로 트리거해둔다(v1과 동일한 부작용 유지).
      context.read<HomePageConfigProvider>().load();
      _maybeShowWelcomeRewardModal();
    });
  }

  /// [Phase C] v1과 완전히 동일한 웰컴 리워드 팝업 로직(변경 없음).
  Future<void> _maybeShowWelcomeRewardModal() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final reward = auth.lastSignupReward;
    if (user == null || reward == null || user.welcomeGiftClaimed) return;

    final amount = (reward['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0 || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await WelcomeRewardModal.show(
      context,
      amount: amount,
      onClaim: () {
        auth.claimWelcomeGift();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 하단 여백(시트를 히어로 위로 20px 겹치게 올리며 생기는 화면
      // 최하단 틈)도 시트와 동일한 다크 톤으로 채워 이질감이 없게 한다.
      backgroundColor: SHomeV2Colors.sheetBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 460,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SintongHeroCarousel(
                    key: _heroKey,
                    onIndexChanged: (i) => setState(() => _heroIndex = i),
                  ),
                  const Positioned(top: 0, left: 0, right: 0, child: SintongV2TopBar()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 44,
                    child: SintongDotsIndicator(currentIndex: _heroIndex),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 78,
                    child: SintongChipRow(
                      currentIndex: _heroIndex,
                      onChipTapGoTo: (i) =>
                          _heroKey.currentState?.goTo(i),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: const SintongV2Sheet(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
