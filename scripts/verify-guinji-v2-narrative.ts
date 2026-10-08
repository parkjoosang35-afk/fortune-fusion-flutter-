// narrative.ts 수동 검증 스크립트 — "빈 문자열/대충 만든 문장"이 아닌지,
// 골든벡터 샘플 몇 개에 대해 실제로 합리적인 한국어 reason 문장이
// 생성되는지 확인한다. (task #4 완료 조건 수동 검증용, 자동 테스트는
// 별도 CI 단계가 아니라 이 스크립트 실행 결과를 눈으로 확인하는 방식.)

import { computeRelation } from "../src/lib/guinji-v2/relation";
import { buildOhaengEvidence } from "../src/lib/guinji-v2/narrative";
import { CASES } from "../src/lib/guinji-v2/__fixtures__/demo-cases";

async function main() {
  // C08은 hour(시주)가 null인 케이스 — mine/other 양쪽 다 커버하도록 몇 개 더 포함.
  const sampleIds = new Set(["C01", "C05", "C08", "C11", "C15"]);
  const list = CASES.filter(([id]) => sampleIds.has(id));
  let allOk = true;

  for (const [caseId, a, b] of list) {
    const result = await computeRelation(a, b);
    const evidence = buildOhaengEvidence(result);

    console.log(`\n=== ${caseId} ===`);
    console.log("relationType:", result.relationType, "/ score:", result.chemistryScore, "/ grade:", result.grade);
    console.log("mine:", evidence.mine);
    console.log("other:", evidence.other);
    console.log("reason:", evidence.reason);

    // 최소 검증: reason이 빈 문자열이 아니고, 의미 없는 placeholder가 아니며,
    // 충분한 길이(단순 "." 같은 더미가 아님)를 가져야 한다.
    const bad =
      !evidence.reason ||
      evidence.reason.trim().length < 10 ||
      evidence.reason.includes("undefined") ||
      evidence.reason.includes("null") ||
      evidence.reason.includes("NaN");
    if (bad) {
      console.error(`  ❌ FAIL: reason이 비정상입니다 -> "${evidence.reason}"`);
      allOk = false;
    } else {
      console.log("  ✅ OK");
    }
  }

  console.log(allOk ? "\n전체 PASS" : "\n일부 FAIL — 위 로그 확인 필요");
  process.exit(allOk ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
