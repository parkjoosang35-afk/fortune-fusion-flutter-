import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/subscription_provider.dart';
import '../domain/subscription_model.dart';
import 'subscription_plans_screen.dart';

/// 03단계 §6.4/§7.6 MySubscriptionScreen(구독상태/해지/재구독)
/// 02§21 사용자흐름 ④: 다음 결제일 확인, 해지, 재구독
class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadMySubscription();
      context.read<SubscriptionProvider>().loadPaymentHistory();
    });
  }

  Future<void> _handleCancel() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '구독 해지',
      message: '구독을 해지하시겠습니까? 현재 결제 주기가 끝나면 혜택이 종료됩니다.',
      confirmLabel: '해지하기',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await context.read<SubscriptionProvider>().cancel();
    if (!mounted) return;
    AppToast.show(
      context,
      ok ? '구독이 해지되었습니다.' : '해지 처리에 실패했습니다.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final subscription = provider.mySubscription;

    return Scaffold(
      appBar: AppBar(title: const Text('내 구독')),
      body: SafeArea(
        child: provider.isLoadingSubscription && subscription == null
            ? const Center(child: CircularProgressIndicator())
            : subscription == null
            ? AppEmptyState(
                icon: Icons.workspace_premium_outlined,
                title: '구독 중인 플랜이 없어요',
                description: '프리미엄 플랜을 구독하고 무제한으로 이용해보세요',
                action: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPlansScreen(),
                    ),
                  ),
                  child: const Text('플랜 보러가기'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              subscription.plan.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _StatusBadge(status: subscription.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subscription.status == SubscriptionStatus.cancelled
                              ? '${_formatDate(subscription.currentPeriodEnd)}까지 이용 가능'
                              : '다음 결제일: ${_formatDate(subscription.currentPeriodEnd)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('이용 혜택', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...subscription.plan.benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(b),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (subscription.status == SubscriptionStatus.active)
                    OutlinedButton(
                      onPressed: _handleCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('구독 해지'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionPlansScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('재구독하기'),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('결제 내역', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (provider.paymentHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          '결제 내역이 없어요',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ),
                    )
                  else
                    ...provider.paymentHistory.map(
                      (p) => _PaymentTile(payment: p),
                    ),
                ],
              ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}.${d.month}.${d.day}';
}

class _StatusBadge extends StatelessWidget {
  final SubscriptionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SubscriptionStatus.active => ('이용중', AppColors.success),
      SubscriptionStatus.cancelled => ('해지예정', AppColors.warning),
      SubscriptionStatus.expired => ('만료됨', AppColors.textHint),
      SubscriptionStatus.pastDue => ('결제실패', AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final priceText = payment.amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        ),
        child: Row(
          children: [
            Icon(
              payment.status == PaymentStatus.paid
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
              size: 18,
              color: payment.status == PaymentStatus.paid
                  ? AppColors.success
                  : AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$priceText원'),
                  Text(
                    '${payment.createdAt.year}.${payment.createdAt.month}.${payment.createdAt.day} · ${payment.pgProvider}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
