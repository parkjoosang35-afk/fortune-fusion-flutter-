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
        '복주머니가 부족합니다. (보유 ${wallet.balance}개)',
        isError: true,
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: '${product.name} 교환',
      message: '복주머니 ${product.requiredPoint}개를 사용하여 교환하시겠습니까?',
      confirmLabel: '교환하기',
    );
    if (!confirmed || !context.mounted) return;

    // 02§14 사용자흐름: 교환신청 → 발급대기 → 발급완료/실패.
    // [전수검수 2026-10-12 C-2/GIFTCARD-01] 차감·재고·발급을 서버 단일
    // 트랜잭션으로 이관한다(chargeMode: server) — 기존 클라이언트
    // 오케스트레이션은 (a) spend 대기 구간의 이중 탭으로 중복 차감이
    // 가능했고(GIFTCARD-01) (b) orderProduct 직접 호출로 무료 발급이
    // 가능한 서버 구멍(C-2)의 원인이었다.
    final issue = await giftcard.orderProduct(product.id, chargeMode: 'server');
    wallet.load(); // 성공/실패 무관 서버 차감·환원 결과를 즉시 반영.
    if (!context.mounted) return;

    if (issue == null || issue.status == GiftcardIssueStatus.failed) {
      // [전수검수 2026-10-12] 발급 실패 시 차감도 서버 트랜잭션이 함께
      // 롤백하므로 클라이언트 환불(earn) 경로는 제거됐다 — 지갑은 위
      // load()로 최신화된다(WALLET-01/GIFTCARD-02 무음 환불 유실 결함도
      // 이 경로 삭제로 함께 소멸).
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
                  '${product.requiredPoint}개',
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
                      label: '보유 복주머니',
                      value: '${wallet.balance}개',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '교환 신청 시 복주머니가 즉시 차감되며, 발급에 실패할 경우 복주머니는 자동으로 환불됩니다.',
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
