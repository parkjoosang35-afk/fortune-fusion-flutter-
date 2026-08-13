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
                        onPressed: () =>
                            Navigator.of(context).maybePop(),
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
          Row(
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
              Text(
                passState.isActive ? '프리패스 이용 중' : '프리패스 미사용',
                style: UnifiedText.bodyStrong(
                  color: passState.isActive
                      ? Colors.white
                      : UnifiedColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (passState.isActive && passState.remainingLabel != null)
                Text(
                  passState.remainingLabel!,
                  style: UnifiedText.chipLabel(color: UnifiedColors.neon),
                ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Divider(
            color: passState.isActive
                ? Colors.white.withValues(alpha: 0.15)
                : UnifiedColors.border,
            height: 1,
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            children: [
              Icon(
                Icons.savings_outlined,
                size: UnifiedTokens.iconSm,
                color: passState.isActive
                    ? Colors.white70
                    : UnifiedColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '복주머니 $walletBalance개',
                style: UnifiedText.caption(
                  color: passState.isActive
                      ? Colors.white70
                      : UnifiedColors.textSecondary,
                ),
              ),
              const SizedBox(width: UnifiedTokens.spaceMd),
              if (isPremium) ...[
                Icon(
                  Icons.workspace_premium_outlined,
                  size: UnifiedTokens.iconSm,
                  color: passState.isActive
                      ? Colors.white70
                      : UnifiedColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '구독 이용 중',
                  style: UnifiedText.caption(
                    color: passState.isActive
                        ? Colors.white70
                        : UnifiedColors.textSecondary,
                  ),
                ),
              ],
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
