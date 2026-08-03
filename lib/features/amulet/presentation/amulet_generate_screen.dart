import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/amulet_provider.dart';
import '../domain/amulet_item_model.dart';
import 'widgets/amulet_acquired_dialog.dart';

/// 03단계 §3.3 / 06§4.8 `POST /v1/amulets/generate` 대응
/// AI 생성형 부적(isAiGenerated=true 상품) 선택 → 생성 요청 → 결과 애니메이션 화면.
/// 입력형(선택) + 로딩형(생성중) 패턴을 한 화면 내 상태 전환으로 구성한다.
class AmuletGenerateScreen extends StatefulWidget {
  const AmuletGenerateScreen({super.key});

  @override
  State<AmuletGenerateScreen> createState() => _AmuletGenerateScreenState();
}

enum _GenerateStep { select, generating }

class _AmuletGenerateScreenState extends State<AmuletGenerateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  _GenerateStep _step = _GenerateStep.select;
  AmuletItemModel? _selected;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AmuletProvider>().loadShop();
      context.read<WalletProvider>().load();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final base = _selected;
    if (base == null) return;
    final wallet = context.read<WalletProvider>();
    final amuletProvider = context.read<AmuletProvider>();

    if (wallet.balance < base.pricePoint) {
      AppToast.show(
        context,
        '복주머니가 부족합니다. (보유 ${wallet.balance}개)',
        isError: true,
      );
      return;
    }

    setState(() => _step = _GenerateStep.generating);

    final spent = await wallet.spend(base.pricePoint, '${base.name} AI 생성 요청');
    if (!mounted) return;
    if (!spent) {
      setState(() => _step = _GenerateStep.select);
      AppToast.show(context, '복주머니 차감에 실패했습니다.', isError: true);
      return;
    }

    final ok = await amuletProvider.generate(base.id);
    if (!mounted) return;

    if (ok) {
      setState(() => _step = _GenerateStep.select);
      // 03§10.2 부적 획득 애니메이션(봉투펼침+골드광택스윕) 공용 다이얼로그 재사용
      await AmuletAcquiredDialog.show(context, item: base);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/reward/amulet/my');
    } else {
      // 예외처리: 생성 실패 시 차감된 복주머니 환불(rollback)
      await wallet.earn(base.pricePoint, '${base.name} 생성 실패 환불');
      if (!mounted) return;
      setState(() => _step = _GenerateStep.select);
      AppToast.show(
        context,
        amuletProvider.actionError ?? '생성에 실패했습니다. 복주머니가 환불되었습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 부적 생성')),
      body: SafeArea(
        child: switch (_step) {
          _GenerateStep.select => _buildSelect(context),
          _GenerateStep.generating => _buildGenerating(context),
        },
      ),
    );
  }

  Widget _buildSelect(BuildContext context) {
    final amulet = context.watch<AmuletProvider>();
    final wallet = context.watch<WalletProvider>();
    final aiItems = amulet.shopItems.where((i) => i.isAiGenerated).toList();

    if (amulet.isShopLoading && amulet.shopItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (aiItems.isEmpty) {
      return const AppEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'AI 생성 가능한 부적이 없어요',
        description: '추후 업데이트를 기다려주세요',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.mysticGradient,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.secondary),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'AI가 당신만을 위한 특별한 부적을 생성합니다',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('생성할 부적 선택', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...aiItems.map(
            (item) => _SelectableTile(
              item: item,
              selected: _selected?.id == item.id,
              onTap: () => setState(() => _selected = item),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: _selected == null
                ? 'AI 부적 생성하기'
                : '${_selected!.pricePoint}개로 생성하기',
            onPressed: _selected == null ? null : _generate,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              '보유 ${wallet.balance}개',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerating(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.15).animate(_pulseController),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.secondary,
                size: 72,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'AI가 부적을 생성하고 있어요...',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '잠시만 기다려주세요',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final AmuletItemModel item;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : Colors.white,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Text(item.iconEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      item.effectDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${item.pricePoint}개',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
