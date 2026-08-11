import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/customize_category.dart';
import '../../data/models/customize_item_model.dart';
import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';

/// [필수 화면 ⑦ 소원방 꾸미기 화면]
///
/// 화면 목적: 오브제/제단/배경/이펙트/장식/시즌테마 6개 카테고리를 탭으로
/// 나눠 보여주고, 각 아이템을 구매(복주머니)하거나 적용한다.
/// 핵심 CTA: "적용하기"(보유 중) / "복주머니로 구매"(미보유).
///
/// [디자인 핸드오프 — "마법진이 소환되는 신전"] 다른 화면들과 일관된
/// 대기(atmosphere) 배경([WishRoomBackground])과 화면 진입 연출
/// ([DramaticEntrance])을 적용했다. 카테고리 탭/구매/적용 로직은 그대로 유지.
class WishCustomizeScreen extends ConsumerStatefulWidget {
  const WishCustomizeScreen({super.key});

  @override
  ConsumerState<WishCustomizeScreen> createState() =>
      _WishCustomizeScreenState();
}

class _WishCustomizeScreenState extends ConsumerState<WishCustomizeScreen> {
  CustomizeCategory _selected = CustomizeCategory.objectSkin;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(wishRoomControllerProvider.notifier).loadCustomizeCatalog(),
    );
  }

  Future<void> _handleTap(CustomizeItem item) async {
    final controller = ref.read(wishRoomControllerProvider.notifier);
    if (item.isOwned) {
      await controller.applyCustomizeItem(item.id);
      return;
    }
    final success = await controller.purchaseCustomizeItem(item.id);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복주머니가 부족해요. 상점에서 채워보세요.')));
    } else {
      await controller.applyCustomizeItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(wishRoomControllerProvider);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('방 꾸미기', style: WishRoomTextStyles.titleLg),
        iconTheme: const IconThemeData(color: WishRoomColors.textPrimary),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: WishRoomBackground()),
          SafeArea(
            top: false,
            child: DramaticEntrance(
              child: asyncData.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: WishRoomColors.gold),
                ),
                error: (err, st) => Center(
                  child: Text(
                    '잠시 후 다시 시도해주세요',
                    style: WishRoomTextStyles.bodyMd,
                  ),
                ),
                data: (data) {
                  final catalog = data.customizeCatalog;
                  if (catalog.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: WishRoomColors.gold,
                      ),
                    );
                  }
                  final filtered = catalog
                      .where((c) => c.category == _selected)
                      .toList();

                  return Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: WishRoomSpacing.md,
                          ),
                          children: CustomizeCategory.values.map((category) {
                            final isSelected = category == _selected;
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: WishRoomSpacing.sm,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selected = category),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: WishRoomSpacing.md,
                                    vertical: WishRoomSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? WishRoomColors.gold.withValues(
                                            alpha: 0.85,
                                          )
                                        : WishRoomColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(
                                      WishRoomRadius.pill,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? WishRoomColors.gold
                                          : WishRoomColors.surfaceCardBorder,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    category.label,
                                    style: WishRoomTextStyles.bodySm.copyWith(
                                      color: isSelected
                                          ? WishRoomColors.backgroundDeep
                                          : WishRoomColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: WishRoomSpacing.md),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WishRoomSpacing.md,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: WishRoomSpacing.sm,
                                crossAxisSpacing: WishRoomSpacing.sm,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _CustomizeItemCard(
                            item: filtered[index],
                            onTap: _handleTap,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizeItemCard extends StatelessWidget {
  final CustomizeItem item;
  final void Function(CustomizeItem) onTap;

  const _CustomizeItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(WishRoomSpacing.md),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          borderRadius: BorderRadius.circular(WishRoomRadius.md),
          border: Border.all(
            color: item.isApplied
                ? WishRoomColors.gold
                : WishRoomColors.surfaceCardBorder,
            width: item.isApplied ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  item.previewEmoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
            Text(
              item.name,
              style: WishRoomTextStyles.bodySm.copyWith(
                color: WishRoomColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: WishRoomSpacing.xs),
            Text(
              item.isApplied
                  ? '적용중'
                  : item.isOwned
                  ? '보유중'
                  : (item.pouchPrice > 0
                        ? '👝 ${item.pouchPrice}개'
                        : item.unlockType == CustomizeUnlockType.streakReward
                        ? '연속 ${item.unlockThreshold}일 해금'
                        : '조건부 해금'),
              style: WishRoomTextStyles.caption.copyWith(
                color: item.isApplied
                    ? WishRoomColors.gold
                    : WishRoomColors.textTertiary,
                fontWeight: item.isApplied ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
