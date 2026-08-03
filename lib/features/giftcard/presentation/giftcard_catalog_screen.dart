import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/giftcard_provider.dart';
import '../domain/giftcard_model.dart';
import 'widgets/giftcard_card.dart';

/// 03단계 §7.6 카탈로그형 표준패턴 - GiftcardCatalogScreen(상품권 상점)
/// 06§4.10 `GET /v1/giftcards/products` 대응 화면.
/// 카드 탭 시 GiftcardDetailScreen으로 이동(상세진입→교환하기CTA→확인모달→완료화면, Phase14-2).
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

  void _openDetail(GiftcardProductModel product) {
    Navigator.of(
      context,
    ).pushNamed('/reward/giftcard/detail', arguments: product);
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
                '${wallet.balance}개',
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
                    childAspectRatio: 0.68,
                  ),
                  itemCount: giftcard.products.length,
                  itemBuilder: (context, index) {
                    final product = giftcard.products[index];
                    return GiftcardCard(
                      product: product,
                      onTap: () => _openDetail(product),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
