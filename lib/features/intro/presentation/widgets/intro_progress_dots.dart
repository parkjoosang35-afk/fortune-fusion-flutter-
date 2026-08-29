import 'package:flutter/material.dart';
import '../intro_palette.dart';

/// [핸드오프 콘텐츠 반영] `.progress .dot` — 4장 캐러셀 전체 기준 진행률 점.
/// 핸드오프는 스플래시(1)+페이저(2·3·4) 총 4페이지 기준으로 점을 그리므로,
/// 이 위젯도 항상 4개 점을 그리고 [activeIndex](0~3)만 넓게·밝게 표시한다.
/// 스플래시는 별도 화면이라 이미 "지나간" 상태로 취급해 인디케이터에는
/// 표시하지 않고, 페이저 3페이지가 activeIndex 1/2/3에 대응한다.
class IntroProgressDots extends StatelessWidget {
  final int activeIndex; // 0~3
  static const int total = 4;

  const IntroProgressDots({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? IntroPalette.primary
                : IntroPalette.indicatorInactive,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: IntroPalette.glowShadow,
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
