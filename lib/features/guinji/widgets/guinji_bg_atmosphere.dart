import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';

/// 귀인지도(Guinji Map) 화면 공통 배경.
///
/// [Phase G-1 범위] `GUINJI_SCREENS.md` "02 · 온보딩" 스펙은 소원방과 동일한
/// `BgAtmosphere(sigilOpacity=0.28)`(회전 마법진 + 먼지 파티클)를 요구하지만,
/// 이 첫 Phase는 라우트 스캐폴딩 + 온보딩 화면 뼈대 확인이 목적이므로 무거운
/// CustomPainter 애니메이션(마법진 회전 40s 등)은 후속 Phase로 미루고, 우선
/// Moonlit Crystal 그라디언트 배경만 정확히 재현한다(색상·비율은
/// `colors_and_type.css` `[data-palette="crystal"]` 그대로).
///
/// 이후 화면(S4 빈지도/S5 지도메인 등)에서 마법진·별빛 애니메이션이 필요해지면
/// 이 위젯에 옵션을 추가해 확장한다(신규 컴포넌트 삭제 후 재작성 방지).
class GuinjiBgAtmosphere extends StatelessWidget {
  const GuinjiBgAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.3,
          colors: [
            GuinjiColors.backgroundSoft,
            GuinjiColors.backgroundDeep,
            GuinjiColors.backgroundDarker,
          ],
          stops: [0.0, 0.65, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
