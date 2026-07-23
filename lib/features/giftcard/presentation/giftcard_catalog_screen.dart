import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/giftcard_provider.dart';
import '../domain/giftcard_model.dart';
import 'widgets/giftcard_card.dart';

/// 03단계 §7.6 카탈로그형 표준패턴 + §5.3 화면목록 - GiftcardCatalogScreen(상품권 상점)
/// 06§4.10 `GET /v1/giftcards/products` + `POST /v1/giftcards/orders` 대응 화면.
/// LuckyBagShopScreen과 동일한 카탈로그 UI 패턴(그리드카드+교환하기CTA+확인다이얼로그)을 재사용.
class GiftcardCatalogScreen extends StatefulWidget {
  const GiftcardCatalogScreen({super.key});

  @override
  State<GiftcardCatalogScreen> createState() => _GiftcardCatalogScreenState();
}

class _GiftcardCatalogScreenState extends State<GiftcardCatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GiftcardProvider>().loadProducts();
      context.read<WalletProvider>().load();
    });
  }

  Future<void> _orderProduct(GiftcardProductModel product) async {
    final wallet = context.read<WalletProvider>();
    final giftcard = context.read<GiftcardProvider>();

    if (wallet.balance < product.requiredPoint) {
      AppToast.show(
        context,
        '포인트가 부족합니다. (보유 ${wallet.balance}P)',
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
    if (!confirmed || !mounted) return;

    // 02§14 사용자흐름: 교환신청 → 포인트차감 → 발급대기 → 발급완료/실패.
    // WalletService.spend 단일 인터페이스 원칙(02§1.2)에 따라 화면 레이어에서
    // 먼저 포인트를 차감하고, 발급이 실패하면 즉시 환불(earn)로 보상 처리한다.
    final spent = await wallet.spend(
      product.requiredPoint,
      '상품권 교환 - ${product.name}',
    );
    if (!spent) {
      if (!mounted) return;
      AppToast.show(context, '포인트 차감에 실패했습니다.', isError: true);
      return;
    }

    final issue = await giftcard.orderProduct(product.id);
    if (!mounted) return;

    if (issue == null || issue.status == GiftcardIssueStatus.failed) {
      // 발급 실패 - 포인트 자동 환불(트랜잭션 보상처리, 02§14 예외처리)
      await wallet.earn(
        product.requiredPoint,
        '상품권 발급 실패 환불 - ${product.name}',
      );
      if (!mounted) return;
      AppToast.show(context, '발급에 실패하여 포인트가 환불되었습니다.', isError: true);
      await giftcard.loadProducts();
      return;
    }

    AppToast.show(context, '교환 완료! 내 상품권함에서 확인하세요.');
    await giftcard.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final giftcard = context.watch<GiftcardProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('상품권'),
        actions: [
          IconButton(
            tooltip: '내 상품권함',
            icon: const Icon(Icons.card_giftcard_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed('/reward/giftcard/my'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                '${wallet.balance} P',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: giftcard.isProductsLoading && giftcard.products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : giftcard.products.isEmpty
            ? const AppEmptyState(
                icon: Icons.card_giftcard_outlined,
                title: '판매 중인 상품권이 없어요',
              )
            : RefreshIndicator(
                onRefresh: () => giftcard.loadProducts(),
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: giftcard.products.length,
                  itemBuilder: (context, index) {
                    final product = giftcard.products[index];
                    return GiftcardCard(
                      product: product,
                      trailing: SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: product.inStock ? '교환하기' : '품절',
                          onPressed: product.inStock && !giftcard.isOrdering
                              ? () => _orderProduct(product)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
