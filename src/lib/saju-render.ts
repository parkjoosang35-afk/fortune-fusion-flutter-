// [정통사주 AI 프롬프트 개선] LLM이 반환한 7블록 JSON(SajuLlmResult)을
// 파싱하고, 화면(Flutter)에 표시할 문자열로 렌더링하는 헬퍼.
//
// [호환성 결정] Flutter 클라이언트(SajuRepository.requestSaju →
// topicResults: Map<String,String>)는 이번 개선 범위에서 변경하지 않는다
// (Track1 결과화면 리디자인과 별개 작업이라 화면단 변경은 최소화한다).
// 대신 서버가 LLM의 구조화 JSON을 받아 QA 검증까지 마친 뒤, 사람이 읽기
// 좋은 하나의 텍스트로 렌더링해서 기존 topicResults[topic] 자리에 넣는다.
// 구조화 원본은 resultMeta.topicStructured에 함께 저장해 두어(route.ts),
// 추후 Flutter가 블록 단위 렌더링으로 전환할 때 재작업 없이 바로 쓸 수 있다.

import type { SajuLlmResult } from "./saju-qa-check";

/** LLM 응답 문자열에서 첫 번째 `{...}` JSON 블록만 추출해 파싱한다.
 *  (마크다운 코드펜스 등 잡음이 섞여 있어도 견고하게 파싱하기 위함) */
export function parseSajuLlmJson(raw: string): SajuLlmResult | null {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  const candidate = raw.slice(start, end + 1);
  try {
    const parsed = JSON.parse(candidate);
    if (
      typeof parsed.headline === "string" &&
      Array.isArray(parsed.sections) &&
      Array.isArray(parsed.actions) &&
      typeof parsed.closing === "string"
    ) {
      return {
        headline: parsed.headline,
        sections: parsed.sections.map((s: { key?: string; title?: string; body?: string[] }) => ({
          key: String(s.key ?? ""),
          title: String(s.title ?? ""),
          body: Array.isArray(s.body) ? s.body.map(String) : [],
        })),
        actions: parsed.actions.map(String),
        closing: parsed.closing,
        evidence_used: Array.isArray(parsed.evidence_used)
          ? parsed.evidence_used.map(String)
          : [],
      };
    }
    return null;
  } catch {
    return null;
  }
}

/** 7블록 JSON을 기존 "긴 텍스트 요약" 형식으로 렌더링한다(Flutter 하위호환). */
export function renderSajuLlmResult(result: SajuLlmResult): string {
  const lines: string[] = [];
  lines.push(result.headline.trim());
  lines.push("");
  for (const s of result.sections) {
    lines.push(`【${s.title}】`);
    lines.push(s.body.join(" "));
    lines.push("");
  }
  lines.push("✨ 오늘의 실천");
  for (const a of result.actions) {
    lines.push(`· ${a}`);
  }
  lines.push("");
  lines.push(result.closing.trim());
  return lines.join("\n").trim();
}
