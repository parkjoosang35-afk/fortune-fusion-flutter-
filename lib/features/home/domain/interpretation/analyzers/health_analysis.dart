/// [정통사주 69종 개인화 해석 엔진 — 5단계] A05 평생 건강운 분석 결과
/// 모델.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리 고유
/// 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A01(LifeOverallAnalysis)/A03(WealthAnalysis)/A04(CareerAnalysis)와
/// 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class HealthAnalysis extends CategoryAnalysis {
  const HealthAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.healthConstitutionPattern,
    required this.healthVitality,
    required this.vulnerableOrgans,
    required this.healthRiskPattern,
    required this.recommendedCare,
    required this.healthCautionDaewoonLabel,
  });

  /// 오행 과다(dominant)/부족(deficient) 개수 조합으로 판정한 "체질
  /// 편중 구조"(예: '오행균형형', '단일과다형', '복합편중형' 등). 레거시
  /// `interpretHealth()`가 오행 5개를 개별 순회하며 개수≥3/=0만으로 경고
  /// 문자열을 나열하던 방식을 폐기하고, dominant/deficient 개수 조합
  /// 자체를 하나의 체질 유형으로 종합 판정한다(§4 "문장이 아니라 분석을
  /// 개인화").
  final String healthConstitutionPattern;

  /// 신강신약 × 오행 편중 여부(isImbalanced)를 조합한 "타고난 체력
  /// 그릇의 크기와 회복력" 판정. A03의 wealthStrength, A04의
  /// careerStrength와 동일한 설계 원칙.
  final String healthVitality;

  /// 과다/부족 오행에 대응하는 장기 계통 목록(`five_elements_rules.json`의
  /// organ 필드를 오행별로 조회) — 사람마다 dominant/deficient 오행이
  /// 다르므로 이 목록 자체가 개인화된다.
  final List<String> vulnerableOrgans;

  /// 건강 관련 신살(양인살/백호대살/육해살/겁살 등) 존재 여부 + 기신
  /// 오행 강도를 조합한 리스크 서술.
  final String healthRiskPattern;

  /// 부족한 오행(우선) 또는 일간 오행 기준 전통 고정표
  /// (`five_elements_rules.json`의 food_good)에서 조회한 보양 음식 목록.
  final List<String> recommendedCare;

  /// 건강 주의가 필요한 대운 라벨(기신 오행이 들어오는 대운 —
  /// PHASE4 실계산 대운 목록에서 실제로 찾은 것만, 없으면 빈 문자열).
  final String healthCautionDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'healthConstitutionPattern': healthConstitutionPattern,
    'healthVitality': healthVitality,
    'vulnerableOrgans': vulnerableOrgans,
    'healthRiskPattern': healthRiskPattern,
    'recommendedCare': recommendedCare,
    'healthCautionDaewoonLabel': healthCautionDaewoonLabel,
  };
}
