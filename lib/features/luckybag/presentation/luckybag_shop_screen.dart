import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/luckybag_provider.dart';
import '../domain/luckybag_product_model.dart';
import 'widgets/luckybag_card.dart';
import 'widgets/luckybag_probability_sheet.dart';

/// 03단계 §3.3 리워드 탭 - LuckyBagShopScreen(행복머니 상점)
/// 06§4.9 `GET /v1/luckybags` + `GET /:id/probabilities` 대응 화면.
/// "열어보기" CTA는 Phase10-3(LuckyBagOpenAnimationScreen)에서 라우팅 연결 예정.
class LuckyBagShopScreen extends StatefulWidget {
  const LuckyBagShopScreen({super.key});

  @override
  State<LuckyBagShopScreen> createState() => _LuckyBagShopScreenState();
}

class _LuckyBagShopScreenState extends State<LuckyBagShopScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LuckyBagProvider>().loadProducts();
      context.read<WalletProvider>().load();
    });
  }

  Future<void> _showProbabilities(LuckyBagProductModel product) async {
    await context.read<LuckyBagProvider>().loadProbabilities(product.id);
    if (!mounted) return;
    await showLuckyBagProbabilitySheet(context, product: product);
  }

  Future<void> _openBag(LuckyBagProductModel product) async {
    final wallet = context.read<WalletProvider>();
    if (wallet.balance < product.pricePoint) {
      AppToast.show(
        context,
        '행복머니가 부족합니다. (보유 ${wallet.balance}P)',
        isError: true,
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${product.name} 열기',
      message: '${product.pricePoint}P를 사용하여 행복머니를 여시겠습니까?',
      confirmLabel: '열기',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(
      context,
    ).pushNamed('/reward/luckybag/open', arguments: product);
  }

  @override
  Widget build(BuildContext context) {
    final luckybag = context.watch<LuckyBagProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('행복머니'),
        actions: [
          IconButton(
            tooltip: '개봉 이력',
            icon: const Icon(Icons.history_rounded),
            onPressed: () =>
                Navigator.of(context).pushNamed('/reward/luckybag/history'),
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
        child: luckybag.isProductsLoading && luckybag.products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : luckybag.products.isEmpty
            ? const AppEmptyState(
                icon: Icons.card_giftcard_outlined,
                title: '판매 중인 행복머니가 없어요',
              )
            : RefreshIndicator(
                onRefresh: () => luckybag.loadProducts(),
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: luckybag.products.length,
                  itemBuilder: (context, index) {
                    final product = luckybag.products[index];
                    return LuckyBagCard(
                      product: product,
                      trailing: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              label: '열어보기',
                              onPressed: () => _openBag(product),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => _showProbabilities(product),
                              child: const Text(
                                '확률 보기',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
