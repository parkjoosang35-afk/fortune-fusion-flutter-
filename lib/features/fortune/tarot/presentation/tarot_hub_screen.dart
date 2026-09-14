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
/// [specialFilter]는 홈 화면의 "지금 많이 보는"/"새로 생긴" 배너에서
/// 진입할 때만 사용된다('popular' 또는 'new'). [문제5 수정] 배너에 표시된
/// 개수(count)와 실제로 열리는 목록이 일치하도록, 그룹 필터가 아니라
/// [TarotCategoryData.popular]/[TarotCategoryData.newest]로 필터링된
/// 목록을 그대로 보여준다. 사용자가 이후 그룹 칩을 직접 선택하면 일반
/// 그룹 필터링 동작으로 전환된다.
///
/// ⚠️ 순수 UI 리스킨: [_selected] 상태, [TarotCategoryData.byGroup]/[all],
/// [enterTarotCategory] 로직은 기존과 완전히 동일하다.
class TarotHubScreen extends StatefulWidget {
  final TarotCategoryGroup? initialGroup;
  final String? specialFilter; // 'popular' | 'new' | null
  const TarotHubScreen({super.key, this.initialGroup, this.specialFilter});

  @override
  State<TarotHubScreen> createState() => _TarotHubScreenState();
}

class _TarotHubScreenState extends State<TarotHubScreen> {
  TarotCategoryGroup? _selected;
  // 그룹 칩을 사용자가 직접 클릭하면 special 필터는 해제된다.
  late String? _specialFilter = widget.specialFilter;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGroup;
  }

  String get _titleLabel {
    if (_selected != null) return _selected!.label;
    if (_specialFilter == 'popular') return '지금 많이 보는 카테고리';
    if (_specialFilter == 'new') return '새로 생긴 카테고리';
    return '타로 테마 둘러보기';
  }

  @override
  Widget build(BuildContext context) {
    final List<TarotCategoryMeta> categories;
    if (_selected != null) {
      categories = TarotCategoryData.byGroup(_selected!);
    } else if (_specialFilter == 'popular') {
      // 실제 인기순 상위 N개(홈 배너 count와 동일한 로직으로 산출).
      categories = TarotCategoryData.popular(take: 6);
    } else if (_specialFilter == 'new') {
      // isNew == true인 카테고리 전체(현재 12개).
      categories = TarotCategoryData.newest(take: 12);
    } else {
      categories = TarotCategoryData.all;
    }

    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(starDensity: 30),
          SafeArea(
            child: Column(
              children: [
                OzTopbar(
                  title: _titleLabel,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OzTokens.spaceLg,
                  ),
                  child: _GroupChipRow(
                    selected: _selected,
                    // 사용자가 그룹 칩을 직접 선택하면 special 필터(popular/new)는
                    // 해제하고 일반 그룹 필터링으로 전환한다.
                    onSelected: (g) => setState(() {
                      _selected = g;
                      _specialFilter = null;
                    }),
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
                        SizedBox(
                          height: OzTokens.spaceLg,
                          child: _specialFilter == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: OzTokens.spaceLg,
                                  ),
                                  child: Text(
                                    '전체 ${categories.length}개',
                                    style: OzTypography.body(
                                      color: OzColors.fg.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
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
