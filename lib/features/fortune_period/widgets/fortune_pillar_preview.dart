/// [기간별 운세 — 사주정보 입력 화면용 원국 미리보기]
///
/// `saju-input.jsx`의 `.pillar-preview`(時/日/月/年 4칸, 값이 있으면 실선
/// 테두리+강조)를 백자 팔레트로 재현한다. 값 계산은 기존 검증된
/// `saju_renewal/data/saju_visual_adapter.dart`(ManseryeokCoreEngine 기반,
/// Phase1~4 명리 엔진)를 그대로 재사용한다 — 계산 로직 재구현 금지
/// 원칙을 지키면서, UI만 이 기능의 백자 테마로 새로 그린다.
library;

import 'package:flutter/material.dart';
import '../theme/fortune_period_theme.dart';

class FortunePillarColumn {
  const FortunePillarColumn({required this.label, this.value});
  final String label; // 時/日/月/年
  final String? value; // 예: '甲子' (null = 아직 입력 전/계산 불가)
}

class FortunePillarPreview extends StatelessWidget {
  const FortunePillarPreview({super.key, required this.columns});

  /// 길이 4, 디자인과 동일한 순서: [時, 日, 月, 年].
  final List<FortunePillarColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: columns.map((c) {
        final has = c.value != null && c.value!.isNotEmpty;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: c == columns.last ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: has
                    ? FortunePeriodColors.glow.withValues(alpha: 0.35)
                    : FortunePeriodColors.line,
                style: has ? BorderStyle.solid : BorderStyle.solid,
                width: has ? 1.2 : 1,
              ),
              color: has
                  ? FortunePeriodColors.glow.withValues(alpha: 0.07)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.label,
                  style: const TextStyle(
                    fontFamily: FortunePeriodType.body,
                    fontSize: 11,
                    color: FortunePeriodColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(
                      c.value ?? '',
                      style: const TextStyle(
                        fontFamily: FortunePeriodType.serif,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.8,
                        color: FortunePeriodColors.glow,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
