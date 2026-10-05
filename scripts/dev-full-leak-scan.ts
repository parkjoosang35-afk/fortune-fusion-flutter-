// [STEP6.5 디버그 문구 수정 후속 — 26개 활성 Topic 전체 동적 interpret 호출 +
// 내부 문구 누출 검사] 사용자 지시: "26개 활성 Topic 전체에 대해 내부 문구 누출
// 검사를 한 번 돌리게 하세요." route.ts 전체 파이프라인(인증→FACT→재검증→Prompt
// →LLM/fallback→QA→DB저장)을 실제 HTTP 호출로 통과시켜, 최종적으로 사용자에게
// 나가는 응답 텍스트에 운영/디버그 메타 표현이 없는지 확인한다.
import { TOPIC_CATALOG_SEED } from "../src/lib/saju-renewal/topic-catalog-data";
import { SCENE_UNRESOLVED_TOPIC_IDS } from "../src/lib/saju-renewal/topic-contract-adapter";
import { SignJWT } from "jose";
import { prisma } from "../src/lib/db";

const BASE_URL = "http://localhost:3099";
const USER_ID = 300;

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 필요");
const encodedKey = new TextEncoder().encode(secretKey);

const LEAK_PATTERNS: RegExp[] = [
  /\b69\s*종/i, /\bE0?\d{1,2}\b/, /\bG0?\d{1,2}\b/, /\bA0?\d{1,2}\b/, /\bB0?\d{1,2}\b/,
  /\b[A-Z]+_\d{3}\b/, /\bevaluator\b/i, /\bcategoryGroup\b/i, /\bconditionType\b/i,
  /\bfact\s*key\b/i, /\bDB\s*id\b/i, /\btopic_id\b/i, /\bscore\b/i, /\bconfidence\b/i,
  /폴백/, /fallback/i, /내부\s*디버그/, /디버그/, /감사용/, /평가자/, /테스트용/,
  /캐시\s*경로/, /항상\s*활성/, /지시서\s*§/, /템플릿\s*경로/, /운영\s*메타/, /개발\s*메타/,
  /\bAI\b/, /인공지능/, /에이아이/,
];

function extractContentText(data: any, mode: string): string {
  const texts: string[] = [data.title ?? ""];
  if (mode === "summary") {
    texts.push(data.summary ?? "");
    if (data.evidence?.text) texts.push(data.evidence.text);
  } else {
    for (const b of data.blocks ?? []) {
      texts.push(b.body ?? "");
      if (b.evidence?.text) texts.push(b.evidence.text);
    }
  }
  return texts.join("\n");
}

async function main() {
  const token = await new SignJWT({ userId: USER_ID, nickname: "qaUserA" })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedKey);

  const targets = TOPIC_CATALOG_SEED.filter(
    (t) => t.releasePhase === 1 && !SCENE_UNRESOLVED_TOPIC_IDS.includes(t.topicId)
  );
  console.log(`대상 Topic 수: ${targets.length}`);

  let totalCalls = 0;
  let leakFound = 0;
  const failures: string[] = [];

  for (const t of targets) {
    for (const mode of ["summary", "detail"] as const) {
      // 캐시 적중 방지(QA 우회 방지) — 매번 삭제 후 재생성해서 실제 파이프라인을 다시 태운다.
      await prisma.topicInterpretResult.deleteMany({
        where: { userId: USER_ID, topicId: t.topicId, mode },
      });

      const res = await fetch(`${BASE_URL}/api/public/saju-renewal/interpret`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({ profile_id: String(USER_ID), topic_id: t.topicId, mode }),
      });
      const json = await res.json();
      totalCalls++;

      if (!json.success) {
        failures.push(`${t.topicId}/${mode}: HTTP ${res.status} reason=${json.reason}`);
        continue;
      }

      const content = extractContentText(json.data, mode);
      let topicLeak = false;
      for (const p of LEAK_PATTERNS) {
        if (p.test(content)) {
          console.log(`❌ LEAK [${t.topicId}/${mode}] pattern=${p}`);
          console.log(`   context: ...${content.slice(Math.max(0, content.search(p) - 30), content.search(p) + 50)}...`);
          leakFound++;
          topicLeak = true;
        }
      }
      console.log(`${topicLeak ? "❌" : "✅"} ${t.topicId}/${mode} (source=${json.data.source}, len=${content.length})`);
    }
  }

  console.log(`\n=== 최종 결과 ===`);
  console.log(`총 호출: ${totalCalls}`);
  console.log(`누출 발견: ${leakFound}`);
  if (failures.length > 0) {
    console.log(`API 실패(거부) 건: ${failures.length}`);
    failures.forEach((f) => console.log("  - " + f));
  }
  console.log(leakFound === 0 ? "✅ 전체 PASS — 내부 문구 누출 없음" : "❌ FAIL — 누출 발견됨");

  await prisma.$disconnect();
  process.exit(leakFound === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
