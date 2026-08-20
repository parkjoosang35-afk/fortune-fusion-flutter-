/// [정통사주 69종 개인화 해석 엔진 — 8단계] A08 평생 부모·형제운 분석
/// 결과 모델.
///
/// [A06/A07과의 구조적 차이 — 중요] A06(배우자)/A07(자녀)은 "배우자성/
/// 자녀성 개수 + 인성 개수"를 하나의 조합으로 묶어 단일 pattern(예:
/// spousePattern/childPattern) 하나로 판정했다. 하지만 A08은 부모(인성,
/// 生我者)와 형제(비겁, 同五行者)라는 완전히 독립된 두 개의 육친 관계를
/// 다룬다 — 레거시 `getLifeParentsSiblings()`도 parentCount/siblingCount를
/// 처음부터 서로 무관하게 각각 판정했다(§0 계산 원칙 보존). 따라서 이
/// 스키마는 두 축을 하나로 억지로 합치지 않고, parentPattern/
/// parentBondStrength와 siblingPattern/siblingBondStrength를 각각 별도
/// 필드로 둔다.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리
/// 고유 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A01/A03~A07과 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class ParentsSiblingsAnalysis extends CategoryAnalysis {
  const ParentsSiblingsAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.parentPattern,
    required this.parentBondStrength,
    required this.siblingPattern,
    required this.siblingBondStrength,
    required this.familyPalaceCondition,
    required this.familyRiskPattern,
    required this.familyRelationApproach,
    required this.familyBlessingDaewoonLabel,
  });

  /// 인성(정인+편인, 부모성) 개수만으로 판정하는 부모 인연 "구조"(예:
  /// '자립형(自立型)', '인복형(印福型)', '의존주의형(依存注意型)'). 레거시
  /// `getLifeParentsSiblings()`의 parentCount 3단계(0/1~2/3+) 분류를
  /// 그대로 계승하되, A06/A07과 동일하게 'A — B' 라벨 형식으로 확장한다.
  final String parentPattern;

  /// 신강신약 × 인성 개수를 조합한 "부모의 도움을 실제로 어떻게 받아
  /// 들이는가" 판정. A06의 spouseBondStrength, A07의 childBondStrength와
  /// 동일한 설계 원칙이나, 자녀성이 아니라 인성(부모성)을 기준으로 삼는다.
  final String parentBondStrength;

  /// 비겁(비견+겁재, 형제성) 개수만으로 판정하는 형제 인연 "구조"(예:
  /// '독행형(獨行型)', '협력형(協力型)', '경쟁형(競爭型)'). 레거시
  /// siblingCount 3단계(0/1~2/3+) 분류를 계승한다.
  final String siblingPattern;

  /// 신강신약 × 비겁 개수를 조합한 "형제·동료의 힘을 실제로 어떻게
  /// 활용하는가" 판정.
  final String siblingBondStrength;

  /// [A08 고유 — 다른 카테고리가 쓰지 않는 근거] 부모형제궁(월지, 전통적
  ///으로 월주=부모·형제를 함께 보는 자리)이 관여된 합충형파해/원진
  /// 관계를 조회해 "부모·형제와의 관계가 안정적인지 충돌·원진 등으로
  /// 흔들리는지"를 판정한다. A06의 일지(배우자궁), A07의 시지(자녀궁)와
  /// 짝을 이루는 위치 근거. profile.relationships는 PHASE2가 이미 계산한
  /// 값을 위치(positions)로 필터링해 재사용할 뿐, 새로 합충형파해를
  /// 계산하지 않는다(§0).
  final String familyPalaceCondition;

  /// 부모형제궁(월지)에 공망·겁살·재살 등이 걸려 있는지 + 인성/비겁 부재
  /// 여부를 조합한 부모·형제운 리스크 서술.
  final String familyRiskPattern;

  /// 부모·형제와의 관계에 임하는 태도 제안(고정 문구가 아니라
  /// parentBondStrength+siblingBondStrength+familyPalaceCondition 조합으로
  /// 매번 생성).
  final String familyRelationApproach;

  /// 부모·형제 관련 인연·도움이 가장 활발해지는 대운 라벨(인성 또는
  /// 비겁 범주, 또는 용신 오행이 들어오는 대운 — PHASE4 실계산 대운
  /// 목록에서 실제로 찾은 것만, 없으면 빈 문자열).
  final String familyBlessingDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'parentPattern': parentPattern,
    'parentBondStrength': parentBondStrength,
    'siblingPattern': siblingPattern,
    'siblingBondStrength': siblingBondStrength,
    'familyPalaceCondition': familyPalaceCondition,
    'familyRiskPattern': familyRiskPattern,
    'familyRelationApproach': familyRelationApproach,
    'familyBlessingDaewoonLabel': familyBlessingDaewoonLabel,
  };
}
