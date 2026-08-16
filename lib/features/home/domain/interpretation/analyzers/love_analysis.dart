/// [정통사주 69종 개인화 해석 엔진 — 6단계] A06 평생 배우자·결혼운 분석 결과
/// 모델.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리 고유
/// 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A01(LifeOverallAnalysis)/A03(WealthAnalysis)/A04(CareerAnalysis)/
/// A05(HealthAnalysis)와 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class LoveAnalysis extends CategoryAnalysis {
  const LoveAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.spousePattern,
    required this.spouseBondStrength,
    required this.spousePalaceCondition,
    required this.romanceRiskPattern,
    required this.recommendedApproach,
    required this.marriagePeakDaewoonLabel,
  });

  /// 배우자성(남=재성/여=관성) 정편 개수 + 비겁 개수를 조합한 인연 "구조"
  /// 판정(예: '정연형(正緣形)', '다연형(多緣形)', '경쟁연형(競爭緣形)',
  /// '만혼·특수연형', '혼합형'). 레거시 `getLifeLove()`가 배우자성 정편
  /// 개수만으로 4분류하던 방식을 폐기하고, 비겁(경쟁자 상징)까지 함께
  /// 조합해 세분화한다(§4 "문장이 아니라 분석을 개인화").
  final String spousePattern;

  /// 신강신약 × 배우자성 개수를 조합한 "결혼생활을 감당하는 그릇의 크기"
  /// 판정. A03의 wealthStrength, A04의 careerStrength, A05의
  /// healthVitality와 동일한 설계 원칙.
  final String spouseBondStrength;

  /// [A06 고유 — 다른 카테고리가 쓰지 않는 근거] 배우자궁(일지)이 관여된
  /// 합충형파해/원진/귀문 관계를 조회해 "배우자궁이 안정적인지 충돌/원진
  /// 등으로 흔들리는지"를 판정한다. profile.relationships는 PHASE2가
  /// 이미 계산한 값을 위치(positions)로 필터링해 재사용할 뿐, 새로
  /// 합충형파해를 계산하지 않는다(§0).
  final String spousePalaceCondition;

  /// 도화(12신살 중 년살)·원진·육해살 존재 + 비겁 개수를 조합한 애정
  /// 리스크 서술.
  final String romanceRiskPattern;

  /// 연애·결혼에 임하는 태도 제안(§ 기존 advice 대체 — 고정 문구가
  /// 아니라 spousePattern+spouseBondStrength 조합으로 매번 생성).
  final String recommendedApproach;

  /// 혼인·인연이 가장 활발해지는 대운 라벨(배우자성 오행 또는 용신 오행이
  /// 들어오는 대운 — PHASE4 실계산 대운 목록에서 실제로 찾은 것만, 없으면
  /// 빈 문자열).
  final String marriagePeakDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'spousePattern': spousePattern,
    'spouseBondStrength': spouseBondStrength,
    'spousePalaceCondition': spousePalaceCondition,
    'romanceRiskPattern': romanceRiskPattern,
    'recommendedApproach': recommendedApproach,
    'marriagePeakDaewoonLabel': marriagePeakDaewoonLabel,
  };
}
