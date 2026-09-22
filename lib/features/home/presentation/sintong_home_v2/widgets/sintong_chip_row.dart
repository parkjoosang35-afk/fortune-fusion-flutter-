// ═══════════════════════════════════════════════════════════════
// FILE: sintong_chip_row.dart
// [신통방통 홈 v2] 히어로 위에 겹쳐지는 칩 로우.
//
// [중요 수정] 원래 "1탭=캐러셀만 이동, 2탭(0.7초 이내)=서브 화면 이동"
// 규칙이었으나, 실제 사용자는 더블탭 규칙을 알 수 없어 "눌러도 안
// 넘어간다"고 느끼는 문제가 있었다(사용자 피드백 반영). 이제 칩을
// 누르면 바로 해당 카테고리 실제 화면으로 이동하고, 캐러셀도 함께
// 해당 슬라이드로 이동시킨다(1탭으로 통일).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';
import 'sintong_hero_carousel.dart';

class SintongChipRow extends StatelessWidget {
  const SintongChipRow({
    super.key,
    required this.currentIndex,
    required this.onChipTapGoTo,
  });

  final int currentIndex;

  /// 칩 탭 시 히어로를 해당 인덱스로 이동시키는 콜백(부모가 소유한
  /// [SintongHeroCarouselState.goTo]에 위임).
  final ValueChanged<int> onChipTapGoTo;

  void _onChipTap(BuildContext context, int index) {
    // 캐러셀도 함께 해당 슬라이드로 이동시켜 시각적 피드백을 준 뒤,
    // 곧바로 실제 기능 화면으로 이동한다.
    onChipTapGoTo(index);
    openSubScreen(context, sHeroOrder[index]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: sHeroOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final active = index == currentIndex;
          return GestureDetector(
            onTap: () => _onChipTap(context, index),
            child: AnimatedContainer(
              duration: SHomeV2Motion.chipTransition,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? SHomeV2Colors.chipOnBg : SHomeV2Colors.chipBg,
                borderRadius: BorderRadius.circular(SHomeV2Radii.pill),
                border: Border.all(
                  color: active
                      ? SHomeV2Colors.chipOnBg
                      : SHomeV2Colors.chipBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                sHeroOrder[index].chipLabel,
                style: SHomeV2Text.chip(
                  color: active ? SHomeV2Colors.chipOnFg : Colors.white,
                  active: active,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SintongDotsIndicator extends StatelessWidget {
  const SintongDotsIndicator({super.key, required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < sHeroOrder.length; i++) ...[
          AnimatedContainer(
            duration: SHomeV2Motion.dotTransition,
            width: i == currentIndex ? 18 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? SHomeV2Colors.dotOn
                  : SHomeV2Colors.dotOff,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (i != sHeroOrder.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
