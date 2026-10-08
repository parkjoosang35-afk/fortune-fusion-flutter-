// 귀인지도 V2 TS 엔진 ↔ Python 골든 벡터(C01~C20) 대조 검증 스크립트.
//
// 목적: `src/lib/guinji-v2/relation.ts`(TS 포팅)가 Python 기준 소스
// (`guinji_v2_source/guinji_engine/relation.py`)와 동일한 입력에 대해
// 동일한 출력(resultId 제외, relationType/score/grade/gradeCode/ruleTrace
// 전체)을 내는지 1:1 비교한다. 20개 케이스 전부 일치해야 다음 단계
// (API 연결)로 진행할 수 있다.
//
// 실행: npx tsx scripts/verify-guinji-v2-golden.ts

import { readFileSync } from "fs";
import { join } from "path";
import { computeRelation } from "../src/lib/guinji-v2/relation";
import { CASES } from "../src/lib/guinji-v2/__fixtures__/demo-cases";

interface GoldenCase {
  name: string;
  resultId: string;
  relationType: string;
  score: number;
  grade: string;
  gradeCode: string;
  ruleTrace: Record<string, unknown>;
  fullTextLen: number;
}

function deepEqual(a: unknown, b: unknown, path: string, diffs: string[]): void {
  if (a === b) return;
  if (typeof a !== typeof b) {
    diffs.push(`${path}: type mismatch (${typeof a} vs ${typeof b}) — ${JSON.stringify(a)} vs ${JSON.stringify(b)}`);
    return;
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) {
      diffs.push(`${path}: array length mismatch (${a.length} vs ${b.length})`);
      // continue comparing overlapping items for more detail
    }
    const len = Math.max(a.length, b.length);
    for (let i = 0; i < len; i++) {
      deepEqual(a[i], b[i], `${path}[${i}]`, diffs);
    }
    return;
  }
  if (a && b && typeof a === "object" && typeof b === "object") {
    const aKeys = Object.keys(a as Record<string, unknown>);
    const bKeys = Object.keys(b as Record<string, unknown>);
    const allKeys = new Set([...aKeys, ...bKeys]);
    for (const k of allKeys) {
      deepEqual((a as Record<string, unknown>)[k], (b as Record<string, unknown>)[k], `${path}.${k}`, diffs);
    }
    return;
  }
  diffs.push(`${path}: value mismatch — ${JSON.stringify(a)} vs ${JSON.stringify(b)}`);
}

async function main() {
  const goldenPath = join(__dirname, "..", "src", "lib", "guinji-v2", "__fixtures__", "python_golden_vectors.json");
  const golden: GoldenCase[] = JSON.parse(readFileSync(goldenPath, "utf-8"));
  const goldenByName = new Map(golden.map((g) => [g.name, g]));

  let passCount = 0;
  let failCount = 0;
  const failures: string[] = [];

  for (const [name, owner, member] of CASES) {
    const g = goldenByName.get(name);
    if (!g) {
      failCount++;
      failures.push(`${name}: 골든 벡터에 케이스 없음`);
      continue;
    }

    let result;
    try {
      result = await computeRelation(owner, member);
    } catch (e) {
      failCount++;
      failures.push(`${name}: TS 엔진 실행 오류 — ${(e as Error).message}`);
      continue;
    }

    const diffs: string[] = [];
    // resultId는 제외(해시 알고리즘 동치성은 별도 검증했음 — 여기서는
    // 핵심 관계판정 로직의 동치성만 본다). 나머지 전부 비교.
    deepEqual(result.relationType, g.relationType, `${name}.relationType`, diffs);
    deepEqual(result.chemistryScore, g.score, `${name}.score`, diffs);
    deepEqual(result.grade, g.grade, `${name}.grade`, diffs);
    deepEqual(result.gradeCode, g.gradeCode, `${name}.gradeCode`, diffs);
    deepEqual(result.ruleTrace, g.ruleTrace, `${name}.ruleTrace`, diffs);

    // resultId도 별도로 비교(참고용 — 실패해도 FAIL 처리하지 않고 경고만).
    const resultIdMatch = result.resultId === g.resultId;

    if (diffs.length === 0) {
      passCount++;
      console.log(`✅ ${name}: PASS${resultIdMatch ? "" : "  (⚠ resultId 불일치 — 참고용, 비차단)"}`);
    } else {
      failCount++;
      failures.push(`${name}:\n  - ${diffs.join("\n  - ")}`);
      console.log(`❌ ${name}: FAIL`);
    }
  }

  console.log("\n========================================");
  console.log(`PASS=${passCount} FAIL=${failCount} / TOTAL=${CASES.length}`);
  console.log("========================================");

  if (failures.length > 0) {
    console.log("\n--- 실패 상세 ---");
    for (const f of failures) console.log(f);
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error("검증 스크립트 실행 오류:", e);
  process.exitCode = 1;
});
