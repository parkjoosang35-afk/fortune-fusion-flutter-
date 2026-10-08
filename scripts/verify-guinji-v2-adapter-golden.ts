// 귀인지도 V2 어댑터(guinji-v2/adapter.ts) 회귀 검증 스크립트.
//
// [검증 목적] "GuinjiSajuInput(한자) → adapter → PersonInput(한글)" 변환이
// 원래 한글 PersonInput을 그대로 입력했을 때와 100% 동일한 결과를
// 만들어내는지 확인한다. 즉 어댑터가 결과를 왜곡하지 않음을 증명한다.
//
// [방법] 20개 골든 벡터 입력(CASES, 한글 PersonInput)을 STEM_HANJA/
// BRANCH_HANJA로 한자 변환해 "가짜 GuinjiSajuInput"을 만들고, 이를 다시
// adapter.guinjiSajuInputToV2()로 되돌려 한글 PersonInput을 복원한다.
// 복원된 PersonInput으로 computeRelation()을 실행한 결과가, 원본
// PersonInput으로 직접 실행한 결과(= 기존 골든벡터 검증을 통과한 결과)와
// 완전히 동일한지(resultId 포함) 비교한다.
//
// [제외] C18(day만 있고 나머지 null)과 C08(member 쪽 hour가 null)은
// 실제 운영 GuinjiSajuInput 계약과 맞지 않아 제외한다 — 운영 계약은
// 4주 전부 문자열(한자)이 필수다(시간 미상이어도 정오 가정으로 항상
// 채워 보냄, `guinjiSajuInputFromManseryeok`/`guinjiSajuInputFromProfile`
// 양쪽 모두 hour 기둥을 항상 채운다). 이 두 케이스는 어댑터 입력 전제
// 자체와 맞지 않아 회귀 대상에서 제외한다(엔진 자체의 null 허용 동작은
// 이미 relation.golden 검증에서 커버됨).

import { computeRelation } from "../src/lib/guinji-v2/relation";
import type { PersonInput } from "../src/lib/guinji-v2/saju";
import { STEM_HANJA, BRANCH_HANJA } from "../src/lib/guinji-v2/constants";
import { guinjiSajuInputToV2 } from "../src/lib/guinji-v2/adapter";
import type { GuinjiSajuInput } from "../src/lib/guinji-relation-judger";
import { CASES } from "../src/lib/guinji-v2/__fixtures__/demo-cases";

/** 한글 PersonInput(4주 전부 필수) → 가짜 한자 GuinjiSajuInput. */
function toFakeHanjaInput(p: PersonInput): GuinjiSajuInput {
  const pillars = p.pillars;
  if (!pillars) throw new Error("pillars 누락");
  const get = (key: "year" | "month" | "day" | "hour") => {
    const v = pillars[key];
    if (!v || v.length !== 2) {
      throw new Error(`${key} 기둥이 없거나 형식이 올바르지 않음(테스트 전제 위반): ${JSON.stringify(v)}`);
    }
    return v;
  };
  const stemOf = (v: string) => STEM_HANJA[v[0]];
  const branchOf = (v: string) => BRANCH_HANJA[v[1]];

  const y = get("year");
  const m = get("month");
  const d = get("day");
  const h = get("hour");

  return {
    dayStemHanja: stemOf(d),
    stems: { year: stemOf(y), month: stemOf(m), day: stemOf(d), hour: stemOf(h) },
    branches: { year: branchOf(y), month: branchOf(m), day: branchOf(d), hour: branchOf(h) },
    fiveElementsCount: { 목: 0, 화: 0, 토: 0, 금: 0, 수: 0 }, // 어댑터가 사용하지 않음(더미).
    sinsalIds: [],
  };
}

function deepEqual(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

async function main() {
  let pass = 0;
  let fail = 0;
  const skipped: string[] = [];

  for (const [id, ownerP, memberP] of CASES) {
    if (id === "C18" || id === "C08") {
      skipped.push(id);
      continue;
    }
    try {
      // 1) 원본 한글 PersonInput으로 직접 실행(기존 골든벡터 기준 결과).
      const directResult = await computeRelation(ownerP, memberP);

      // 2) 한글 → 가짜 한자(GuinjiSajuInput) → 어댑터로 한글 복원 → 실행.
      const ownerHanja = toFakeHanjaInput(ownerP);
      const memberHanja = toFakeHanjaInput(memberP);
      const ownerRestored = guinjiSajuInputToV2(ownerHanja, ownerP.name ?? undefined);
      const memberRestored = guinjiSajuInputToV2(memberHanja, memberP.name ?? undefined);
      const adaptedResult = await computeRelation(ownerRestored, memberRestored);

      const ok =
        deepEqual(directResult.relationType, adaptedResult.relationType) &&
        deepEqual(directResult.chemistryScore, adaptedResult.chemistryScore) &&
        deepEqual(directResult.grade, adaptedResult.grade) &&
        deepEqual(directResult.gradeCode, adaptedResult.gradeCode) &&
        deepEqual(directResult.ruleTrace, adaptedResult.ruleTrace) &&
        deepEqual(directResult.resultId, adaptedResult.resultId);

      if (ok) {
        pass++;
        console.log(`[PASS] ${id}`);
      } else {
        fail++;
        console.log(`[FAIL] ${id}`);
        console.log("  direct :", JSON.stringify({ t: directResult.relationType, s: directResult.chemistryScore, id: directResult.resultId }));
        console.log("  adapted:", JSON.stringify({ t: adaptedResult.relationType, s: adaptedResult.chemistryScore, id: adaptedResult.resultId }));
      }
    } catch (e) {
      fail++;
      console.log(`[ERROR] ${id}:`, e);
    }
  }

  console.log(`\nPASS=${pass} FAIL=${fail} SKIPPED=${skipped.join(",")}`);
  if (fail > 0) process.exit(1);
}

main();
