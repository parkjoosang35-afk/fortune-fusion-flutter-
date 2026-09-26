// 신통방통 - 정통사주 69종 "서사형 해석" 응답 모델 (POST /saju/v3/narrative)
//
// [69종 AI 해석 전면 재설계] 기존 4블록 카드형(interpretation_result.dart)/
// 9-PART 장문 리포트(saju_report.dart)와는 별개의 새 계약이다. 서버가
// 카테고리 1개당 "하나의 줄글 이야기"(text)만 돌려준다 — 섹션/카드 구조
// 없음. 계산 사실은 엔진 원본 그대로이며, 이 모델은 그 구조를 그대로
// 파싱만 한다(값 가공/재계산 없음).
//
// source: "llm"(실 LLM 성공, QA 게이트 통과) | "rule_fallback"(LLM 미연결/
//         QA 미통과 시 계산값 나열로 대체) — 서버가 402/429일 때는
//         SajuV3ApiException으로 이미 처리되므로 이 모델까지 오지 않는다.
class NarrativeResult {
  final String sourceType; // "llm" | "rule_fallback"
  final String categoryCode;
  final String categoryName;
  final String text;
  final List<String> evidenceUsed;
  final bool qaPassed;
  final List<String> qaWarnings;
  final String? fallbackReason;
  final Map<String, dynamic>? engine;

  const NarrativeResult({
    required this.sourceType,
    required this.categoryCode,
    required this.categoryName,
    required this.text,
    required this.evidenceUsed,
    required this.qaPassed,
    this.qaWarnings = const [],
    this.fallbackReason,
    this.engine,
  });

  bool get isFallback => sourceType == 'rule_fallback';

  factory NarrativeResult.fromJson(Map<String, dynamic> json) {
    return NarrativeResult(
      sourceType: (json['source'] ?? 'llm').toString(),
      categoryCode: (json['category_code'] ?? '').toString(),
      categoryName: (json['category_name'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      evidenceUsed: ((json['evidence_used'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      qaPassed: json['qa_passed'] == true,
      qaWarnings: ((json['qa_warnings'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      fallbackReason: json['fallback_reason']?.toString(),
      engine: json['engine'] is Map<String, dynamic>
          ? json['engine'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': sourceType,
        'category_code': categoryCode,
        'category_name': categoryName,
        'text': text,
        'evidence_used': evidenceUsed,
        'qa_passed': qaPassed,
        if (qaWarnings.isNotEmpty) 'qa_warnings': qaWarnings,
        if (fallbackReason != null) 'fallback_reason': fallbackReason,
        if (engine != null) 'engine': engine,
      };
}
