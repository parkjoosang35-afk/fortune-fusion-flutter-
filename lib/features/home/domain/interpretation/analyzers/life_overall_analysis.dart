/// [정통사주 69종 개인화 해석 엔진 — 2단계] A01 평생총운 분석 결과 모델.
///
/// 사용자 최종 지시 §23 "2단계: A01을 기준 모델로 완성"에 대응한다.
/// [LifeOverallAnalyzer]의 산출물이며, [CategoryAnalysis] 공통 뼈대에
/// A01 고유 필드(중심 기운/인생 테마/타고난 성향/특이 신살 등)를 더한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class LifeOverallAnalysis extends CategoryAnalysis {
  const LifeOverallAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.dominantTenGodCategory,
    required this.lifeTheme,
    required this.coreNatureDescription,
    required this.notableSinsal,
    required this.dominantElements,
    required this.deficientElements,
    required this.strengthVerdict,
    required this.yongsinElement,
    required this.gisinElement,
    required this.strengths,
    required this.weaknesses,
  });

  /// 십신 7개 위치를 5대 범주로 집계했을 때 가장 많이 나타난 범주
  /// (비겁/식상/재성/관살/인성 중 하나, 모두 0이면 '균형').
  final String dominantTenGodCategory;

  /// 일간·중심기운·신강신약·용신을 종합한 한 문장짜리 인생 테마.
  final String lifeTheme;

  /// 일간 오행+음양 기준 타고난 기본 성향 서술(10천간 고정표에서 유래).
  final String coreNatureDescription;

  /// 원국에서 발견된 주요 신살(천을귀인/괴강살/양인살 등) 이름 목록.
  final List<String> notableSinsal;

  /// 오행 과다(3개 이상) 목록.
  final List<String> dominantElements;

  /// 오행 부족(0개) 목록.
  final List<String> deficientElements;

  /// '신강' | '중화' | '신약'.
  final String strengthVerdict;

  /// 용신 오행.
  final String yongsinElement;

  /// 기신 오행.
  final String gisinElement;

  /// 결과 페이지 ③ "나에게 나타나는 특징"의 재료 — 개인 성향 강점.
  final List<String> strengths;

  /// 결과 페이지 ③ "나에게 나타나는 특징"의 재료 — 개인 성향 약점(주의점).
  final List<String> weaknesses;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'dominantTenGodCategory': dominantTenGodCategory,
    'lifeTheme': lifeTheme,
    'coreNatureDescription': coreNatureDescription,
    'notableSinsal': notableSinsal,
    'dominantElements': dominantElements,
    'deficientElements': deficientElements,
    'strengthVerdict': strengthVerdict,
    'yongsinElement': yongsinElement,
    'gisinElement': gisinElement,
    'strengths': strengths,
    'weaknesses': weaknesses,
  };
}
