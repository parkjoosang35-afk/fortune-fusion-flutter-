import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/luckybag_provider.dart';
import '../domain/luckybag_product_model.dart';
import 'widgets/luckybag_card.dart';
import 'widgets/luckybag_probability_sheet.dart';

/// 03단계 §3.3 리워드 탭 - LuckyBagShopScreen(복주머니 상점)
/// 06§4.9 `GET /v1/luckybags` + `GET /:id/probabilities` 대응 화면.
/// "열어보기" CTA는 Phase10-3(LuckyBagOpenAnimationScreen)에서 라우팅 연결 예정.
///
/// [복주머니 디자인 정합성 수정] 기존에는 다크 "우주(Cosmic)" 팔레트(AppColors
/// 기본 테마 색)를 그대로 쓰고 있었는데, 이 화면으로 들어오는 입구인 허브
/// (LuckyBagScreen)는 이미 화이트+라벤더 Unified 톤으로 리뉴얼되어 있어 진입
/// 즉시 화면이 통째로 바뀌는 이질감이 있었다. 허브와 동일한 팔레트/타이포로
/// 전면 재작성한다(기능·Provider·라우팅은 완전히 동일하게 유지).
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
        '복주머니가 부족합니다. (보유 ${wallet.balance}개)',
        isError: true,
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${product.name} 열기',
      message: '복주머니 ${product.pricePoint}개를 사용하여 여시겠습니까?',
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
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('복주머니', style: UnifiedText.titleLarge()),
        actions: [
          IconButton(
            tooltip: '개봉 이력',
            icon: const Icon(
              Icons.history_rounded,
              color: UnifiedColors.textPrimary,
            ),
            onPressed: () =>
                Navigator.of(context).pushNamed('/reward/luckybag/history'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: UnifiedTokens.spaceLg),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: UnifiedColors.cardAllMenu,
                  borderRadius: BorderRadius.circular(
                    UnifiedTokens.radiusPill,
                  ),
                ),
                child: Text(
                  '${wallet.balance}개',
                  style: UnifiedText.chipLabel(),
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
                title: '판매 중인 복주머니가 없어요',
              )
            : RefreshIndicator(
                onRefresh: () => luckybag.loadProducts(),
                child: GridView.builder(
                  padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: UnifiedTokens.spaceMd,
                    mainAxisSpacing: UnifiedTokens.spaceMd,
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
                            child: ElevatedButton(
                              onPressed: () => _openBag(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: UnifiedColors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    UnifiedTokens.radiusPill,
                                  ),
                                ),
                              ),
                              child: Text(
                                '열어보기',
                                style: UnifiedText.chipLabel(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => _showProbabilities(product),
                              child: Text(
                                '확률 보기',
                                style: UnifiedText.caption(),
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
