import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_dust.dart';
import 'wish_room_sigil.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 공통 배경(`BgAtmosphere`).
///
/// `design_files/wish-screens.jsx`의 `BgAtmosphere({sigilSize, sigilOpacity,
/// dust, gradient})`를 그대로 재구현한 공용 배경 위젯. 8개 화면 중 04 Home을
/// 제외한 나머지 화면(01/03/04/05/06/07)이 이 위젯을 그대로 사용한다(04
/// Home은 [wish_room_home_screen.dart]에 이미 이 구조를 인라인으로 pixel
/// -perfect 재현해두었으므로 이 공용 위젯으로 옮기지 않고 그대로 둔다 —
/// 리팩터 범위를 최소화해 회귀 위험을 없앤다).
///
/// 원본 레이어 순서(뒤→앞): radial/linear gradient 배경 → 중앙 고정 마법진
/// (회전 40s, [WishRoomSigilRing]) → (옵션) 10개 Dust 파티클.
class WishRoomBgAtmosphere extends StatelessWidget {
  final double sigilSize;
  final double sigilOpacity;
  final bool dust;

  /// 'radial' | 'linear' — JSX `gradient` prop과 동일한 두 가지 값만 지원.
  final String gradient;

  const WishRoomBgAtmosphere({
    super.key,
    this.sigilSize = 380,
    this.sigilOpacity = 0.35,
    this.dust = true,
    this.gradient = 'radial',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient == 'radial'
                  ? const RadialGradient(
                      center: Alignment(0, -0.6),
                      radius: 1.3,
                      colors: [
                        WishRoomColors.backgroundSoft,
                        WishRoomColors.backgroundDeep,
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        WishRoomColors.backgroundSoft,
                        WishRoomColors.backgroundDeep,
                      ],
                    ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: Center(
              child: Opacity(
                opacity: 0.9,
                child: WishRoomSigilRing(
                  size: sigilSize,
                  opacity: sigilOpacity,
                ),
              ),
            ),
          ),
        ),
        if (dust) const Positioned.fill(child: WishRoomDust(count: 10)),
      ],
    );
  }
}
