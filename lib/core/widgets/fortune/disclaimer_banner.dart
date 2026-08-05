import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../../../features/home/domain/fortune_matrix.dart';

/// [운섹션 87 카테고리 통합] 면책 문구 표준안.
///
/// 두 계층으로 구성한다.
/// 1. [DisclaimerBanner.common] — 모든 운세 결과 화면 상단에 공통으로 붙는
///    담백한 한 줄 띠("참고용 콘텐츠" 고지). 카테고리와 무관하게 항상 동일하다.
/// 2. [DisclaimerBanner.forTags] — [FortuneCategoryEntry.disclaimers]에 따라
///    카메라/건강/금전/날짜(법적효력)/관계/영아/복권/해몽 8종 중 필요한 것만
///    추가로 붙는 카테고리별 보강 문구. 태그가 없으면 아무것도 렌더링하지
///    않는다(공통 띠 하나로 충분한 카테고리).
///
/// 기존 [SectionCard]/[ListCard] 등과 시각적으로 다르게(정보성 톤) 구분하기
/// 위해, 배경은 카드 팔레트 중 가장 옅은 [UnifiedColors.cardSection]을 쓰고
/// 아이콘은 경고가 아닌 정보 아이콘(`info_outline`)을 사용한다.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner._({super.key, required this.lines});

  /// 공통 상단 띠 — 모든 결과 화면에서 항상 노출.
  const DisclaimerBanner.common({Key? key})
    : this._(key: key, lines: const [_commonText]);

  /// 카테고리의 [tags]에 대응하는 추가 면책 문구만 모아서 보여준다.
  /// tags가 비어 있으면 이 위젯은 아무것도 그리지 않는다([SizedBox.shrink]).
  factory DisclaimerBanner.forTags(List<DisclaimerTag> tags, {Key? key}) {
    final lines = tags.map((t) => _textByTag[t]!).toList();
    return DisclaimerBanner._(key: key, lines: lines);
  }

  final List<String> lines;

  static const _commonText =
      '이 결과는 재미와 참고를 위한 콘텐츠예요. 실제 중요한 결정은 이 내용만으로 판단하지 말고, '
      '본인의 상황과 전문가의 의견을 함께 고려해주세요.';

  static const Map<DisclaimerTag, String> _textByTag = {
    DisclaimerTag.medical:
        '건강 관련 내용은 의학적 진단·치료를 대체할 수 없어요. 몸에 이상이 느껴지면 반드시 전문의와 상담해주세요.',
    DisclaimerTag.finance:
        '재물·금전 관련 내용은 투자 권유나 재무 자문이 아니에요. 중요한 금융 결정은 전문가와 상담 후 진행해주세요.',
    DisclaimerTag.legalDate:
        '추천 날짜는 전통 명리 해석에 기반한 참고 정보이며 법적 효력이 없어요. 중요한 일정은 관계 기관 확인 후 결정해주세요.',
    DisclaimerTag.relationship:
        '관계·궁합 해석은 재미로 참고할 콘텐츠이며, 실제 관계의 좋고 나쁨을 단정하지 않아요.',
    DisclaimerTag.infant:
        '아기·태명 관련 콘텐츠는 참고용이며, 이름 관련 법적 절차는 관계 기관(가족관계등록 등)에 문의해주세요.',
    DisclaimerTag.camera:
        '관상·손금 해석은 전통 해석을 재미로 풀어낸 콘텐츠이며, 촬영한 이미지는 분석 목적으로만 임시 사용돼요.',
    DisclaimerTag.lottery:
        '행운 번호는 재미로 즐기는 콘텐츠이며 실제 당첨을 보장하지 않아요. 복권 구매는 신중하게 결정해주세요.',
    DisclaimerTag.dream: '꿈해몽은 전통 해석을 참고용으로 풀이한 콘텐츠이며, 실제 미래를 예측하지 않아요.',
  };

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textCaption,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  Text(lines[i], style: UnifiedText.caption()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
