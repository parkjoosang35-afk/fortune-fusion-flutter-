// 귀인지도 V2 관계 엔진 — 사주 입력 정규화 및 오행 분석.
//
// [출처] Python 기준 소스 `guinji_v2_source/guinji_engine/saju.py`를 그대로
// 1:1 포팅한 것이다. 입력은 정통사주 엔진이 출력하는 '사주 4주'
// (천간+지지 2글자 문자열, 한글 1글자씩)를 그대로 받는다.
// 예: {"name":"A","pillars":{"year":"계사","month":"갑신","day":"을해","hour":"병인"}}
//
// [중요] 이 파일의 입력 타입은 기존 `GuinjiSajuInput`(한자 기반,
// guinji-relation-judger.ts)과 다르다 — Python 원본과 동일한 한글
// 간지 문자열 계약을 그대로 유지한다(골든 벡터 대조를 위해 변형 없이
// 포팅). API 계약 통합은 이후 단계에서 별도로 처리한다.

import * as C from "./constants";

export class SajuError extends Error {}

export const PILLAR_KEYS = ["year", "month", "day", "hour"] as const;
export type PillarKey = (typeof PILLAR_KEYS)[number];

/** 파싱된 기둥: [천간, 지지] 또는 null(미상). */
export type ParsedPillar = [string, string] | null;

export interface PersonPillarsInput {
  year?: string | null;
  month?: string | null;
  day?: string | null;
  hour?: string | null;
}

export interface PersonInput {
  name?: string | null;
  pillars?: PersonPillarsInput | null;
}

export interface NormalizedPerson {
  name: string;
  pillars: Record<PillarKey, ParsedPillar>;
}

/** '을해' → ['을','해']. null/undefined이면 null. */
export function parsePillar(p: string | null | undefined): ParsedPillar {
  if (p === null || p === undefined) return null;
  const s = String(p).trim();
  if (s.length !== 2) {
    throw new SajuError(`기둥은 2글자(천간+지지)여야 합니다: ${JSON.stringify(p)}`);
  }
  const stem = s[0];
  const branch = s[1];
  if (!(C.STEMS as readonly string[]).includes(stem) || !(C.BRANCHES as readonly string[]).includes(branch)) {
    throw new SajuError(`천간/지지 값이 올바르지 않습니다: ${JSON.stringify(p)}`);
  }
  return [stem, branch];
}

/** 사람 입력을 정규화. day(일주)는 필수. */
export function normalize(person: PersonInput | null | undefined): NormalizedPerson {
  if (person === null || person === undefined || typeof person !== "object") {
    throw new SajuError("사람 정보는 객체여야 합니다.");
  }
  const name = (person.name ?? "").trim() || "이름없음";
  const p = person.pillars ?? {};
  const pillars = {} as Record<PillarKey, ParsedPillar>;
  for (const k of PILLAR_KEYS) {
    pillars[k] = parsePillar(p[k]);
  }
  if (pillars.day === null) {
    throw new SajuError("일주(day)는 필수입니다.");
  }
  return { name, pillars };
}

/** 사주 4주에서 오행 개수 집계(천간+지지, 최대 8개). */
export function elementCounts(pillars: Record<PillarKey, ParsedPillar>): Record<string, number> {
  const c: Record<string, number> = {};
  for (const e of C.ELEMENTS) c[e] = 0;
  for (const k of PILLAR_KEYS) {
    const pr = pillars[k];
    if (!pr) continue;
    const [s, b] = pr;
    c[C.STEM_ELEMENT[s]] += 1;
    c[C.BRANCH_ELEMENT[b]] += 1;
  }
  return c;
}

/** 일간(천간) — 관계 판단의 기준. */
export function dayMaster(person: NormalizedPerson): string {
  const day = person.pillars.day;
  if (!day) throw new SajuError("일주(day)는 필수입니다.");
  return day[0];
}

/** 일지(지지) — 배우자궁/관계궁. */
export function dayBranch(person: NormalizedPerson): string {
  const day = person.pillars.day;
  if (!day) throw new SajuError("일주(day)는 필수입니다.");
  return day[1];
}

export function allStems(person: NormalizedPerson): string[] {
  return PILLAR_KEYS.filter((k) => person.pillars[k]).map((k) => (person.pillars[k] as [string, string])[0]);
}

export function allBranches(person: NormalizedPerson): string[] {
  return PILLAR_KEYS.filter((k) => person.pillars[k]).map((k) => (person.pillars[k] as [string, string])[1]);
}

/** 가장 적은 오행(들) — 보완이 필요한 기운. */
export function lacking(counts: Record<string, number>): string[] {
  const mn = Math.min(...C.ELEMENTS.map((e) => counts[e]));
  return C.ELEMENTS.filter((e) => counts[e] === mn);
}

/** 가장 많은 오행(들) — 강한 기운. */
export function dominant(counts: Record<string, number>): string[] {
  const mx = Math.max(...C.ELEMENTS.map((e) => counts[e]));
  return C.ELEMENTS.filter((e) => counts[e] === mx);
}

export interface SajuSummary {
  name: string;
  pillars: Record<PillarKey, string | null>;
  dayMaster: string;
  dayMasterElement: string;
  dayBranch: string;
  dayBranchElement: string;
  elementCounts: Record<string, number>;
  lacking: string[];
  dominant: string[];
}

/** 사주 요약(엔진 내부용). */
export function summarize(person: NormalizedPerson): SajuSummary {
  const counts = elementCounts(person.pillars);
  const dm = dayMaster(person);
  const db = dayBranch(person);
  const pillarsStr = {} as Record<PillarKey, string | null>;
  for (const k of PILLAR_KEYS) {
    const v = person.pillars[k];
    pillarsStr[k] = v ? v.join("") : null;
  }
  return {
    name: person.name,
    pillars: pillarsStr,
    dayMaster: dm,
    dayMasterElement: C.STEM_ELEMENT[dm],
    dayBranch: db,
    dayBranchElement: C.BRANCH_ELEMENT[db],
    elementCounts: counts,
    lacking: lacking(counts),
    dominant: dominant(counts),
  };
}
