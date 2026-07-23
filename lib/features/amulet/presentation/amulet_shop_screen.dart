import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/amulet_provider.dart';
import '../domain/amulet_item_model.dart';
import 'widgets/amulet_acquired_dialog.dart';
import 'widgets/amulet_card.dart';

/// 03단계 §3.3 리워드 탭 - AmuletShopScreen(디지털 부적 상점)
/// 06§4.8 `GET /v1/amulets/shop` + `POST /v1/amulets/purchase` 대응 화면.
/// 구매 플로우: showAppConfirmDialog → WalletProvider.spend → AmuletProvider.purchase
/// (WalletService.earn/spend 단일 인터페이스 원칙 - 02번 §1.2, 여기서 orchestrate)
class AmuletShopScreen extends StatefulWidget {
  const AmuletShopScreen({super.key});

  @override
  State<AmuletShopScreen> createState() => _AmuletShopScreenState();
}

class _AmuletShopScreenState extends State<AmuletShopScreen> {
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AmuletProvider>().loadShop();
      context.read<WalletProvider>().load();
    });
  }

  Future<void> _handlePurchase(AmuletItemModel item) async {
    final wallet = context.read<WalletProvider>();
    final amulet = context.read<AmuletProvider>();

    if (wallet.balance < item.pricePoint) {
      AppToast.show(
        context,
        '포인트가 부족합니다. (보유 ${wallet.balance}P)',
        isError: true,
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: '${item.name} 구매',
      message: '${item.pricePoint}P를 사용하여 구매하시겠습니까?',
      confirmLabel: '구매',
    );
    if (!confirmed || !mounted) return;

    setState(() => _purchasing = true);

    // 1) Wallet spend 선행
    final spent = await wallet.spend(item.pricePoint, '${item.name} 구매');
    if (!mounted) return;
    if (!spent) {
      setState(() => _purchasing = false);
      AppToast.show(context, '포인트 차감에 실패했습니다.', isError: true);
      return;
    }

    // 2) 부적 지급
    final result = await amulet.purchase(item.id);
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (result != null) {
      // 03§10.2 부적 획득 애니메이션(봉투펼침+골드광택스윕) 공용 다이얼로그 재사용
      await AmuletAcquiredDialog.show(context, item: item);
    } else {
      // 예외처리: 지급 실패 시 차감된 포인트 환불(rollback)
      await wallet.earn(item.pricePoint, '${item.name} 구매 실패 환불');
      if (!mounted) return;
      AppToast.show(
        context,
        amulet.actionError ?? '구매에 실패했습니다. 포인트가 환불되었습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final amulet = context.watch<AmuletProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('디지털 부적 상점'),
        actions: [
          IconButton(
            tooltip: '내 부적',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed('/reward/amulet/my'),
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
        child: amulet.isShopLoading && amulet.shopItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : amulet.shopItems.isEmpty
            ? const AppEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: '판매 중인 부적이 없어요',
              )
            : RefreshIndicator(
                onRefresh: () => amulet.loadShop(),
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: amulet.shopItems.length,
                  itemBuilder: (context, index) {
                    final item = amulet.shopItems[index];
                    return AmuletCard(
                      item: item,
                      trailing: SizedBox(
                        width: double.infinity,
                        child: item.isAiGenerated
                            ? AppButton.secondary(
                                label: 'AI로 생성하기',
                                icon: Icons.auto_awesome_rounded,
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed('/reward/amulet/generate'),
                              )
                            : AppButton(
                                label: '${item.pricePoint}P',
                                onPressed: _purchasing
                                    ? null
                                    : () => _handlePurchase(item),
                                fullWidth: true,
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
