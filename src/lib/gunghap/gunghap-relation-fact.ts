// 궁합지도(Gunghap Map) — 십성(十星) FACT 비교 엔진.
//
// [신통방통 궁합지도 개발 지시서 — 이번 단계 승인 범위]
// §개발 원칙 1: "귀인지도 guinji-v2/relation.ts의 검증된 S1~S7 관계
// 규칙을 재사용한다." 이 파일은 그 원칙을 그대로 따른다 — S1~S6(일간
// 오행관계/일지관계/오행보완/십성/합충계수/점수)를 재구현하지 않고
// `guinji-v2/relation.ts`의 `computeRelation()`을 그대로 호출해 재사용
// 한다. 이 파일이 신규로 추가하는 것은, 8개 분야(연애/결혼/속궁합/성격/
// 재물/사업/친구/가족) 등급 판정에 필요한 "일간 대 일간" 수준을 넘어선
// 확장 FACT뿐이다:
//   - 십성 매트릭스: 두 사람의 4주 천간 전체가 상대방 일간 기준으로
//     어떤 십성인지(연애/재물/사업 등 분야별 십성 비중 판정에 필요).
//   - 지지 관계 매트릭스: 두 사람의 4주 지지 전체 조합(16쌍)의
//     합·충·형·파·해 관계(가족/결혼 등 분야별 안정성 판정에 필요).
//   - 일간 음양조화: 전통 명리학의 "음양배합" 원칙(속궁합/성격 분야에
//     사용).
//
// §개발 원칙 2: "십성 FACT는 실제 사주 원국 계산 결과를 근거로 산출
// 한다." 이 파일의 모든 필드는 입력된 두 사람의 실제 4주(년/월/일/시
// 천간·지지)로부터만 계산되며, 외부 통계나 임의 수치를 전혀 참조하지
// 않는다. 동일 입력 → 항상 동일 출력(결정론적).
//
// [이번 단계 금지 사항 — 명시] 이 파일은 FACT 계산만 담당한다. 등급
// 판정(점수화)은 `gunghap-category-rules.ts`가, 해석 문장 생성은
// `gunghap-narrative.ts`가 담당한다. API 라우트/DB 저장/Flutter 연동은
// 이번 단계 범위가 아니다(승인 문서 "4. 이번 단계에서 금지" 참고).

import * as C from "../guinji-v2/constants";
import * as S from "../guinji-v2/saju";
import type { PersonInput, NormalizedPerson, SajuSummary, PillarKey } from "../guinji-v2/saju";
import type { BranchRelationKind } from "../guinji-v2/constants";
import {
  computeRelation,
  type GuinjiV2RelationResult,
} from "../guinji-v2/relation";

export const GUNGHAP_FACT_ENGINE_VERSION = "gunghap-fact-1.0.0";
export const GUNGHAP_FACT_RULE_VERSION = "gunghap-fact-rules-1.0.0";

// ---------------- 확장 FACT 1: 십성 매트릭스 ----------------

export interface TenGodMatrixEntry {
  /** 이 천간이 속한 기둥(년/월/일/시). */
  pillar: PillarKey;
  /** 기둥의 천간(한글 1글자, 예: '갑'). */
  stem: string;
  /** 상대방 일간 기준 십성(예: '정재'). */
  tenGod: string;
  /** 십성이 속한 그룹(비겁/식상/재성/관성/인성). */
  group: string;
}

export interface TenGodMatrix {
  /** A(owner)의 4주 천간이 B(member) 일간 기준으로 어떤 십성인지. */
  aPillarsToB: TenGodMatrixEntry[];
  /** B(member)의 4주 천간이 A(owner) 일간 기준으로 어떤 십성인지. */
  bPillarsToA: TenGodMatrixEntry[];
}

/**
 * person의 4주 천간을 otherDayMaster 기준 십성으로 변환한다.
 * [결정론] 입력이 같으면 항상 같은 배열을 반환(순서도 PILLAR_KEYS 고정순).
 */
function buildTenGodMatrixEntries(
  person: NormalizedPerson,
  otherDayMaster: string,
): TenGodMatrixEntry[] {
  const entries: TenGodMatrixEntry[] = [];
  for (const key of S.PILLAR_KEYS) {
    const pillar = person.pillars[key];
    if (!pillar) continue; // 시주 미상 등 — 존재하는 기둥만 계산(임의 추정 금지).
    const stem = pillar[0];
    const tenGod = C.tenGod(otherDayMaster, stem);
    entries.push({ pillar: key, stem, tenGod, group: C.TEN_GOD_GROUP[tenGod] });
  }
  return entries;
}

export function computeTenGodMatrix(a: NormalizedPerson, b: NormalizedPerson): TenGodMatrix {
  const dayA = S.dayMaster(a);
  const dayB = S.dayMaster(b);
  return {
    aPillarsToB: buildTenGodMatrixEntries(a, dayB),
    bPillarsToA: buildTenGodMatrixEntries(b, dayA),
  };
}

/**
 * 십성 그룹(비겁/식상/재성/관성/인성)별 발생 횟수 — 양방향 합산.
 * [대칭성 — 중요] A↔B를 바꿔 입력해도 합산값은 동일하다(순서 무관).
 * 분야별 판정(`gunghap-category-rules.ts`)이 "누가 owner인지"에 따라
 * 결과가 달라지지 않도록 하기 위한 설계 — 두 사람 순서를 바꿔도 동일
 * 결과가 나와야 한다는 검수 지시 §3 테스트 항목을 구조적으로 충족한다.
 */
export function tenGodGroupCounts(matrix: TenGodMatrix): Record<string, number> {
  const counts: Record<string, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  for (const e of [...matrix.aPillarsToB, ...matrix.bPillarsToA]) {
    counts[e.group] = (counts[e.group] ?? 0) + 1;
  }
  return counts;
}

// ---------------- 확장 FACT 2: 지지 관계 매트릭스(16쌍) ----------------

export interface BranchPairEntry {
  posA: PillarKey;
  posB: PillarKey;
  branchA: string;
  branchB: string;
  kind: BranchRelationKind;
  desc: string;
}

/**
 * 두 사람의 4주 지지 전체 조합(최대 4×4=16쌍)의 관계를 계산한다.
 * [출처] 판정 로직 자체는 `guinji-v2/constants.ts`의 `branchRelation()`
 * (육합/삼합/충/형/파/해 고정표, 기존 검증된 함수)을 그대로 재사용한다
 * — 이 파일은 "어느 기둥과 어느 기둥을 비교할지"만 확장할 뿐, 합충형파해
 * 판정 규칙 자체는 추가·변경하지 않는다.
 */
export function computeBranchPairMatrix(
  a: NormalizedPerson,
  b: NormalizedPerson,
): BranchPairEntry[] {
  const entries: BranchPairEntry[] = [];
  for (const posA of S.PILLAR_KEYS) {
    const pa = a.pillars[posA];
    if (!pa) continue;
    for (const posB of S.PILLAR_KEYS) {
      const pb = b.pillars[posB];
      if (!pb) continue;
      const { kind, desc } = C.branchRelation(pa[1], pb[1]);
      entries.push({ posA, posB, branchA: pa[1], branchB: pb[1], kind, desc });
    }
  }
  return entries;
}

export type BranchKindCounts = Record<BranchRelationKind, number>;

/** kind별 발생 횟수 집계. 대칭성: A↔B를 바꿔도 동일(합/충 쌍 자체가 대칭 판정이므로). */
export function branchKindCounts(entries: BranchPairEntry[]): BranchKindCounts {
  const counts: BranchKindCounts = { 육합: 0, 삼합: 0, 충: 0, 형: 0, 파: 0, 해: 0, 무관: 0 };
  for (const e of entries) counts[e.kind] += 1;
  return counts;
}

// ---------------- 확장 FACT 3: 일간 음양조화 ----------------

export interface YinYangHarmony {
  ownerDayMasterYang: boolean;
  memberDayMasterYang: boolean;
  /** 전통 명리 "음양배합" 원칙 — 일간의 음양이 서로 다르면 조화롭다고 본다. */
  harmonious: boolean;
}

export function computeYinYangHarmony(a: NormalizedPerson, b: NormalizedPerson): YinYangHarmony {
  const dayA = S.dayMaster(a);
  const dayB = S.dayMaster(b);
  const ownerDayMasterYang = C.STEM_YANG[dayA];
  const memberDayMasterYang = C.STEM_YANG[dayB];
  return {
    ownerDayMasterYang,
    memberDayMasterYang,
    harmonious: ownerDayMasterYang !== memberDayMasterYang,
  };
}

// ---------------- 조립: GunghapFactResult ----------------

export interface GunghapFactResult {
  factEngineVersion: string;
  factRuleVersion: string;
  factId: string;
  /** 귀인지도 V2 엔진 재사용 결과(S1~S6, 관계유형, resultId 등 그대로 보존). */
  base: GuinjiV2RelationResult;
  owner: SajuSummary;
  member: SajuSummary;
  tenGodMatrix: TenGodMatrix;
  tenGodGroupCounts: Record<string, number>;
  branchPairMatrix: BranchPairEntry[];
  branchKindCounts: BranchKindCounts;
  yinYangHarmony: YinYangHarmony;
}

/** relation.ts의 pyCanonicalJson과 동일한 목적(결정론적 직렬화)의 독립 구현.
 * [중복 사유] relation.ts는 이 함수를 export하지 않으므로, 귀인지도 파일을
 * 수정하지 않기 위해(검수 완료된 기존 파일 불변 원칙) 여기서 별도로 둔다.
 * 로직은 완전히 동일(키 알파벳 정렬 직렬화)하다. */
function canonicalJson(value: unknown): string {
  if (value === null || value === undefined) return "null";
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number" || typeof value === "boolean") return JSON.stringify(value);
  if (Array.isArray(value)) return "[" + value.map((v) => canonicalJson(v)).join(", ") + "]";
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const keys = Object.keys(obj).sort();
    return "{" + keys.map((k) => `${JSON.stringify(k)}: ${canonicalJson(obj[k])}`).join(", ") + "}";
  }
  throw new Error(`canonicalJson: unsupported value type ${typeof value}`);
}

async function sha1Hex(input: string): Promise<string> {
  const { createHash } = await import("crypto");
  return createHash("sha1").update(input, "utf-8").digest("hex");
}

function pillarsToPlain(pillars: NormalizedPerson["pillars"]): Record<string, [string, string] | null> {
  const out: Record<string, [string, string] | null> = {};
  for (const k of S.PILLAR_KEYS) {
    const v = pillars[k];
    out[k] = v ? [v[0], v[1]] : null;
  }
  return out;
}

async function computeFactId(owner: NormalizedPerson, member: NormalizedPerson): Promise<string> {
  const key = canonicalJson({
    a: pillarsToPlain(owner.pillars),
    b: pillarsToPlain(member.pillars),
    e: GUNGHAP_FACT_ENGINE_VERSION,
    r: GUNGHAP_FACT_RULE_VERSION,
  });
  const hash = await sha1Hex(key);
  return "gf_" + hash.slice(0, 16);
}

/**
 * 두 사람의 사주(PersonInput, 귀인지도 V2 계약과 동일한 한글 간지 묶음
 * 구조)로부터 궁합지도 FACT 전체를 계산한다.
 *
 * [순서 무관 — 결정론] ownerInput/guestInput의 순서를 바꿔 호출해도
 * `base.chemistryScore`/`base.grade`/`tenGodGroupCounts`/`branchKindCounts`
 * 등 분야별 판정에 쓰이는 모든 집계값은 동일하다(검수 지시 §3 "두 사람
 * 입력 순서 변경 시 일관성" 요구사항 — `scripts/gunghap/*.ts`에서 실측
 * 검증).
 */
export async function computeGunghapFact(
  ownerInput: PersonInput,
  guestInput: PersonInput,
): Promise<GunghapFactResult> {
  const a = S.normalize(ownerInput);
  const b = S.normalize(guestInput);

  // S1~S6 + 관계유형 + resultId — 귀인지도 V2 엔진 그대로 재사용(재구현 금지 원칙).
  const base = await computeRelation(ownerInput, guestInput);

  const tgMatrix = computeTenGodMatrix(a, b);
  const branchMatrix = computeBranchPairMatrix(a, b);

  return {
    factEngineVersion: GUNGHAP_FACT_ENGINE_VERSION,
    factRuleVersion: GUNGHAP_FACT_RULE_VERSION,
    factId: await computeFactId(a, b),
    base,
    owner: S.summarize(a),
    member: S.summarize(b),
    tenGodMatrix: tgMatrix,
    tenGodGroupCounts: tenGodGroupCounts(tgMatrix),
    branchPairMatrix: branchMatrix,
    branchKindCounts: branchKindCounts(branchMatrix),
    yinYangHarmony: computeYinYangHarmony(a, b),
  };
}
