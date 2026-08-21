import 'package:flutter/material.dart';

import '../domain/tarot_category_model.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_chip.dart';
import 'oz/widgets/oz_sublist_row.dart';
import 'oz/widgets/oz_theme_hero.dart';
import 'oz/widgets/oz_topbar.dart';
import 'tarot_home_screen.dart' show enterTarotCategory;

/// [타로 섹션 전면 개편 §2 정보구조 ②] 서브 카테고리 허브 — 오즈의 타로
/// 리스킨(화면02 THEME LIST).
///
/// 6개 그룹을 칩으로 전환하며 해당 그룹의 카테고리 전체를 세로 리스트로
/// 보여준다. [initialGroup]이 주어지면(타로 홈 그룹 그리드에서 진입) 해당
/// 칩을 선택한 상태로 시작하고, null이면(직접 진입) 전체 65개를 보여준다.
///
/// ⚠️ 순수 UI 리스킨: [_selected] 상태, [TarotCategoryData.byGroup]/[all],
/// [enterTarotCategory] 로직은 기존과 완전히 동일하다.
class TarotHubScreen extends StatefulWidget {
  final TarotCategoryGroup? initialGroup;
  const TarotHubScreen({super.key, this.initialGroup});

  @override
  State<TarotHubScreen> createState() => _TarotHubScreenState();
}

class _TarotHubScreenState extends State<TarotHubScreen> {
  TarotCategoryGroup? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGroup;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _selected == null
        ? TarotCategoryData.all
        : TarotCategoryData.byGroup(_selected!);

    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(starDensity: 30),
          SafeArea(
            child: Column(
              children: [
                OzTopbar(
                  title: _selected?.label ?? '타로 테마 둘러보기',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OzTokens.spaceLg,
                  ),
                  child: _GroupChipRow(
                    selected: _selected,
                    onSelected: (g) => setState(() => _selected = g),
                  ),
                ),
                const SizedBox(height: OzTokens.spaceSm),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: OzTokens.spaceXxl),
                    children: [
                      if (_selected != null)
                        OzThemeHero(group: _selected!, count: categories.length)
                      else
                        const SizedBox(height: OzTokens.spaceLg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OzTokens.spaceLg,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < categories.length; i++) ...[
                              OzSublistRow(
                                index: i + 1,
                                category: categories[i],
                                onTap: () =>
                                    enterTarotCategory(context, categories[i]),
                              ),
                              if (i != categories.length - 1)
                                const SizedBox(height: OzTokens.spaceSm),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS 대응: .oz-chip-row / .oz-chip / .oz-chip.active.
class _GroupChipRow extends StatelessWidget {
  final TarotCategoryGroup? selected;
  final ValueChanged<TarotCategoryGroup?> onSelected;
  const _GroupChipRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          OzChip(
            label: '전체',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: OzTokens.spaceSm),
          ...TarotCategoryGroup.values.map((g) {
            return Padding(
              padding: const EdgeInsets.only(right: OzTokens.spaceSm),
              child: OzChip(
                label: g.label,
                selected: selected == g,
                onTap: () => onSelected(g),
              ),
            );
          }),
        ],
      ),
    );
  }
}
