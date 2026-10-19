// [앱·웹 공유 구조 확정] `/r/[id]` 서비스별 전용 렌더러가 공유하는 타입
// 정의. Flutter 각 결과화면(`_shareResult`/`_shareResultLink`/
// `_shareViaLink`)이 `POST /api/public/share`에 보내는 payload와 1:1
// 대응한다 — 이 파일이 "앱이 보내는 것"과 "웹이 그리는 것" 사이의 계약서
// 역할을 한다.
//
// [하위 호환 원칙] payload는 서버가 그대로 통과시키는 자유 JSON이므로,
// 아래 타입에 맞지 않는 값(필드 누락/구버전 레거시 데이터/QA 테스트
// 데이터)이 섞여 들어올 수 있다. 모든 필드를 optional로 두고, 렌더러
// 쪽에서 없는 값은 건너뛰거나 `highlights`/`summary` 범용 폴백으로
// 대체한다(화면이 깨지거나 비어 보이지 않도록 방어).
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
