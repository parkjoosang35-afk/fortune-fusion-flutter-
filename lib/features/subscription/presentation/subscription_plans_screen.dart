import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/subscription_provider.dart';
import '../domain/subscription_model.dart';
import 'subscription_checkout_screen.dart';

/// 03단계 §6.4/§7.6 프리미엄 구독 전환 플로우 - SubscriptionPlansScreen(요금제 비교)
/// 02§21 사용자흐름 ①: Free vs Premium 비교 → 플랜 선택(월간/연간) → 결제화면
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadPlans();
      context.read<SubscriptionProvider>().loadMySubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final isSubscribed = provider.isPremium;

    return Scaffold(
      appBar: AppBar(title: const Text('프리미엄 구독')),
      body: SafeArea(
        child: provider.isLoadingPlans && provider.plans.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: AppColors.mysticGradient,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.premiumGold,
                          size: 32,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          isSubscribed ? '프리미엄 이용 중이에요' : '프리미엄으로 무제한 이용하세요',
                          style: const TextStyle(
                            color: AppColors.onDeepSpace,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '심층 AI 해석과 무제한 이용, 광고 제거까지',
                          style: TextStyle(
                            color: AppColors.onDeepSpace,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ...provider.plans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PlanCard(
                        plan: plan,
                        isCurrentPlan:
                            isSubscribed &&
                            provider.mySubscription!.plan.id == plan.id,
                        onSelect: plan.price <= 0
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SubscriptionCheckoutScreen(plan: plan),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlanModel plan;
  final bool isCurrentPlan;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.onSelect,
  });

  bool get _isPremium => plan.price > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: _isPremium ? AppColors.premiumGold : AppColors.divider,
          width: _isPremium ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '이용중',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.price <= 0
                ? '무료'
                : '${plan.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원 / ${plan.period == SubscriptionPeriod.yearly ? '연' : '월'}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _isPremium ? AppColors.premiumGold : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...plan.benefits.map(
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
                  Expanded(
                    child: Text(b, style: const TextStyle(fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ),
          if (onSelect != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrentPlan ? null : onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.premiumGold,
                  foregroundColor: AppColors.textPrimary,
                ),
                child: Text(isCurrentPlan ? '이용 중인 플랜' : '이 플랜 구독하기'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
