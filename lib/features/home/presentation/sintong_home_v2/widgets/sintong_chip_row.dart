// ═══════════════════════════════════════════════════════════════
// FILE: sintong_chip_row.dart
// [신통방통 홈 v2] 히어로 위에 겹쳐지는 칩 로우.
//
// [중요 수정] 원래 "1탭=캐러셀만 이동, 2탭(0.7초 이내)=서브 화면 이동"
// 규칙이었으나, 실제 사용자는 더블탭 규칙을 알 수 없어 "눌러도 안
// 넘어간다"고 느끼는 문제가 있었다(사용자 피드백 반영). 이제 칩을
// 누르면 바로 해당 카테고리 실제 화면으로 이동한다(1탭으로 통일).
//
// [히어로 영상 전환 지시서 v1.0 §2 변경범위] "탭/칩" 행: "칩은 유지하되
// 슬라이드 인덱스 연동만 해제(칩 탭 → 각 서비스 화면 이동). 슬라이드
// 인덱스 상태값 삭제". 히어로가 캐러셀에서 30초 영상 1개로 교체되면서
// 더 이상 "이동시킬 슬라이드"가 없으므로, 칩은 이제 활성/비활성 시각
// 상태 없이 순수 라우팅 전용 버튼이 된다. [SintongDotsIndicator]도
// 슬라이드 진행 표시용이었으므로 이 지시서에 따라 완전히 제거한다
// (제거 체크리스트 #2 "인디케이터 DOM/CSS" 대응).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';

class SintongChipRow extends StatelessWidget {
  const SintongChipRow({super.key});

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
          return GestureDetector(
            onTap: () => openSubScreen(context, sHeroOrder[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SHomeV2Colors.chipBg,
                borderRadius: BorderRadius.circular(SHomeV2Radii.pill),
                border: Border.all(
                  color: SHomeV2Colors.chipBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                sHeroOrder[index].chipLabel,
                style: SHomeV2Text.chip(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
