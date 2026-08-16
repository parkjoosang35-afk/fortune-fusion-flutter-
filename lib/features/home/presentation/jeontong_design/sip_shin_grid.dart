// ============================================================
// 십신(十神) 그리드 — 정통사주 전용 Dawn Hanji 디자인.
//
// [재계산 금지 원칙] `saju_interpreter.dart`의
// `SajuFullInterpretation.tenGodsAnalysis.details`(List<TenGodDetail>{god,
// easy, count, meaning, positive, negative})를 그대로 받아 렌더링한다.
// 원본 디자인의 자체 `SipShin(name, hanja, code, desc, wuxing)` 모델은
// 도입하지 않는다.
//
// [색상 그룹은 계산이 아니라 순수 UI 분류] 십신 자체는 고정된 오행이
// 아니라 일간 대비 "관계"이므로(비겁=나와 같음, 식상=내가 생함, 재성=내가
// 극함, 관성=나를 극함, 인성=나를 생함), 실제 사주 데이터를 새로 계산하지
// 않고 그룹별로 시각적 구분을 위한 고정 팔레트만 부여한다(전통적으로도
// 비겁/식상/재성/관성/인성 다섯 그룹으로 묶어 설명하는 방식과 동일).
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/saju_interpreter.dart' show TenGodDetail;
import 'hanji_design_tokens.dart';

/// 십신 한자 표기(사전 정의 — 계산 아님, 표시용 상수 테이블).
const Map<String, String> _kSipShinHanja = {
  '비견': '比肩',
  '겁재': '劫財',
  '식신': '食神',
  '상관': '傷官',
  '편재': '偏財',
  '정재': '正財',
  '편관': '偏官',
  '정관': '正官',
  '편인': '偏印',
  '정인': '正印',
};

/// 십신 그룹별 표시 색상(비겁=목/식상=화/재성=토/관성=금/인성=수 팔레트를
/// 그대로 재사용 — 실제 오행 재계산이 아니라 다섯 그룹을 구분하기 위한
/// 고정 매핑).
Color _sipShinGroupColor(String god) {
  const bigyeop = ['비견', '겁재'];
  const siksang = ['식신', '상관'];
  const jaeseong = ['편재', '정재'];
  const gwanseong = ['편관', '정관'];
  const inseong = ['편인', '정인'];
  if (bigyeop.contains(god)) return HanjiColors.mok;
  if (siksang.contains(god)) return HanjiColors.hwa;
  if (jaeseong.contains(god)) return HanjiColors.to;
  if (gwanseong.contains(god)) return HanjiColors.geum;
  if (inseong.contains(god)) return HanjiColors.su;
  return HanjiColors.to;
}

class SipShinGrid extends StatelessWidget {
  final List<TenGodDetail> items;
  const SipShinGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cs) {
        final w = (cs.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((it) {
            final color = _sipShinGroupColor(it.god);
            final hanja = _kSipShinHanja[it.god] ?? '';
            final code = hanja.isNotEmpty
                ? hanja.substring(0, 1)
                : it.god.substring(0, 1);
            return SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: HanjiColors.card,
                  border: Border.all(color: HanjiColors.line),
                  borderRadius: BorderRadius.circular(HanjiRadii.chip),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.13),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style: HanjiTextStyles.display1(
                          color: color,
                        ).copyWith(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${it.god}${it.count > 1 ? ' ×${it.count}' : ''}',
                                style: HanjiTextStyles.bodyTitle().copyWith(
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hanja,
                                style: HanjiTextStyles.body(
                                  color: HanjiColors.muted,
                                ).copyWith(fontSize: 9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            it.easy,
                            style: HanjiTextStyles.bodySmall().copyWith(
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
