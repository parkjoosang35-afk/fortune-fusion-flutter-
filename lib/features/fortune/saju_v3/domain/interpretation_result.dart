import 'dart:convert';

/// /saju/v3/interpret 응답 모델 (v3.1+ AI 해석 레이어)
///
/// source: "llm" — 서버가 LLM 해석(QA 게이트 통과)을 반환
///         "rule_fallback" — LLM 장애·QA 미통과로 기존 룰 해석기 결과를 변환한 값
/// 서버 응답이 { source, fallback_reason, result: {headline, ...} } 중첩형과
/// 평탄형 { headline, ..., source } 모두를 지원한다.
class InterpretationSection {
  final String key;
  final String title;
  final List<String> body;

  const InterpretationSection({
    required this.key,
    required this.title,
    required this.body,
  });

  factory InterpretationSection.fromJson(dynamic raw) {
    final m = raw is Map ? raw : const {};
    return InterpretationSection(
      key: (m['key'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      body: ((m['body'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'title': title, 'body': body};
}

class InterpretationResult {
  final String headline;
  final List<InterpretationSection> sections;
  final List<String> actions;
  final String closing;
  final List<String> evidenceUsed;
  final String source;
  final String? fallbackReason;
  final Map<String, dynamic>? engine;

  const InterpretationResult({
    required this.headline,
    required this.sections,
    required this.actions,
    required this.closing,
    required this.evidenceUsed,
    required this.source,
    this.fallbackReason,
    this.engine,
  });

  bool get isFallback => source == 'rule_fallback';
  bool get hasActions => actions.isNotEmpty;
  bool get hasClosing => closing.isNotEmpty;

  factory InterpretationResult.fromJson(Map<String, dynamic> json) {
    // 중첩형({source, result:{...}}) → 평탄형 통합
    final nested = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : null;
    final body = nested != null ? ({...json}..remove('result')) : json;
    final src = nested != null ? {...body, ...nested} : body;
    return InterpretationResult(
      headline: (src['headline'] ?? '').toString(),
      sections: ((src['sections'] as List?) ?? const [])
          .map(InterpretationSection.fromJson)
          .toList(),
      actions: ((src['actions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      closing: (src['closing'] ?? '').toString(),
      evidenceUsed: ((src['evidence_used'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      source: (src['source'] ?? 'llm').toString(),
      fallbackReason: json['fallback_reason']?.toString(),
      engine: json['engine'] is Map<String, dynamic>
          ? json['engine'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'sections': sections.map((s) => s.toJson()).toList(),
        'actions': actions,
        'closing': closing,
        'evidence_used': evidenceUsed,
        'source': source,
        if (fallbackReason != null) 'fallback_reason': fallbackReason,
        if (engine != null) 'engine': engine,
      };

  @override
  String toString() => jsonEncode(toJson());
}
