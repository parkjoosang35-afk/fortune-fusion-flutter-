// [STEP 6] 실제 checkInterpretSummary/checkInterpretDetail을 사용해 각 카테고리
// 템플릿의 fallback 결과가 QA를 통과하는지 검증한다. buildFallbackSummary/
// buildFallbackDetail()로 fallback을 실제 생성한 뒤 그대로 QA를 통과시킨다
// (중복 QA 로직 작성 금지 — STEP4/5에서 검증된 실제 함수를 그대로 재사용).
import { buildFallbackSummary, buildFallbackDetail } from "../../src/lib/saju-renewal/interpret-fallback";
import { checkInterpretSummary, checkInterpretDetail } from "../../src/lib/saju-renewal/interpret-qa-check";
import type { TemplateSeedItem } from "../seed-topic-prompt-templates-full";

const DUMMY_NOTES = ["편재/정재 존재 여부", "일간 기준 재성 오행 역산", "재성 오행-용신/희신 일치 여부"];

export async function verifyGroup(
  groupName: string,
  items: TemplateSeedItem[],
  isTimingMap: Record<string, boolean>
) {
  const byTopic = new Map<string, TemplateSeedItem[]>();
  for (const it of items) {
    const arr = byTopic.get(it.topicId) ?? [];
    arr.push(it);
    byTopic.set(it.topicId, arr);
  }

  console.log(`\n=== ${groupName} 그룹 QA 검증 ===`);
  let allPass = true;
  for (const [topicId, arr] of byTopic) {
    const isTiming = isTimingMap[topicId] ?? false;
    const summaryItem = arr.find((i) => i.mode === "summary");
    const detailItem = arr.find((i) => i.mode === "detail");

    if (summaryItem) {
      const summaryResult = buildFallbackSummary({
        topicId,
        topicName: topicId,
        evidenceNotes: DUMMY_NOTES,
        fallbackJson: summaryItem.fallbackJson,
      });
      const qa = checkInterpretSummary(summaryResult, { expectedTopicId: topicId, isTiming, knownTermKeys: [] });
      if (!qa.ok) {
        allPass = false;
        console.log(`  [FAIL] ${topicId} summary — ${JSON.stringify(qa.failures)}`);
      } else {
        console.log(`  [PASS] ${topicId} summary`);
      }
    } else {
      console.log(`  [MISSING] ${topicId} summary`);
      allPass = false;
    }

    if (detailItem) {
      const detailResult = buildFallbackDetail({
        topicId,
        topicName: topicId,
        evidenceNotes: DUMMY_NOTES,
        isTiming,
        fallbackJson: detailItem.fallbackJson,
      });
      const qa = checkInterpretDetail(detailResult, { expectedTopicId: topicId, isTiming, knownTermKeys: [] });
      if (!qa.ok) {
        allPass = false;
        console.log(`  [FAIL] ${topicId} detail — ${JSON.stringify(qa.failures)}`);
      } else {
        console.log(`  [PASS] ${topicId} detail`);
      }
    } else {
      console.log(`  [MISSING] ${topicId} detail`);
      allPass = false;
    }
  }
  return allPass;
}

if (require.main === module) {
  void (async () => {
    const { MONEY_TEMPLATES } = await import("./money");
    const { TALENT_TEMPLATES } = await import("./talent");
    const { RELATION_TEMPLATES } = await import("./relation");
    const { LOVE_TEMPLATES } = await import("./love");
    const { LIFE_TEMPLATES } = await import("./life");
    const isTimingMap: Record<string, boolean> = {
      MONEY_001: false,
      MONEY_003: false,
      MONEY_004: true,
      MONEY_005: false,
      MONEY_006: false,
      TALENT_001: false,
      TALENT_002: false,
      TALENT_003: false,
      TALENT_004: true,
      TALENT_005: true,
      RELATION_001: false,
      RELATION_002: false,
      RELATION_003: false,
      RELATION_004: false,
      RELATION_005: false,
      LOVE_001: false,
      LOVE_002: false,
      LOVE_003: false,
      LOVE_004: false,
      LOVE_005: true,
      LOVE_006: true,
      LIFE_000: false,
      LIFE_001: true,
      LIFE_002: true,
      LIFE_003: true,
      LIFE_004: true,
      LIFE_006: true,
    };
    const p1 = await verifyGroup("MONEY", MONEY_TEMPLATES, isTimingMap);
    const p2 = await verifyGroup("TALENT", TALENT_TEMPLATES, isTimingMap);
    const p3 = await verifyGroup("RELATION", RELATION_TEMPLATES, isTimingMap);
    const p4 = await verifyGroup("LOVE", LOVE_TEMPLATES, isTimingMap);
    const p5 = await verifyGroup("LIFE", LIFE_TEMPLATES, isTimingMap);
    const pass = p1 && p2 && p3 && p4 && p5;
    console.log(pass ? "\n[최종] 전체 그룹 QA PASS" : "\n[최종] 일부 그룹 FAIL");
    process.exit(pass ? 0 : 1);
  })();
}
