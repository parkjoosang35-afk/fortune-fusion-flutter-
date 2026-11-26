import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../pass/application/pass_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/subscription_provider.dart';
import '../domain/subscription_model.dart';
import 'my_subscription_screen.dart';

/// 03단계 §6.4 SubscriptionCheckoutScreen
/// [Google Play Billing 실연동 — 2026-11-26] plan.canRealPurchase(=
/// googlePlayProductId 등록됨)이면 Google Play 결제창을 띄우는 실결제,
/// 아니면("정책준비중") 기존 서버 시뮬레이션 결제로 분기한다. 화면 UI는
/// 실제 결제 주체가 Google Play임을 명확히 안내하고, Play 정책이 요구하는
/// 자동갱신/해지방법 고지문구를 포함한다(카드/PG사 선택 UI는 실결제와
/// 맞지 않아 제거함 — Google Play가 자체 결제 시트를 담당한다).
class SubscriptionCheckoutScreen extends StatefulWidget {
  final SubscriptionPlanModel plan;
  const SubscriptionCheckoutScreen({super.key, required this.plan});

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  bool _agreeTerms = false;

  Future<void> _pay() async {
    final provider = context.read<SubscriptionProvider>();
    // [Google Play Billing 실연동] googlePlayProductId가 등록된 플랜은 실제
    // Google Play 결제창을 띄우는 흐름으로, 미등록("정책준비중") 플랜은 기존
    // 서버 시뮬레이션 결제로 분기한다(두 경로가 공존하는 과도기 설계).
    final result = widget.plan.canRealPurchase
        ? await provider.subscribeReal(widget.plan)
        : await provider.subscribe(widget.plan);
    if (!mounted) return;
    if (result.success) {
      // [2단계 구독 연동] 구독 성공 시 서버(subscribe/route.ts)가 열림패스를
      // 자동 발급하고 복주머니 보너스를 지급하므로, 클라이언트는 PassProvider/
      // WalletProvider를 즉시 재조회해 홈/운세 탭 상태를 최신화한다.
      await Future.wait([
        context.read<PassProvider>().load(),
        context.read<WalletProvider>().load(),
      ]);
      if (!mounted) return;
      AppToast.show(context, '구독이 시작되었습니다! 프리패스와 복주머니 보너스가 지급되었어요 🎉');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MySubscriptionScreen()),
      );
    } else {
      AppToast.show(
        context,
        result.errorMessage ?? '결제에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final plan = widget.plan;
    final priceText = plan.price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final periodLabel = plan.period == SubscriptionPeriod.yearly ? '연간' : '월간';
    final nextLabel = plan.period == SubscriptionPeriod.yearly ? '1년 뒤' : '한 달 뒤';

    return Scaffold(
      appBar: AppBar(title: const Text('결제하기')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$priceText원 / $periodLabel 정기결제',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('결제 수단', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shop_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Google Play 결제',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                plan.canRealPurchase
                                    ? '등록된 Google 계정의 결제 수단으로 안전하게 결제돼요'
                                    : '현재 준비 중인 플랜이에요 (체험용 결제)',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.radio_button_checked_rounded,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '결제 전 꼭 확인해주세요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _NoticeBox(
                    items: [
                      '결제는 Google Play를 통해 처리되며, 카드 정보는 앱/서버에 저장되지 않아요.',
                      '구독은 $periodLabel 단위로 자동 갱신되며, 다음 결제일 24시간 전까지 해지하지 않으면 자동으로 $priceText원이 결제돼요.',
                      '해지는 Play 스토어 앱 > 결제 및 구독 메뉴에서 언제든 직접 하실 수 있어요(앱 내 [내 구독] 화면에서도 가능).',
                      '해지해도 이미 결제한 기간이 끝날 때까지는 혜택을 그대로 이용할 수 있어요.',
                      '복주머니를 하나라도 사용하면 해당 결제 주기에 대한 환불이 제한될 수 있어요.',
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AgreeRow(
                    value: _agreeTerms,
                    onChanged: (v) => setState(() => _agreeTerms = v),
                    label: '위 내용(정기결제 자동 갱신 및 해지 방법)을 확인했어요',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '구독 시작 시 $nextLabel 자동으로 $priceText원이 결제됩니다.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                label: '$priceText원 결제하기',
                isLoading: provider.isProcessing,
                onPressed: (!_agreeTerms || provider.isProcessing) ? null : _pay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  final List<String> items;
  const _NoticeBox({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AgreeRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const _AgreeRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              value
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: value ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
