/// [정통사주 69종 개인화 해석 엔진 — 10단계] A10 인생 5대 전환점 분석
/// 결과 모델.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리 고유
/// 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A06~A09와 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class LifeTransitionsAnalysis extends CategoryAnalysis {
  const LifeTransitionsAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.transitionPattern,
    required this.transitionBondStrength,
    required this.turningPointsCondition,
    required this.transitionRiskPattern,
    required this.transitionApproach,
    required this.keyTurningPointLabel,
  });

  /// 대운(최대 5개) 전환점 각각을 "십신 범주가 완전히 바뀌는지(대전환)/
  /// 일부만 바뀌는지(소전환)/유지되는지(순환형)"로 분류한 뒤, 대전환
  /// 개수를 기준으로 정리한 전체 전환 성격 판정(예: '급변형(急變型)',
  /// '변곡형(變曲型)', '완만형(緩慢型)', '순류형(順流型)'). 레거시
  /// `getLifeTransitionPoints()`가 대운 시작연령/연도만 단순 나열하던
  /// 방식을 폐기하고, 각 전환점의 질적 성격을 새로 판정한다.
  final String transitionPattern;

  /// 신강신약을 기준으로 전환기를 대하는 방식을 조합한 판정(예:
  /// '신강주도(身强主導)', '신강안정(身强安定)', '신약격동(身弱激動)',
  /// '신약적응(身弱適應)', '중화순응(中和順應)'). A06~A09의
  /// spouseBondStrength/childBondStrength/parentBondStrength/
  /// studyBondStrength와 동일한 설계 원칙.
  final String transitionBondStrength;

  /// [A10 고유 근거] 대운 목록에서 실제로 계산된 각 전환점(연령/연도/
  /// 간지)이 이전 대운 대비 십신 범주가 얼마나 바뀌었는지(대전환/소전환/
  /// 순환형)와 그 전환이 용신/기신 중 어디에 해당하는지(호전/주의/중립)를
  /// 매핑해 서술한다. A06의 일지(배우자궁)/A07의 시지(자녀궁)/A08의
  /// 월지(부모형제궁)/A09의 문창귀인 위치처럼 다른 카테고리는 조회하지
  /// 않는, A10만의 고유 근거.
  final String turningPointsCondition;

  /// 기신과 맞닿은 전환점(주의 판정) 개수 및 그 시점을 조합한 리스크
  /// 판정.
  final String transitionRiskPattern;

  /// 전환기를 대하는 접근법 서술.
  final String transitionApproach;

  /// 가장 주목해야 할 전환점 대운 라벨(호전+대전환이 겹치는 첫 전환점,
  /// 없으면 호전인 첫 전환점 — PHASE4 실계산 대운 목록에서 실제로 찾은
  /// 것만, 없으면 빈 문자열).
  final String keyTurningPointLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'transitionPattern': transitionPattern,
    'transitionBondStrength': transitionBondStrength,
    'turningPointsCondition': turningPointsCondition,
    'transitionRiskPattern': transitionRiskPattern,
    'transitionApproach': transitionApproach,
    'keyTurningPointLabel': keyTurningPointLabel,
  };
}
