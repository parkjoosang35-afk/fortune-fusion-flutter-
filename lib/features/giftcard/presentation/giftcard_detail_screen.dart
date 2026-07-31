import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/giftcard_provider.dart';
import '../domain/giftcard_model.dart';

/// 03단계 §7.6 카탈로그형 표준패턴 "상세진입→교환하기CTA→확인모달→완료화면"
/// GiftcardDetailScreen(상품 상세) - 06§4.10 `POST /v1/giftcards/orders` 대응.
class GiftcardDetailScreen extends StatelessWidget {
  final GiftcardProductModel product;

  const GiftcardDetailScreen({super.key, required this.product});

  Future<void> _orderProduct(BuildContext context) async {
    final wallet = context.read<WalletProvider>();
    final giftcard = context.read<GiftcardProvider>();

    if (wallet.balance < product.requiredPoint) {
      AppToast.show(
        context,
        '행복머니가 부족합니다. (보유 ${wallet.balance}P)',
        isError: true,
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: '${product.name} 교환',
      message: '${product.requiredPoint}P를 사용하여 교환하시겠습니까?',
      confirmLabel: '교환하기',
    );
    if (!confirmed || !context.mounted) return;

    // 02§14 사용자흐름: 교환신청 → 행복머니차감 → 발급대기 → 발급완료/실패.
    // WalletService.spend 단일 인터페이스 원칙(02§1.2)에 따라 화면 레이어에서
    // 먼저 행복머니를 차감하고, 발급이 실패하면 즉시 환불(earn)로 보상 처리한다.
    final spent = await wallet.spend(
      product.requiredPoint,
      '상품권 교환 - ${product.name}',
    );
    if (!spent) {
      if (!context.mounted) return;
      AppToast.show(context, '행복머니 차감에 실패했습니다.', isError: true);
      return;
    }

    final issue = await giftcard.orderProduct(product.id);
    if (!context.mounted) return;

    if (issue == null || issue.status == GiftcardIssueStatus.failed) {
      // 발급 실패 - 행복머니 자동 환불(트랜잭션 보상처리, 02§14 예외처리)
      await wallet.earn(
        product.requiredPoint,
        '상품권 발급 실패 환불 - ${product.name}',
      );
      if (!context.mounted) return;
      await giftcard.loadProducts();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/reward/giftcard/result',
        arguments:
            issue ??
            GiftcardIssueModel(
              id: 'gci_failed',
              product: product,
              pointSpent: product.requiredPoint,
              status: GiftcardIssueStatus.failed,
            ),
      );
      return;
    }

    await giftcard.loadProducts();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed('/reward/giftcard/result', arguments: issue);
  }

  @override
  Widget build(BuildContext context) {
    final giftcard = context.watch<GiftcardProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('상품권 상세')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    product.imageEmoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  product.brand,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  '${product.requiredPoint} P',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: '재고',
                      value: product.inStock
                          ? '${product.stockCount}개 남음'
                          : '품절',
                    ),
                    const Divider(height: AppSpacing.lg),
                    _InfoRow(
                      icon: Icons.event_available_outlined,
                      label: '유효기간',
                      value: '발급일로부터 ${product.validDays}일',
                    ),
                    const Divider(height: AppSpacing.lg),
                    _InfoRow(
                      icon: Icons.wallet_outlined,
                      label: '보유 행복머니',
                      value: '${wallet.balance} P',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '교환 신청 시 행복머니가 즉시 차감되며, 발급에 실패할 경우 행복머니는 자동으로 환불됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: product.inStock ? '교환하기' : '품절',
                onPressed: product.inStock && !giftcard.isOrdering
                    ? () => _orderProduct(context)
                    : null,
                isLoading: giftcard.isOrdering,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
