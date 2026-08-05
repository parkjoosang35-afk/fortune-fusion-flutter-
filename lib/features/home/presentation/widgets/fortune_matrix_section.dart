import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../domain/fortune_matrix.dart';

/// [운섹션 87 카테고리 통합] 87개 카테고리 전체를 그룹(13개)별로 펼쳐 보여주는
/// 전체보기 화면 전용 섹션.
///
/// 기존 관리자 8그룹 섹션("전체 카테고리")과 별개로, [FortuneMatrix]를 단일
/// 소스로 삼아 새로 추가된 87개 카테고리(K/V/O/X/G/B/D/R 등 타로를 제외한
/// 전체)를 탐색할 수 있게 한다. 그룹별 카드 안에 하위 카테고리를 칩으로
/// 나열하고, 각 칩에는 게이트 정책을 한눈에 알 수 있는 짧은 배지 라벨을
/// 붙인다(무료/1회무료/첫무료/프리패스).
class FortuneMatrixSection extends StatelessWidget {
  const FortuneMatrixSection({super.key, required this.onTapEntry});

  final void Function(FortuneCategoryEntry entry) onTapEntry;

  static const Map<FortuneGroupCode, IconData> _groupIcon = {
    FortuneGroupCode.t: Icons.wb_sunny_outlined,
    FortuneGroupCode.s: Icons.auto_stories_outlined,
    FortuneGroupCode.n: Icons.badge_outlined,
    FortuneGroupCode.k: Icons.event_available_outlined,
    FortuneGroupCode.v: Icons.timeline_outlined,
    FortuneGroupCode.o: Icons.auto_awesome_outlined,
    FortuneGroupCode.f: Icons.face_outlined,
    FortuneGroupCode.x: Icons.compare_arrows_rounded,
    FortuneGroupCode.g: Icons.show_chart_rounded,
    FortuneGroupCode.b: Icons.route_outlined,
    FortuneGroupCode.d: Icons.nights_stay_outlined,
    FortuneGroupCode.r: Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in FortuneMatrix.groups)
          Padding(
            padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
            child: _GroupCard(
              icon: _groupIcon[group.code] ?? Icons.auto_awesome_outlined,
              title: group.code.label,
              desc: group.code.description,
              items: group.items,
              onTapItem: onTapEntry,
            ),
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.items,
    required this.onTapItem,
  });

  final IconData icon;
  final String title;
  final String desc;
  final List<FortuneCategoryEntry> items;
  final void Function(FortuneCategoryEntry entry) onTapItem;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: UnifiedText.title())),
              Text('${items.length}개', style: UnifiedText.caption()),
            ],
          ),
          const SizedBox(height: 3),
          Text(desc, style: UnifiedText.caption()),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (entry) =>
                      _EntryChip(entry: entry, onTap: () => onTapItem(entry)),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 하위 카테고리 1개 칩 — 라벨 + 게이트 정책 축약 배지.
class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.entry, required this.onTap});

  final FortuneCategoryEntry entry;
  final VoidCallback onTap;

  String get _badgeLabel => switch (entry.gate) {
    GateResult.openFree => '무료',
    GateResult.freeOncePerDay => '1회무료',
    GateResult.lockedFreeFirst => '첫무료',
    GateResult.paidOnlyPassGate => '프리패스',
    GateResult.cooldown => '대기',
    GateResult.granted => '무료',
  };

  bool get _isFree => entry.gate == GateResult.openFree;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: UnifiedColors.bg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.title,
              style: UnifiedText.chipLabel(color: UnifiedColors.textPrimary),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _isFree
                    ? UnifiedColors.chipInactiveBg
                    : UnifiedColors.cardBanner,
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
              child: Text(
                _badgeLabel,
                style: UnifiedText.caption(color: UnifiedColors.textCaption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
