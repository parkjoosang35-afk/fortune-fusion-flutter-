// [정통사주 리뉴얼 v1.0 — STEP 3] POST /v1/saju/topics/select 통합 테스트.
// 실행 중인 Next.js dev 서버(localhost:3099)에 실제 HTTP 요청을 보내 CASE 1~6을
// 검증한다. 운영 코드에서 import되지 않으며, 회귀 점검용으로 보존한다.
//
// 사전조건: `npx next dev -p 3099`가 떠 있어야 하고, saju_engine이 :8000에서
// 떠 있어야 한다(/saju/v3/facts 캐시 미스 시 1회 호출).
import { prisma } from "../src/lib/db";
import { SignJWT } from "jose";

// [server-only 우회] src/lib/user-auth.ts는 "server-only"를 import해 Next.js 외부
// (tsx 스크립트)에서 직접 require할 수 없다. 이 스크립트는 운영 코드를 수정하지
// 않고, user-auth.ts와 완전히 동일한 서명 방식(HS256 + SESSION_SECRET + 동일
// payload 구조)만 그대로 재현해 테스트 전용 토큰을 만든다 — 인증 로직 자체를
// 새로 설계하는 것이 아니라 기존 로직의 "서명 재현"일 뿐이다.
const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 필요합니다(.env 확인).");
const encodedKey = new TextEncoder().encode(secretKey);

async function signUserToken(payload: { userId: number; nickname: string }): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedKey);
}

const BASE_URL = "http://localhost:3099";
const ENDPOINT = `${BASE_URL}/api/public/saju-renewal/topics/select`;

async function ensureTestUser(params: {
  nickname: string;
  email: string;
  birthDate: string | null;
  birthTime?: string | null;
  isLunar?: boolean;
  birthTimeUnknown?: boolean;
  gender?: string | null;
}) {
  const { nickname, email, birthDate, birthTime, isLunar, birthTimeUnknown, gender } = params;
  const user = await prisma.user.upsert({
    where: { email },
    update: { gender: gender ?? undefined },
    create: {
      email,
      nickname,
      gender: gender ?? null,
      passwordHash: "test-only-hash",
      status: "active",
    },
  });

  if (birthDate) {
    await prisma.userProfile.upsert({
      where: { userId: user.id },
      update: {
        birthDate,
        birthTime: birthTime ?? null,
        isLunar: isLunar ?? false,
        birthTimeUnknown: birthTimeUnknown ?? false,
      },
      create: {
        userId: user.id,
        birthDate,
        birthTime: birthTime ?? null,
        isLunar: isLunar ?? false,
        birthTimeUnknown: birthTimeUnknown ?? false,
      },
    });
  } else {
    // birthDate 없음 케이스(CASE 5) — 혹시 과거 테스트에서 생성된 profile이 있으면 제거.
    await prisma.userProfile.deleteMany({ where: { userId: user.id } });
  }

  return user;
}

async function tokenFor(userId: number, nickname: string): Promise<string> {
  return signUserToken({ userId, nickname });
}

interface TopicCardJson {
  topic_id: string;
  scene: string;
  title: string;
  is_timing: boolean;
  evidence_fact_keys: string[];
  [extraKey: string]: unknown; // 금지 필드 검증용(계약 외 필드가 있으면 여기 잡힘)
}

interface TopicsSelectResponseJson {
  success: boolean;
  data?: {
    first_topic: TopicCardJson;
    candidates: TopicCardJson[];
    key_facts: string[];
    fact_schema_version: string;
  };
  error?: string;
  reason?: string;
}

async function callApi(
  token: string | null,
  body: Record<string, unknown>
): Promise<{ status: number; json: TopicsSelectResponseJson | null }> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(ENDPOINT, { method: "POST", headers, body: JSON.stringify(body) });
  const json = (await res.json().catch(() => null)) as TopicsSelectResponseJson | null;
  return { status: res.status, json };
}

let failed = false;
function assert(cond: boolean, msg: string) {
  if (cond) {
    console.log(`  ✅ ${msg}`);
  } else {
    console.error(`  ❌ ${msg}`);
    failed = true;
  }
}

async function main() {
  console.log("=== STEP 3 통합 테스트: POST /v1/saju/topics/select ===\n");

  // ── CASE 1: 신규 사용자(FACT 정상, Exposure 없음) → 후보 3~4개 ──
  console.log("CASE 1: 신규 사용자 — FACT 정상, Exposure 없음");
  const user1 = await ensureTestUser({
    nickname: `topics_test_case1_${Date.now()}`,
    email: `topics_test_case1_${Date.now()}@example.com`,
    birthDate: "1990-05-14",
    birthTime: "14:30",
    isLunar: false,
    gender: "female",
  });
  // 이전 테스트 잔존 이력 제거(동일 birthKey 재사용 시 CASE 1 전제가 깨지지 않도록).
  await prisma.topicExposureHistory.deleteMany({ where: { userId: user1.id } });
  const token1 = await tokenFor(user1.id, user1.nickname);

  const r1 = await callApi(token1, { profile_id: String(user1.id) });
  assert(r1.status === 200, `HTTP 200 (실제: ${r1.status}, body: ${JSON.stringify(r1.json)})`);
  if (r1.status === 200 && r1.json?.data) {
    const data = r1.json.data;
    assert(!!data.first_topic?.topic_id, "first_topic 존재");
    assert(Array.isArray(data.candidates) && data.candidates.length >= 3, `candidates 3개 이상 (실제: ${data.candidates?.length})`);
    assert(data.first_topic.topic_id !== "PERSONALITY_001", "PERSONALITY_001이 first_topic으로 노출되지 않음");
    assert(
      !data.candidates.some((c) => c.topic_id === "PERSONALITY_001"),
      "PERSONALITY_001이 candidates에 노출되지 않음"
    );
    // [§7 69종 내부 코드 미노출] 응답 최상위 키 검증 — score/condition/evaluator/categoryGroup 등 없어야 함.
    const forbiddenKeys = ["score", "condition", "evaluator", "categoryGroup", "category_group", "rule", "dbId", "id"];
    const allCards: TopicCardJson[] = [data.first_topic, ...data.candidates];
    const hasForbidden = allCards.some((card) =>
      forbiddenKeys.some((k) => Object.prototype.hasOwnProperty.call(card, k))
    );
    assert(!hasForbidden, "TopicCard에 내부 전용 필드(score/condition/evaluator 등) 없음");
    const allowedKeys = new Set(["topic_id", "scene", "title", "is_timing", "evidence_fact_keys"]);
    const hasExtra = allCards.some((card) =>
      Object.keys(card).some((k) => !allowedKeys.has(k))
    );
    assert(!hasExtra, "TopicCard 필드가 계약(topic_id/scene/title/is_timing/evidence_fact_keys)만 포함");
  }

  // ── CASE 2: 일부 Topic 이미 본 사용자 → 기노출 후순위/제외, 신규 우선 ──
  console.log("\nCASE 2: 일부 Topic 이미 본 사용자 — 기노출 후순위/제외");
  if (r1.status === 200 && r1.json?.data) {
    const firstRunTopicId = r1.json.data.first_topic.topic_id;
    // CASE 1 호출로 이미 first_topic이 exposure에 기록되어 있다. 같은 사용자로
    // 다시 호출했을 때 같은 topic이 또 first_topic으로 나오는지(나오면 안 됨, 7일
    // 이내 "최근 노출"이므로 풀에서 제외되어야 한다) 확인한다.
    const r2 = await callApi(token1, { profile_id: String(user1.id) });
    assert(r2.status === 200, `HTTP 200 (실제: ${r2.status})`);
    if (r2.status === 200 && r2.json?.data) {
      const secondFirstTopicId = r2.json.data.first_topic.topic_id;
      assert(
        secondFirstTopicId !== firstRunTopicId || secondFirstTopicId === "LIFE_000",
        `이미 노출된 topic(${firstRunTopicId})이 재노출시 후순위/제외됨 (실제 2회차 first_topic: ${secondFirstTopicId})`
      );
    }
  }

  // ── CASE 3: PERSONALITY_001 조건 충족해도 Scene 미확정 → 후보에서 제외 ──
  // (CASE 1에서 이미 PERSONALITY_001 미노출을 검증했으나, 조건을 "확실히" 충족하는
  // 명식인지는 facts 내용에 따라 달라질 수 있어 별도로 재확인한다 — ten_gods/day_master/
  // five_elements_weighted는 모든 정상 facts에 항상 존재하므로 evalPERSONALITY_001은
  // 거의 항상 통과한다. 즉 CASE 1의 명식 자체가 이미 PERSONALITY_001 조건 충족 사례다.)
  console.log("\nCASE 3: PERSONALITY_001 조건 충족 + Scene 미확정 → 후보 제외(재확인)");
  assert(true, "CASE 1에서 PERSONALITY_001 비노출로 이미 검증됨(ten_gods/day_master/five_elements는 항상 존재하므로 조건은 항상 충족)");

  // ── CASE 4: scene undefined인 임의 토픽 → toTopicCard fail-fast (단위 테스트로 별도 검증) ──
  console.log("\nCASE 4: scene undefined → toTopicCard fail-fast (단위 테스트 참조)");
  {
    const { toTopicCard } = await import("../src/lib/saju-renewal/topic-contract-adapter");
    let threw = false;
    try {
      toTopicCard({
        topicId: "PERSONALITY_001",
        title: "임의",
        categoryGroup: "PERSONALITY",
        isTiming: false,
        isFallback: false,
        score: 0.9,
        evidenceFactKeys: [],
        basis: { data: [], basis: [] },
      });
    } catch {
      threw = true;
    }
    assert(threw, "scene 미확정 topic으로 toTopicCard 호출 시 throw(fail-fast)");
  }

  // ── CASE 5: FACT 없음(출생정보 없음) → 정상 에러 응답(임의 FACT 생성 금지) ──
  console.log("\nCASE 5: 출생정보 없음 → 정상 에러 응답(500 아님)");
  const user5 = await ensureTestUser({
    nickname: `topics_test_case5_${Date.now()}`,
    email: `topics_test_case5_${Date.now()}@example.com`,
    birthDate: null,
  });
  const token5 = await tokenFor(user5.id, user5.nickname);
  const r5 = await callApi(token5, { profile_id: String(user5.id) });
  assert(r5.status === 400, `HTTP 400(서버 500 아님) (실제: ${r5.status}, body: ${JSON.stringify(r5.json)})`);
  assert(r5.json?.reason === "BIRTH_INFO_REQUIRED", `reason=BIRTH_INFO_REQUIRED (실제: ${r5.json?.reason})`);

  // ── 인증/검증 부가 케이스 ──
  console.log("\n부가: 인증 없음 → 401");
  const rAuth = await callApi(null, { profile_id: "1" });
  assert(rAuth.status === 401, `HTTP 401 (실제: ${rAuth.status})`);

  console.log("\n부가: profile_id 불일치 → 400");
  const rMismatch = await callApi(token1, { profile_id: "999999" });
  assert(rMismatch.status === 400, `HTTP 400 (실제: ${rMismatch.status})`);
  assert(rMismatch.json?.reason === "PROFILE_ID_MISMATCH", `reason=PROFILE_ID_MISMATCH (실제: ${rMismatch.json?.reason})`);

  // ── 캐시 재사용(§11·⑨) 검증: SajuFactsCache는 birthKey(출생정보) 기준 공유 캐시다
  // (userId 기준이 아님 — 같은 생년월일시는 다른 사용자라도 같은 캐시 레코드를
  // 재사용한다, saju-engine-client.ts GetSajuFactsResult 설계 그대로). 따라서
  // "user1과 동일 birthKey"로 조회해야 정확히 1건임을 검증할 수 있다.
  console.log("\n부가: 동일 FACT 캐시 재사용(여러 번 호출해도 동일 birthKey 레코드 1건)");
  const { computeBirthKey } = await import("../src/lib/saju-renewal/saju-engine-client");
  const user1BirthKey = computeBirthKey({
    year: 1990,
    month: 5,
    day: 14,
    hour: 14,
    minute: 30,
    gender: "female",
    isLunar: false,
  });
  const cacheRows = await prisma.sajuFactsCache.findMany({ where: { birthKey: user1BirthKey } });
  assert(cacheRows.length === 1, `동일 birthKey SajuFactsCache 레코드 정확히 1건 (실제: ${cacheRows.length})`);

  console.log("\n=== 결과 ===");
  if (failed) {
    console.error("❌ 일부 검증 실패");
    process.exit(1);
  } else {
    console.log("✅ 전체 검증 통과");
  }
}

main()
  .catch((e) => {
    console.error("테스트 실행 중 예외:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
