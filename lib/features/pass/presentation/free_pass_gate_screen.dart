import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/domain/assets/open_pass_state.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../subscription/application/subscription_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/pass_provider.dart';
import 'pass_gate_helper.dart';

/// [신규 화면 - 프리패스 안내] 딥링크/푸시/공유 URL로 앱에 진입했을 때
/// 풀스크린 단독으로 보여주는 프리패스 소개 화면.
///
/// [pass_gate_helper.dart의 showPassRequiredSheet()와 다른 점]
/// - showPassRequiredSheet()는 "카테고리를 보다가 막혔을 때" 뜨는 바텀시트
///   (쿠팡파트너스 유도 플로우로 즉시 연결)이고, 이 화면은 그와 별개로
///   "프리패스 자체를 소개하는" 풀스크린 랜딩 화면이다.
/// - 이 화면 자체는 결제/구독/인앱결제/광고를 직접 트리거하지 않는다.
///   [PassProvider]/[SubscriptionProvider]/[WalletProvider]는 오직 현재
///   상태를 read-only로 보여주기 위해서만 구독한다(load()는 값을 새로
///   가져오는 것뿐이고, 결제/보상 지급 로직은 이 화면에 전혀 없다).
/// - "지금 프리패스 열어보기" 버튼은 기존 [showPassRequiredSheet]를 그대로
///   호출해, 실제 발급 플로우(쿠팡파트너스 단일 흐름)는 그 기존 함수가
///   전담한다(이 화면에서 새로 만들지 않음).
///
/// [프리패스 진입 화면 개편 · DEV-2026-1011-01, 2026-10-11] REQ-02 §5.1
/// 전수조사 결과, 이 화면으로 들어오는 유일한 진입점이었던 홈 하단
/// 프리패스 버튼(`SintongFreePassBar`)이 쿠팡파트너스 팝업 직접 호출로
/// 변경되면서, 현재 코드베이스에는 이 화면에 도달하는 경로가 없다
/// (도달 불가 코드, dead code). '/free-pass-gate' 라우트와 이 파일은
/// 지시서에 따라 삭제하지 않고 그대로 유지한다(리소스 정리는 별도 이슈).
class FreePassGateScreen extends StatefulWidget {
  const FreePassGateScreen({super.key});

  @override
  State<FreePassGateScreen> createState() => _FreePassGateScreenState();
}

class _FreePassGateScreenState extends State<FreePassGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // [read-only 조회] 딥링크로 바로 들어온 경우 최신 상태를 한 번
      // 새로고침한다. 여기서 어떤 보상/구매/결제도 호출하지 않는다.
      context.read<PassProvider>().load();
      context.read<WalletProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final passState = access.openPassState;
    final wallet = context.watch<WalletProvider>();
    final subscription = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnifiedTokens.spaceXl,
          ),
          child: Column(
            children: [
              const SizedBox(height: UnifiedTokens.spaceMd),
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: UnifiedColors.cardAllMenu,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusMd,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: UnifiedTokens.iconMd,
                      color: UnifiedColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: UnifiedTokens.spaceXl),
                      FadeSlideIn(
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: UnifiedColors.cardAllMenu,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '🔮',
                            style: TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                      const SizedBox(height: UnifiedTokens.spaceXl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 40),
                        child: Text(
                          '프리패스 안내',
                          style: UnifiedText.titleLarge(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: UnifiedTokens.spaceSm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 60),
                        child: Text(
                          '프리패스 하나면 80여 가지 운세를\n제한 없이 열어볼 수 있어요',
                          style: UnifiedText.body(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: UnifiedTokens.spaceXxl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _StatusCard(
                          passState: passState,
                          walletBalance: wallet.balance,
                          isPremium: subscription.isPremium,
                        ),
                      ),
                      const SizedBox(height: UnifiedTokens.spaceXl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: const _BenefitList(),
                      ),
                      const SizedBox(height: UnifiedTokens.spaceXxl),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceLg),
                child: Column(
                  children: [
                    if (!passState.isActive)
                      PremiumButton.black(
                        label: '지금 프리패스 열어보기',
                        onPressed: () => showPassRequiredSheet(
                          context,
                          categoryTitle: '프리패스',
                        ),
                      )
                    else
                      PremiumButton.secondary(
                        label: '홈으로 돌아가기',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    const SizedBox(height: UnifiedTokens.spaceSm),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text('나중에 할게요', style: UnifiedText.caption()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 현재 프리패스/복주머니/구독 상태를 read-only로 보여주는 요약 카드.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.passState,
    required this.walletBalance,
    required this.isPremium,
  });

  final OpenPassState passState;
  final int walletBalance;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: passState.isActive
          ? UnifiedColors.passBar
          : UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [반응형 화면 규격 통일 지시서] 아이콘+상태 라벨 Row가
          // Spacer()로 remainingLabel을 오른쪽 끝에 붙이는 구조였는데,
          // 두 Text 모두 Flexible/Expanded 보호가 전혀 없어 레거시
          // 시간제+횟수 겸용 문구(예: "기존 시간제 이용권 보유 ·
          // 999999회 남음")처럼 긴 remainingLabel이 내려오면 좁은
          // 화면에서 RenderFlex 오버플로가 발생했다(실측: 최대
          // 854px). SizedBox(width: double.infinity) + Wrap
          // (spaceBetween)으로 바꿔, 공간이 충분하면 기존과 완전히
          // 동일하게 한 줄로 보이고 부족할 때만 두 번째 줄로 자연스럽게
          // 줄바꿈되도록 한다(explore_screen.dart/login_screen.dart에서
          // 검증된 동일 패턴 재사용).
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      passState.isActive
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      size: UnifiedTokens.iconMd,
                      color: passState.isActive
                          ? Colors.white
                          : UnifiedColors.textPrimary,
                    ),
                    const SizedBox(width: UnifiedTokens.spaceSm),
                    Flexible(
                      child: Text(
                        passState.isActive ? '프리패스 이용 중' : '프리패스 미사용',
                        style: UnifiedText.bodyStrong(
                          color: passState.isActive
                              ? Colors.white
                              : UnifiedColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                if (passState.isActive && passState.remainingLabel != null)
                  Text(
                    passState.remainingLabel!,
                    style: UnifiedText.chipLabel(color: UnifiedColors.neon),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Divider(
            color: passState.isActive
                ? Colors.white.withValues(alpha: 0.15)
                : UnifiedColors.border,
            height: 1,
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          // [반응형 화면 규격 통일 지시서] 복주머니 개수 + 구독 배지 Row도
          // 보호 장치 없이 나열돼 있어, 복주머니 잔액이 매우 큰 숫자이고
          // 동시에 구독 중일 때 좁은 화면에서 오버플로가 발생했다(실측:
          // 최대 479px). Wrap으로 교체해 공간이 부족할 때만 구독 배지가
          // 다음 줄로 자연스럽게 내려가도록 한다 — 두 클러스터 사이 간격은
          // 기존 SizedBox(width: spaceMd)와 동일하게 Wrap의 spacing으로,
          // 아이콘·텍스트 사이 간격은 기존처럼 내부 Row의 SizedBox(6)로 유지한다.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: UnifiedTokens.spaceMd,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    size: UnifiedTokens.iconSm,
                    color: passState.isActive
                        ? Colors.white70
                        : UnifiedColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '복주머니 $walletBalance개',
                      style: UnifiedText.caption(
                        color: passState.isActive
                            ? Colors.white70
                            : UnifiedColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (isPremium)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      size: UnifiedTokens.iconSm,
                      color: passState.isActive
                          ? Colors.white70
                          : UnifiedColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '구독 이용 중',
                        style: UnifiedText.caption(
                          color: passState.isActive
                              ? Colors.white70
                              : UnifiedColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 프리패스 혜택 소개 리스트(정적 설명 텍스트, 상호작용 없음).
class _BenefitList extends StatelessWidget {
  const _BenefitList();

  static const _benefits = [
    (Icons.auto_stories_outlined, '80여 가지 운세 카테고리를 제한 없이 열람'),
    (Icons.style_outlined, '타로·궁합·관상·손금까지 한 번에'),
    (Icons.bolt_outlined, '광고 시청만으로 간편하게 발급'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, text) in _benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: UnifiedTokens.iconMd,
                  color: UnifiedColors.textPrimary,
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Expanded(child: Text(text, style: UnifiedText.body())),
              ],
            ),
          ),
      ],
    );
  }
}
