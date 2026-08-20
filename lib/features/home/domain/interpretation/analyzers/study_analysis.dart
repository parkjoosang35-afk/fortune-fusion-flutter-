/// [정통사주 69종 개인화 해석 엔진 — 9단계] A09 평생 학업·시험운 분석
/// 결과 모델.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리 고유
/// 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A06(LoveAnalysis)/A07(ChildrenAnalysis)/A08(ParentsSiblingsAnalysis)와
/// 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class StudyAnalysis extends CategoryAnalysis {
  const StudyAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.studyPattern,
    required this.studyBondStrength,
    required this.munchangPositionCondition,
    required this.studyRiskPattern,
    required this.studyApproach,
    required this.studyPeakDaewoonLabel,
  });

  /// 인성(정인+편인) 개수 + 문창귀인 보유 여부를 조합한 5단계 학업 구조
  /// 판정(예: '학업최상형(學業最上型)', '시험운발동형(試驗運發動型)',
  /// '학구형(學究型)', '안정형(安定型)', '실전형(實戰型)'). 레거시
  /// `getLifeStudy()`의 5분류 조합 원칙을 그대로 계승하되(§0 계산 원칙
  /// 보존), 'A — B' 라벨 형식으로 확장한다(§4).
  final String studyPattern;

  /// 신강신약 × 인성 개수를 조합한 "학업 몰입을 감당하는 방식" 판정(예:
  /// '신강왕인(身强旺印)', '신강자학(身强自學)', '신약의학(身弱依學)',
  /// '신약분산(身弱分散)', '중화학구(中和學究)'). A06~A08의
  /// spouseBondStrength/childBondStrength/parentBondStrength와 동일한
  /// 설계 원칙.
  final String studyBondStrength;

  /// [A09 고유 근거] 문창귀인이 원국의 어느 자리(년지/월지/일지/시지)에
  /// 걸렸는지, 그 자리가 상징하는 인생 시기와 연결해 학업·시험운이
  /// 발동하는 시기적 특징을 서술한다. A06의 일지(배우자궁)/A07의
  /// 시지(자녀궁)/A08의 월지(부모형제궁)처럼 다른 카테고리는 조회하지
  /// 않는, A09만의 고유 근거 — 다만 A09는 고정된 "궁"이 아니라 문창귀인
  /// 이라는 신살 자체가 이미 학업·시험 전용 신호이므로, 그 신살이 실제로
  /// 걸린 위치를 개인화 근거로 채택한다.
  final String munchangPositionCondition;

  /// 문창귀인이 걸린 자리에 공망/겁살/재살이 겹치는지, 그리고 인성·
  /// 문창귀인이 모두 없는 경우를 조합한 리스크 판정.
  final String studyRiskPattern;

  /// 학업 접근법(공부 방식·시험 대비 방식) 서술.
  final String studyApproach;

  /// 학업·시험운이 가장 두드러지는 대운 라벨(인성 범주 또는 용신 오행이
  /// 들어오는 대운 — PHASE4 실계산 대운 목록에서 실제로 찾은 것만, 없으면
  /// 빈 문자열).
  final String studyPeakDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'studyPattern': studyPattern,
    'studyBondStrength': studyBondStrength,
    'munchangPositionCondition': munchangPositionCondition,
    'studyRiskPattern': studyRiskPattern,
    'studyApproach': studyApproach,
    'studyPeakDaewoonLabel': studyPeakDaewoonLabel,
  };
}
