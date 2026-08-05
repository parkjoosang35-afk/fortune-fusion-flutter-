import 'package:flutter/material.dart';

import '../domain/tarot_category_model.dart';
import 'tarot_home_screen.dart' show enterTarotCategory;
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_category_card.dart';
import 'widgets/tarot_mystic_background.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ②] 서브 카테고리 허브.
///
/// 6개 그룹을 칩으로 전환하며 해당 그룹의 카테고리 전체를 세로 그리드로
/// 보여준다. [initialGroup]이 주어지면(타로 홈 그룹 그리드에서 진입) 해당
/// 칩을 선택한 상태로 시작하고, null이면(직접 진입) 전체 65개를 보여준다.
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

    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        appBar: AppBar(
          title: Text('타로 테마 둘러보기', style: TarotTextStyles.screenTitle),
        ),
        body: Stack(
          children: [
            TarotMysticBackground(
              intensity: TarotPerfConfig.backgroundIntensity(0.6),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: TarotTokens.spaceSm),
                  _GroupChipRow(
                    selected: _selected,
                    onSelected: (g) => setState(() => _selected = g),
                  ),
                  const SizedBox(height: TarotTokens.spaceLg),
                  if (_selected != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TarotTokens.spaceLg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selected!.moodCopy,
                          style: TarotTextStyles.moodCopy,
                        ),
                      ),
                    ),
                  const SizedBox(height: TarotTokens.spaceMd),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        TarotTokens.spaceLg,
                        0,
                        TarotTokens.spaceLg,
                        TarotTokens.spaceXxl,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: TarotTokens.spaceMd,
                            crossAxisSpacing: TarotTokens.spaceMd,
                            childAspectRatio: 0.86,
                          ),
                      itemCount: categories.length,
                      itemBuilder: (context, i) {
                        final c = categories[i];
                        return TarotCategoryCard(
                          category: c,
                          onTap: () => enterTarotCategory(context, c),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: TarotTokens.spaceLg),
        children: [
          _GroupChip(
            label: '전체',
            color: TarotColors.moonSilver,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: TarotTokens.spaceSm),
          ...TarotCategoryGroup.values.map((g) {
            return Padding(
              padding: const EdgeInsets.only(right: TarotTokens.spaceSm),
              child: _GroupChip(
                label: g.label,
                color: g.accentColor,
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

class _GroupChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _GroupChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TarotTokens.spaceLg,
          vertical: TarotTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : TarotColors.surfaceCard,
          borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
          border: Border.all(color: selected ? color : TarotColors.borderSoft),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TarotTextStyles.chipLabel.copyWith(
            color: selected ? color : TarotColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
