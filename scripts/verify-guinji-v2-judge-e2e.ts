// judgeGuinjiRelationV2() 단위 시뮬레이션 — 실제 라우트가 하는 것과 동일하게
// (1) 어댑터 경유 판정 → (2) JSON.stringify(DB 저장 흉내) → (3) JSON.parse
// (DB 조회 흉내) 라운드트립을 거쳐도 reason이 멀쩍하게 살아있는지 확인한다.

import { judgeGuinjiRelationV2 } from "../src/lib/guinji-v2/judge";
import type { GuinjiSajuInput } from "../src/lib/guinji-relation-judger";

const mine: GuinjiSajuInput = {
  dayStemHanja: "甲",
  stems: { year: "癸", month: "甲", day: "甲", hour: "丙" },
  branches: { year: "巳", month: "申", day: "子", hour: "寅" },
  fiveElementsCount: { 목: 3, 화: 2, 토: 0, 금: 1, 수: 2 },
  sinsalIds: [],
};
const other: GuinjiSajuInput = {
  dayStemHanja: "庚",
  stems: { year: "庚", month: "辛", day: "壬", hour: "癸" },
  branches: { year: "申", month: "亥", day: "寅", hour: "巳" },
  fiveElementsCount: { 목: 1, 화: 1, 토: 0, 금: 3, 수: 3 },
  sinsalIds: [],
};

async function main() {
  const judged = await judgeGuinjiRelationV2(mine, other, { other: "테스트상대" });
  console.log(JSON.stringify(judged, null, 2));

  const serialized = JSON.stringify(judged.ohaengEvidence);
  const parsed = JSON.parse(serialized);
  console.log("\n--- round-trip 후 reason ---");
  console.log(parsed.reason);
  if (!parsed.reason || parsed.reason.length < 10) {
    console.error("FAIL: round-trip 후 reason 손상");
    process.exit(1);
  }
  console.log("\nE2E 시뮬레이션 OK");
}
main();
