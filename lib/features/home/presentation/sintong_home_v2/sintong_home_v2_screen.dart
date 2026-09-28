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
//
// [히어로 영상 전환 지시서 v1.0] 기존 6장 슬라이드 캐러셀
// (SintongHeroCarousel)을 30초 홍보 영상(SintongHeroVideo)으로
// 교체한다. §2 변경범위 표에 따라: 인디케이터 제거, 슬라이드 인덱스
// 상태값(_heroIndex/_heroKey) 완전 삭제, 칩은 순수 라우팅 버튼으로
// 단순화. 히어로 영역의 세로 비율도 캐러셀 원본 이미지 비율(572/1024)
// 대신 실제 영상 비율(9:16, §6.1)로 맞춘다.
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
import '../../../ads_test/presentation/admob_test_banner.dart';
import '../../../ad_banner/presentation/ad_banner_widget.dart';
import 'sintong_home_v2_tokens.dart';
import 'widgets/sintong_hero_video.dart';
import 'widgets/sintong_v2_topbar.dart';
import 'widgets/sintong_chip_row.dart';
import 'widgets/sintong_v2_sheet.dart';

/// [§6.1 히어로 영역 스펙] 영상/포스터와 동일한 9:16 비율. REQ-06
/// (CLS 방지)을 Flutter에서는 AspectRatio 위젯이 그대로 보장한다 —
/// 영상이 로드되기 전(포스터만 보이는 상태)과 로드된 후 영역 크기가
/// 항상 동일하다.
const double sHeroAspectRatio = 9 / 16;

class SintongHomeV2Screen extends StatefulWidget {
  const SintongHomeV2Screen({super.key});

  @override
  State<SintongHomeV2Screen> createState() => _SintongHomeV2ScreenState();
}

class _SintongHomeV2ScreenState extends State<SintongHomeV2Screen> {
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
        // [스크롤 버그 수정] 기존 Column+Expanded 구조는 시트/광고 등
        // 화면에 담을 콘텐츠가 늘어나도 넘치는 부분이 잘려 보이고,
        // 모바일에서 아래로 스크롤이 전혀 되지 않는 문제가 있었다
        // (사용자 피드백: "휴대폰으로 밑으로 내려가지지도 않아").
        // 전체를 SingleChildScrollView로 감싸 히어로 아래로 시트/광고
        // 콘텐츠가 자연스러운 높이만큼 이어지고 필요 시 스크롤되도록
        // 한다.
        //
        // [사진 잘림 방지 — 2026-09-24] 기존 고정 `height: 460` 박스는
        // 실제 사진 비율(9:16.1)보다 훨씬 넓적해 BoxFit.cover가 인물을
        // 크게 잘라냈다(사용자 스크린샷 확인). AspectRatio로 감싸 원본
        // 비율 그대로 사진 전체가 보이게 하고, 늘어난 높이만큼 아래
        // "전체보기" 시트가 더 아래로 밀려 내려가는 것은 사용자가 직접
        // 확인 후 허용함("밑에 전체보기 섹션을 좀더 내려도 괜찮아").
        child: SingleChildScrollView(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: sHeroAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const SintongHeroVideo(),
                    // [§6.1 오버레이 콘텐츠 — 하단 30% 그라데이션 +
                    // 타이틀/설명] 캐러셀에는 슬라이드별 6종 캡션이
                    // 있었지만, 영상은 콘텐츠가 하나이므로 실제 영상
                    // 말미(28.5s)에 등장하는 카피와 동일한 문구를
                    // 고정 오버레이로 노출한다(§6.3 CSS pointer-events:
                    // none과 동일하게 IgnorePointer로 감싸 아래 칩
                    // 탭을 막지 않는다).
                    // [칩 로우와 겹치지 않도록 배치] 칩 로우가
                    // bottom:54~86(높이 32) 구간을 차지하므로, 캡션은
                    // 그 위(bottom:100)부터 위로 펼쳐지게 배치한다.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 100,
                      child: IgnorePointer(
                        child: _HeroVideoCaption(),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SintongV2TopBar(),
                    ),
                    // [지시서 §2] 인디케이터(SintongDotsIndicator)는
                    // 영상 진행 표시가 필요 없어 완전히 제거했다. 칩
                    // 로우는 기존과 동일한 위치(bottom: 54)에 유지.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 54,
                      child: SintongChipRow(),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -20),
                child: const SintongV2Sheet(),
              ),
              // [광고 복원] v1 home_screen.dart에 있던 CMS 제휴광고 배너와
              // 애드몹 테스트 배너가 v2 교체 시 누락되어 있었다(사용자
              // 피드백 "광고도 안 넣어져있고"). 동일한 두 위젯을 그대로
              // 재사용해 시트 아래에 복원한다(신규 로직 없음).
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  color: SHomeV2Colors.sheetBg,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: const [
                      AdBannerWidget(position: 'home_top'),
                      SizedBox(height: 10),
                      AdmobTestBanner(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [§6.1 오버레이 콘텐츠] 히어로 영상 위에 고정 노출하는 eyebrow +
/// 설명 캡션. 실제 영상 말미(28.5s)에 로고와 함께 등장하는 카피
/// ("사주는 나의 이야기를 읽는 것입니다")를 그대로 재사용해, 자동재생
/// 여부·재생 위치와 무관하게 서비스 메시지가 항상 보이도록 한다.
class _HeroVideoCaption extends StatelessWidget {
  const _HeroVideoCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '신통방통 · 神通方通',
            textAlign: TextAlign.center,
            style: SHomeV2Text.heroEyebrow(),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              '사주는 나의 이야기를 읽는 것입니다',
              textAlign: TextAlign.center,
              style: SHomeV2Text.heroSub().copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
