// 신통방통 - 정통사주 v3 장문 리포트 모델 (POST /saju/v3/report 응답)
//
// [5차 지시서 - AI 정통사주 해석 엔진 v1.0] 9 PART 장문 리포트 계약.
// source: "llm"(실 LLM 성공) | "rule_fallback"(LLM 미연결/QA 미통과 시 계산값 나열)
//         | "cache"(동일 요청 재조회, idempotency) | 서버가 429일 때는 HTTP 예외로 처리됨.
// 계산 사실(기둥·오행·신강약·용신 등)은 엔진 원본 그대로이며, 이 모델은 그 구조를
// 그대로 파싱만 한다(값 가공/재계산 없음).

class SajuReportPart {
  final int no;
  final String title;
  final List<String> paras;
  final List<String> evidence;

  const SajuReportPart({
    required this.no,
    required this.title,
    required this.paras,
    required this.evidence,
  });

  factory SajuReportPart.fromJson(dynamic raw) {
    final m = raw is Map ? raw : const {};
    return SajuReportPart(
      no: (m['no'] as num?)?.toInt() ?? 0,
      title: (m['title'] ?? '').toString(),
      paras: ((m['paras'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      evidence: ((m['evidence'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SajuReportBody {
  final List<SajuReportPart> parts;
  final String summary;
  final List<String> evidenceUsed;

  const SajuReportBody({
    required this.parts,
    required this.summary,
    required this.evidenceUsed,
  });

  factory SajuReportBody.fromJson(dynamic raw) {
    final m = raw is Map ? raw : const {};
    return SajuReportBody(
      parts: ((m['parts'] as List?) ?? const [])
          .map(SajuReportPart.fromJson)
          .toList(),
      summary: (m['summary'] ?? '').toString(),
      evidenceUsed: ((m['evidence_used'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SajuReportPersonalization {
  final double sajuReflect;
  final double questionReflect;
  final double evidenceLink;

  const SajuReportPersonalization({
    required this.sajuReflect,
    required this.questionReflect,
    required this.evidenceLink,
  });

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  factory SajuReportPersonalization.fromJson(dynamic raw) {
    final m = raw is Map ? raw : const {};
    return SajuReportPersonalization(
      sajuReflect: _toDouble(m['saju_reflect']),
      questionReflect: _toDouble(m['question_reflect']),
      evidenceLink: _toDouble(m['evidence_link']),
    );
  }
}

class SajuReportResult {
  final String source; // llm | rule_fallback | cache
  final String? fallbackReason;
  final SajuReportBody report;
  final bool? qaPassed;
  final SajuReportPersonalization? personalization;
  final List<String> inputFlags;
  final Map<String, dynamic>? engine;

  const SajuReportResult({
    required this.source,
    this.fallbackReason,
    required this.report,
    this.qaPassed,
    this.personalization,
    required this.inputFlags,
    this.engine,
  });

  bool get isFallback => source == 'rule_fallback';
  bool get isCache => source == 'cache';
  bool get isLlm => source == 'llm';

  factory SajuReportResult.fromJson(Map<String, dynamic> json) {
    return SajuReportResult(
      source: (json['source'] ?? 'rule_fallback').toString(),
      fallbackReason: json['fallback_reason']?.toString(),
      report: SajuReportBody.fromJson(json['report']),
      qaPassed: json['qa_passed'] as bool?,
      personalization: json['personalization'] != null
          ? SajuReportPersonalization.fromJson(json['personalization'])
          : null,
      inputFlags: ((json['input_flags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      engine: json['engine'] is Map
          ? Map<String, dynamic>.from(json['engine'] as Map)
          : null,
    );
  }
}
