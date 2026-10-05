/// [신통방통 정통사주 리뉴얼 — STEP 6.5] admin_web
/// `interpret-qa-check.ts`의 `InterpretSummaryResult`/`InterpretDetailResult`/
/// `InterpretEvidence`/`InterpretDetailBlock`에 1:1 대응하는 Flutter
/// 도메인 모델.
///
/// [내부 정보 비노출 원칙] 이 모델들은 서버가 이미 QA를 통과시켜 내려준
/// 필드만 담는다 — score/evaluator/69종 코드/"AI" 표현 등은 서버
/// `interpret-qa-check.ts`가 애초에 걸러내므로 이 모델에 그런 필드 자체가
/// 없다. source("llm"|"template")는 내부 로그/디버깅 용도로만 보관하고
/// 화면에는 절대 노출하지 않는다.
library;

/// admin_web `InterpretEvidence`.
class InterpretEvidence {
  final String type; // "grid" | "elements" | "luck"
  final List<int>? cols;
  final String? hl;
  final String text;

  const InterpretEvidence({
    required this.type,
    this.cols,
    this.hl,
    required this.text,
  });

  factory InterpretEvidence.fromJson(Map<String, dynamic> json) {
    final rawCols = json['cols'];
    return InterpretEvidence(
      type: json['type'] as String? ?? '',
      cols: rawCols is List
          ? rawCols.map((e) => (e as num).toInt()).toList()
          : null,
      hl: json['hl']?.toString(),
      text: json['text'] as String? ?? '',
    );
  }
}

/// mode="summary" 응답(화면⑤ 이야기 미리보기에서 사용).
class InterpretSummaryResult {
  final String topicId;
  final String title;
  final String summary;
  final InterpretEvidence evidence;

  /// "llm" | "template" — 내부 디버깅용, 화면에 노출 금지.
  final String source;

  const InterpretSummaryResult({
    required this.topicId,
    required this.title,
    required this.summary,
    required this.evidence,
    required this.source,
  });

  factory InterpretSummaryResult.fromJson(Map<String, dynamic> json) {
    return InterpretSummaryResult(
      topicId: json['topic_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      evidence: InterpretEvidence.fromJson(
        json['evidence'] as Map<String, dynamic>? ?? const {},
      ),
      source: json['source'] as String? ?? 'template',
    );
  }
}

/// admin_web `InterpretDetailBlock`.
class InterpretDetailBlock {
  final int n; // 1..5
  final String body;
  final InterpretEvidence? evidence;
  final double? luckIndex;

  const InterpretDetailBlock({
    required this.n,
    required this.body,
    this.evidence,
    this.luckIndex,
  });

  factory InterpretDetailBlock.fromJson(Map<String, dynamic> json) {
    final timing = json['timing'] as Map<String, dynamic>?;
    return InterpretDetailBlock(
      n: (json['n'] as num?)?.toInt() ?? 0,
      body: json['body'] as String? ?? '',
      evidence: json['evidence'] != null
          ? InterpretEvidence.fromJson(json['evidence'] as Map<String, dynamic>)
          : null,
      luckIndex: timing != null
          ? (timing['luck_index'] as num?)?.toDouble()
          : null,
    );
  }
}

/// mode="detail" 응답(화면⑦ 상세 사주 이야기에서 사용).
class InterpretDetailResult {
  final String topicId;
  final String title;
  final List<InterpretDetailBlock> blocks;

  /// "llm" | "template" — 내부 디버깅용, 화면에 노출 금지.
  final String source;

  const InterpretDetailResult({
    required this.topicId,
    required this.title,
    required this.blocks,
    required this.source,
  });

  factory InterpretDetailResult.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    return InterpretDetailResult(
      topicId: json['topic_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      blocks: rawBlocks is List
          ? rawBlocks
                .map(
                  (e) =>
                      InterpretDetailBlock.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : const [],
      source: json['source'] as String? ?? 'template',
    );
  }
}

/// POST /api/public/saju-renewal/interpret 응답 전체(mode에 따라
/// summary/detail 중 하나만 채워진다. cached는 서버 캐시 적중 여부 —
/// 화면 동작에는 영향 없으나 중복클릭 디버깅에 참고).
class InterpretResponse {
  final InterpretSummaryResult? summary;
  final InterpretDetailResult? detail;
  final bool cached;

  const InterpretResponse({this.summary, this.detail, required this.cached});

  factory InterpretResponse.summaryOf(
    Map<String, dynamic> json, {
    required bool cached,
  }) {
    return InterpretResponse(
      summary: InterpretSummaryResult.fromJson(json),
      cached: cached,
    );
  }

  factory InterpretResponse.detailOf(
    Map<String, dynamic> json, {
    required bool cached,
  }) {
    return InterpretResponse(
      detail: InterpretDetailResult.fromJson(json),
      cached: cached,
    );
  }
}
