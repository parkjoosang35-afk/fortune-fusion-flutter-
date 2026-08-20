/// [정통사주 69종 개인화 해석 엔진 — 7단계] A07 평생 자녀운 분석 결과
/// 모델.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리 고유
/// 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A01/A03/A04/A05/A06과 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class ChildrenAnalysis extends CategoryAnalysis {
  const ChildrenAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.childPattern,
    required this.childBondStrength,
    required this.childPalaceCondition,
    required this.childRiskPattern,
    required this.childRearingApproach,
    required this.childBlessingDaewoonLabel,
  });

  /// 자녀성(남=관성/여=식상) 개수 + 인성(조부모·주변의 육아 지원 상징)
  /// 개수를 조합한 자녀 인연 "구조" 판정(예: '안정형(安定型)',
  /// '풍요형(豊饒型)', '조력형(助力型)', '만연형(晚緣型)', '혼합형').
  /// 레거시 `getLifeChildren()`이 자녀성 개수만으로 4분류하던 방식을
  /// 폐기하고, 인성(육아 지원 상징)까지 함께 조합해 세분화한다(§4
  /// "문장이 아니라 분석을 개인화").
  final String childPattern;

  /// 신강신약 × 자녀성 개수를 조합한 "육아를 감당하는 그릇의 크기" 판정.
  /// A03의 wealthStrength, A04의 careerStrength, A05의 healthVitality,
  /// A06의 spouseBondStrength와 동일한 설계 원칙.
  final String childBondStrength;

  /// [A07 고유 — 다른 카테고리가 쓰지 않는 근거] 자녀궁(시지, 전통적으로
  /// 시주=자녀를 상징하는 자리)이 관여된 합충형파해/원진 관계를 조회해
  /// "자녀궁이 안정적인지 충돌/원진 등으로 흔들리는지"를 판정한다.
  /// profile.relationships는 PHASE2가 이미 계산한 값을 위치(positions)로
  /// 필터링해 재사용할 뿐, 새로 합충형파해를 계산하지 않는다(§0).
  final String childPalaceCondition;

  /// 자녀궁(시지)에 공망·겁살·재살 등이 걸려 있는지 + 자녀성 부재 여부를
  /// 조합한 자녀운 리스크 서술.
  final String childRiskPattern;

  /// 육아·자녀와의 관계에 임하는 태도 제안(고정 문구가 아니라
  /// childBondStrength+childPalaceCondition 조합으로 매번 생성).
  final String childRearingApproach;

  /// 자녀 인연·경사가 가장 활발해지는 대운 라벨(자녀성 오행 또는 용신
  /// 오행이 들어오는 대운 — PHASE4 실계산 대운 목록에서 실제로 찾은 것만,
  /// 없으면 빈 문자열).
  final String childBlessingDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'childPattern': childPattern,
    'childBondStrength': childBondStrength,
    'childPalaceCondition': childPalaceCondition,
    'childRiskPattern': childRiskPattern,
    'childRearingApproach': childRearingApproach,
    'childBlessingDaewoonLabel': childBlessingDaewoonLabel,
  };
}
