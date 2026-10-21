// [앱·웹 공유 구조 확정] `/r/[id]` 서비스별 전용 렌더러가 공유하는 타입
// 정의. Flutter 각 결과화면(`_shareResult`/`_shareResultLink`/
// `_shareViaLink`)이 `POST /api/public/share`에 보내는 payload와 1:1
// 대응한다 — 이 파일이 "앱이 보내는 것"과 "웹이 그리는 것" 사이의 계약서
// 역할을 한다.
//
// [2027-02 앱·웹 공유 최종 근본 수정 — 복원 메모] 이 파일은 2026-10-19
// 커밋(7d5ed92)에서 "OG-only SSR + 즉시 Flutter 앱 리다이렉트" 전환 때
// 삭제되었으나, `/g/[token]`·`/w/[token]`과 달리 `/r/[id]`·
// `/web-result/[id]`를 "사람이 열면 콘텐츠 없이 즉시 다른 화면으로
// 튕기는" 상태로 만들어 "웹 공유가 앱으로 강제 전환된다"는 문제의
// 근본 원인이 되었다(대표 지시서 — 공유 완전 근본 수정). `/g`/`/w`가
// 이미 증명한 "리다이렉트 없이 웹에서 직접 실제 콘텐츠를 보여준다" 원칙을
// `/r`/`/web-result`에도 동일하게 적용하기 위해 그대로 복원한다(내용
// 변경 없음 — 과거 삭제 당시 "가짜 하단바"가 문제였지 이 콘텐츠 자체는
// 문제가 아니었음. 하단바는 g/[token]의 최신 4탭 버전을 그대로 재사용).
export type SharePayload = Record<string, unknown>;

export function asString(v: unknown): string | undefined {
  return typeof v === "string" && v.length > 0 ? v : undefined;
}

export function asNumber(v: unknown): number | undefined {
  return typeof v === "number" && Number.isFinite(v) ? v : undefined;
}

export function asStringRecord(v: unknown): Record<string, string> | undefined {
  if (!v || typeof v !== "object" || Array.isArray(v)) return undefined;
  const out: Record<string, string> = {};
  for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
    if (typeof val === "string") out[k] = val;
  }
  return Object.keys(out).length > 0 ? out : undefined;
}

export function asStringList(v: unknown): string[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const out = v.filter((x): x is string => typeof x === "string");
  return out.length > 0 ? out : undefined;
}

/** 공통 범용 필드 — 모든 서비스 payload가 하위 호환으로 가진다. */
export function genericSummaryAndHighlights(payload: SharePayload): {
  summary?: string;
  highlights?: string[];
} {
  return {
    summary: asString(payload.summary),
    highlights: asStringList(payload.highlights),
  };
}
