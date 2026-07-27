import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/subscription_provider.dart';
import '../domain/subscription_model.dart';
import 'my_subscription_screen.dart';

/// 03단계 §6.4 SubscriptionCheckoutScreen(PG SDK/웹뷰 연동 지점)
/// 06§4.11 예외처리: 실제 PG 연동은 웹훅이 최종 확정하지만, Mock 단계에서는
/// "결제하기" 탭 시 즉시 성공/실패를 시뮬레이션한다(카드정보 직접 저장 없음).
class SubscriptionCheckoutScreen extends StatefulWidget {
  final SubscriptionPlanModel plan;
  const SubscriptionCheckoutScreen({super.key, required this.plan});

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  String _selectedMethod = 'card';

  Future<void> _pay() async {
    final provider = context.read<SubscriptionProvider>();
    final result = await provider.subscribe(widget.plan);
    if (!mounted) return;
    if (result.success) {
      AppToast.show(context, '구독이 시작되었습니다!');
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
                          '$priceText원 / ${plan.period == SubscriptionPeriod.yearly ? '연간' : '월간'} 정기결제',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('결제 수단', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _PaymentMethodTile(
                    label: '신용/체크카드',
                    icon: Icons.credit_card_rounded,
                    value: 'card',
                    selected: _selectedMethod == 'card',
                    onTap: () => setState(() => _selectedMethod = 'card'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PaymentMethodTile(
                    label: '간편결제(토스페이)',
                    icon: Icons.smartphone_rounded,
                    value: 'toss',
                    selected: _selectedMethod == 'toss',
                    onTap: () => setState(() => _selectedMethod = 'toss'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    '카드 정보는 서버에 직접 저장되지 않으며, PG사 토큰으로만 처리됩니다.',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                label: '$priceText원 결제하기',
                isLoading: provider.isProcessing,
                onPressed: provider.isProcessing ? null : _pay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label)),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
