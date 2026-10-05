// [STEP 6] 분량 사전 측정 스크립트 — DB 시딩 전에 각 topic의 detail 5블록(또는
// 4블록) 합산 글자수가 interpret-qa-check.ts의 DETAIL_MIN/MAX(1500~2500) 및
// TARGET_MIN/MAX(1800~2200) 범위에 드는지 확인한다. fillTemplate()과 동일한
// 치환 로직을 사용하기 위해 더미 evidenceNotes로 실제 interpret-fallback.ts의
// buildFallbackDetail()을 그대로 호출한다.
import { buildFallbackDetail } from "../../src/lib/saju-renewal/interpret-fallback";
import type { TemplateSeedItem } from "../seed-topic-prompt-templates-full";

function stripMarkup(text: string): string {
  return text.replace(/\[\[([^\]|]+)(\|[^\]]*)?\]\]/g, (_m, _key, display) =>
    display ? display.slice(1) : ""
  );
}
function visibleLength(text: string): number {
  return stripMarkup(text).length;
}

// MONEY_001~006의 requiredFacts 수에 맞춰 더미 evidence note 3개를 제공(가장 많이
// 쓰는 경우가 3개이므로). 적게 쓰는 topic은 앞에서부터 사용되고 나머지는
// fillTemplate 내부에서 evidenceNotes[0] 또는 중립 표현으로 대체된다.
const DUMMY_NOTES = ["편재/정재 존재 여부", "일간 기준 재성 오행 역산", "재성 오행-용신/희신 일치 여부"];
const DUMMY_TIMING = "대운 재성 유입 구간";

export function measureGroup(items: TemplateSeedItem[], isTimingMap: Record<string, boolean>) {
  const byTopic = new Map<string, TemplateSeedItem[]>();
  for (const it of items) {
    if (it.mode !== "detail") continue;
    const arr = byTopic.get(it.topicId) ?? [];
    arr.push(it);
    byTopic.set(it.topicId, arr);
  }

  const results: Array<{ topicId: string; length: number; pass: boolean; inTarget: boolean }> = [];

  for (const [topicId, arr] of byTopic) {
    const item = arr[0];
    const isTiming = isTimingMap[topicId] ?? false;
    const detail = buildFallbackDetail({
      topicId,
      topicName: topicId,
      evidenceNotes: DUMMY_NOTES,
      isTiming,
      fallbackJson: item.fallbackJson,
    });
    let total = 0;
    for (const b of detail.blocks) {
      total += visibleLength(b.body);
    }
    const pass = total >= 1500 && total <= 2500;
    const inTarget = total >= 1800 && total <= 2200;
    results.push({ topicId, length: total, pass, inTarget });
  }
  return results;
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
    const groups: Array<{ name: string; items: TemplateSeedItem[] }> = [
      { name: "MONEY", items: MONEY_TEMPLATES },
      { name: "TALENT", items: TALENT_TEMPLATES },
      { name: "RELATION", items: RELATION_TEMPLATES },
      { name: "LOVE", items: LOVE_TEMPLATES },
      { name: "LIFE", items: LIFE_TEMPLATES },
    ];
    let overallPass = true;
    for (const g of groups) {
      const results = measureGroup(g.items, isTimingMap);
      console.log(`=== ${g.name} 그룹 분량 측정 ===`);
      for (const r of results) {
        console.log(
          `${r.topicId}: ${r.length}자 — ${r.pass ? "PASS" : "FAIL(허용범위벗어남)"} / 목표범위(1800-2200) ${r.inTarget ? "IN" : "OUT"}`
        );
      }
      const allPass = results.every((r) => r.pass);
      if (!allPass) overallPass = false;
      console.log(allPass ? `[${g.name}] 전체 PASS\n` : `[${g.name}] 일부 FAIL — 재작성 필요\n`);
    }
    console.log(overallPass ? "[결과] 전체 그룹 PASS" : "[결과] 일부 그룹 FAIL");
  })();
}
