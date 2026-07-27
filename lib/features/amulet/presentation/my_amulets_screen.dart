import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/amulet_provider.dart';
import '../domain/user_amulet_model.dart';
import 'widgets/amulet_card.dart';

/// 03단계 §3.3 리워드 탭 - MyAmuletsScreen(보유목록/도감)
/// 06§4.8 `GET /v1/amulets/my` + `POST /:id/use` + `POST /:id/equip` 대응 화면.
/// 03§9.2 재사용 패턴("내 보관함" 계열) - 탭(보유목록/도감) 구조.
class MyAmuletsScreen extends StatefulWidget {
  const MyAmuletsScreen({super.key});

  @override
  State<MyAmuletsScreen> createState() => _MyAmuletsScreenState();
}

class _MyAmuletsScreenState extends State<MyAmuletsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AmuletProvider>().loadMyAmulets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleEquip(UserAmuletModel amulet) async {
    final provider = context.read<AmuletProvider>();
    final ok = await provider.equip(amulet.id);
    if (!mounted) return;
    AppToast.show(
      context,
      ok
          ? '${amulet.item.name}을 장착했습니다.'
          : (provider.actionError ?? '장착에 실패했습니다.'),
      isError: !ok,
    );
  }

  Future<void> _handleUse(UserAmuletModel amulet) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${amulet.item.name} 사용',
      message: '이 부적을 지금 사용하시겠습니까? 사용 후에는 되돌릴 수 없습니다.',
      confirmLabel: '사용',
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<AmuletProvider>();
    final ok = await provider.use(amulet.id);
    if (!mounted) return;
    AppToast.show(
      context,
      ok
          ? '${amulet.item.name}을 사용했습니다.'
          : (provider.actionError ?? '사용에 실패했습니다.'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AmuletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 부적'),
        actions: [
          IconButton(
            tooltip: '선물하기',
            icon: const Icon(Icons.card_giftcard_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed('/reward/amulet/gift'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '보유 부적'),
            Tab(text: '도감'),
          ],
        ),
      ),
      body: SafeArea(
        child: provider.isMyAmuletsLoading && provider.myAmulets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _HeldTab(
                    amulets: provider.myAmulets,
                    onRefresh: provider.loadMyAmulets,
                    onEquip: _handleEquip,
                    onUse: _handleUse,
                  ),
                  _CollectionTab(entries: provider.collection),
                ],
              ),
      ),
    );
  }
}

class _HeldTab extends StatelessWidget {
  final List<UserAmuletModel> amulets;
  final Future<void> Function() onRefresh;
  final void Function(UserAmuletModel) onEquip;
  final void Function(UserAmuletModel) onUse;

  const _HeldTab({
    required this.amulets,
    required this.onRefresh,
    required this.onEquip,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final held = amulets
        .where((a) => a.status == UserAmuletStatus.held)
        .toList();
    final others = amulets
        .where((a) => a.status != UserAmuletStatus.held)
        .toList();

    if (amulets.isEmpty) {
      return const AppEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: '보유한 부적이 없어요',
        description: '상점에서 부적을 구매해보세요',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (held.isNotEmpty) ...[
            Text('보유 중', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.72,
              ),
              itemCount: held.length,
              itemBuilder: (context, index) {
                final amulet = held[index];
                return AmuletCard(
                  item: amulet.item,
                  isEquipped: amulet.isEquipped,
                  trailing: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: amulet.isEquipped
                              ? null
                              : () => onEquip(amulet),
                          child: Text(amulet.isEquipped ? '장착중' : '장착'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => onUse(amulet),
                          child: const Text('사용하기'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('지난 부적', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ...others.map((a) => _PastAmuletTile(amulet: a)),
          ],
        ],
      ),
    );
  }
}

class _PastAmuletTile extends StatelessWidget {
  final UserAmuletModel amulet;
  const _PastAmuletTile({required this.amulet});

  String get _statusLabel {
    switch (amulet.status) {
      case UserAmuletStatus.used:
        return '사용 완료';
      case UserAmuletStatus.expired:
        return '만료됨';
      case UserAmuletStatus.gifted:
        return '선물함';
      case UserAmuletStatus.held:
        return '보유중';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        ),
        child: Row(
          children: [
            Text(amulet.item.iconEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                amulet.item.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                _statusLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTab extends StatelessWidget {
  final List<AmuletCollectionEntry> entries;
  const _CollectionTab({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: '아직 도감이 비어있어요',
        description: '부적을 획득하면 도감에 기록됩니다',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.78,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return AmuletCard(
          item: entry.item,
          trailing: Text(
            '보유 ${entry.totalCount}개 · 첫 획득 '
            '${entry.firstAcquiredAt.year}.${entry.firstAcquiredAt.month}.${entry.firstAcquiredAt.day}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}
