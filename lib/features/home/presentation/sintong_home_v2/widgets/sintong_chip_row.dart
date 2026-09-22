// ═══════════════════════════════════════════════════════════════
// FILE: sintong_chip_row.dart
// [신통방통 홈 v2] 히어로 위에 겹쳐지는 칩 로우 — README "칩 탭 규칙":
// 1탭 = 히어로 슬라이드를 해당 카테고리로 이동(자동 순환 리셋)
// 2탭(0.7초 이내) = 해당 카테고리 서브 화면으로 이동
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';
import 'sintong_hero_carousel.dart';

class SintongChipRow extends StatefulWidget {
  const SintongChipRow({
    super.key,
    required this.currentIndex,
    required this.onChipTapGoTo,
  });

  final int currentIndex;

  /// 1탭 시 히어로를 해당 인덱스로 이동시키는 콜백(부모가 소유한
  /// [SintongHeroCarouselState.goTo]에 위임).
  final ValueChanged<int> onChipTapGoTo;

  @override
  State<SintongChipRow> createState() => _SintongChipRowState();
}

class _SintongChipRowState extends State<SintongChipRow> {
  int? _lastTapIndex;
  DateTime? _lastTapAt;

  void _onChipTap(int index) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTapIndex == index &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) < SHomeV2Motion.doubleTapWindow;

    if (isDoubleTap) {
      openSubScreen(context, sHeroOrder[index]);
    } else {
      widget.onChipTapGoTo(index);
    }
    _lastTapIndex = index;
    _lastTapAt = now;
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
          final active = index == widget.currentIndex;
          return GestureDetector(
            onTap: () => _onChipTap(index),
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
                  color: active
                      ? SHomeV2Colors.chipOnFg
                      : Colors.white,
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
