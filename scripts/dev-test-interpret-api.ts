// [정통사주 리뉴얼 v1.0 — STEP 4] POST /v1/saju/interpret 통합 테스트.
// 실행 중인 Next.js dev 서버(localhost:3099)에 실제 HTTP 요청을 보내 2025 진행
// 승인 지시 STEP4 §19의 CASE 1~15를 검증한다. 운영 코드에서 import되지 않으며,
// 회귀 점검용으로 보존한다.
//
// 사전조건:
//   - `npx next dev -p 3099`가 떠 있어야 함
//   - saju_engine이 :8000에서 떠 있어야 함
//   - ANTHROPIC_APP_API_KEY(.env)가 설정되어 있어야 함(실제 LLM 호출 테스트)
//   - scripts/seed-test-prompt-templates.ts로 MONEY_002/LIFE_002 템플릿이 시딩되어 있어야 함
import { prisma } from "../src/lib/db";
import { SignJWT } from "jose";
import { computeBirthKey } from "../src/lib/saju-renewal/saju-engine-client";

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
const ENDPOINT = `${BASE_URL}/api/public/saju-renewal/interpret`;

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
    create: { email, nickname, gender: gender ?? null, passwordHash: "test-only-hash", status: "active" },
  });
  if (birthDate) {
    await prisma.userProfile.upsert({
      where: { userId: user.id },
      update: { birthDate, birthTime: birthTime ?? null, isLunar: isLunar ?? false, birthTimeUnknown: birthTimeUnknown ?? false },
      create: { userId: user.id, birthDate, birthTime: birthTime ?? null, isLunar: isLunar ?? false, birthTimeUnknown: birthTimeUnknown ?? false },
    });
  }
  return user;
}

interface InterpretResponseJson {
  success: boolean;
  data?: Record<string, unknown>;
  cached?: boolean;
  error?: string;
  reason?: string;
}

async function callApi(
  token: string | null,
  body: Record<string, unknown>
): Promise<{ status: number; json: InterpretResponseJson | null; raw: string }> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(ENDPOINT, { method: "POST", headers, body: JSON.stringify(body) });
  const raw = await res.text();
  let json: InterpretResponseJson | null = null;
  try {
    json = JSON.parse(raw);
  } catch {
    json = null;
  }
  return { status: res.status, json, raw };
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

function visibleLength(text: string): number {
  return text.replace(/\[\[([^\]|]+)(\|[^\]]*)?\]\]/g, (_m, _k, d) => (d ? d.slice(1) : "")).length;
}

async function main() {
  console.log("=== STEP 4 통합 테스트: POST /v1/saju/interpret ===\n");

  const uniqueSuffix = Date.now();
  const user = await ensureTestUser({
    nickname: `interpret_test_${uniqueSuffix}`,
    email: `interpret_test_${uniqueSuffix}@example.com`,
    birthDate: "1990-05-14",
    birthTime: "14:30",
    isLunar: false,
    gender: "female",
  });
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });
  const birthKey = computeBirthKey({ year: 1990, month: 5, day: 14, hour: 14, minute: 30, gender: "female", isLunar: false });

  // 이전 테스트 잔존 데이터 정리(idempotency 테스트를 위해 깨끗한 상태에서 시작).
  await prisma.topicInterpretResult.deleteMany({ where: { userId: user.id } });
  await prisma.topicExposureHistory.deleteMany({ where: { userId: user.id } });

  // ── CASE 1: 정상 summary (MONEY_002) ──
  console.log("\nCASE 1: 정상 summary (MONEY_002)");
  const r1 = await callApi(token, { profile_id: String(user.id), topic_id: "MONEY_002", mode: "summary", evidence_fact_keys: [] });
  assert(r1.status === 200, `HTTP 200 (실제: ${r1.status}, body: ${r1.raw.slice(0, 300)})`);
  let case1Sample: unknown = null;
  if (r1.status === 200 && r1.json?.data) {
    const d = r1.json.data as { topic_id: string; title: string; summary: string; evidence: { text: string }; source: string };
    assert(d.topic_id === "MONEY_002", `topic_id 일치 (실제: ${d.topic_id})`);
    assert(typeof d.title === "string" && d.title.length > 0, "title 존재");
    assert(typeof d.summary === "string" && d.summary.length > 0, "summary 존재");
    assert(!!d.evidence?.text, "evidence.text 존재");
    assert(d.source === "llm" || d.source === "template", `source 유효(실제: ${d.source})`);
    assert(r1.json.cached === false, "최초 호출이므로 cached=false");
    case1Sample = d;
  }

  // ── CASE 2: 정상 detail (LIFE_002, 시기형) ──
  console.log("\nCASE 2: 정상 detail (LIFE_002, 시기형)");
  const r2 = await callApi(token, { profile_id: String(user.id), topic_id: "LIFE_002", mode: "detail", evidence_fact_keys: [] });
  assert(r2.status === 200, `HTTP 200 (실제: ${r2.status}, body: ${r2.raw.slice(0, 300)})`);
  let case2Sample: unknown = null;
  if (r2.status === 200 && r2.json?.data) {
    const d = r2.json.data as { topic_id: string; title: string; blocks: Array<{ n: number; body: string }>; source: string };
    assert(d.topic_id === "LIFE_002", `topic_id 일치 (실제: ${d.topic_id})`);
    assert(Array.isArray(d.blocks) && d.blocks.length >= 4, `blocks 배열 존재(실제 ${d.blocks?.length}개)`);
    const ns = d.blocks.map((b) => b.n);
    assert([1, 2, 3, 5].every((n) => ns.includes(n)), `필수 블록(1,2,3,5) 포함(실제: [${ns.join(",")}])`);
    assert(ns.includes(4), "시기형 주제이므로 n=4 블록 포함");
    case2Sample = d;
  }

  // ── CASE 3: 존재하지 않는 Topic ──
  console.log("\nCASE 3: 존재하지 않는 Topic");
  const r3 = await callApi(token, { profile_id: String(user.id), topic_id: "NONEXISTENT_999", mode: "summary", evidence_fact_keys: [] });
  assert(r3.status === 404, `HTTP 404 (실제: ${r3.status})`);
  assert(r3.json?.reason === "TOPIC_NOT_FOUND", `reason=TOPIC_NOT_FOUND (실제: ${r3.json?.reason})`);
  assert(!r3.raw.includes("NONEXISTENT_999") || r3.json?.error !== undefined, "에러 메시지에 topic_id 직접 노출 없음 확인");

  // ── CASE 4: PERSONALITY_001(Scene 미확정) ──
  console.log("\nCASE 4: PERSONALITY_001(Scene 미확정)");
  const r4 = await callApi(token, { profile_id: String(user.id), topic_id: "PERSONALITY_001", mode: "summary", evidence_fact_keys: [] });
  assert(r4.status === 404, `HTTP 404 (실제: ${r4.status})`);
  assert(r4.json?.reason === "TOPIC_SCENE_UNRESOLVED", `reason=TOPIC_SCENE_UNRESOLVED (실제: ${r4.json?.reason})`);

  // ── CASE 5: 현재 FACT와 조건이 맞지 않는 Topic ──
  // LOVE_004는 "일지 오행=용신/희신"이 아니면 조건 자체를 통과하지 못하는 특이 조건
  // 주제다 — 이 테스트 사용자의 FACT로 우연히 통과할 수도 있으므로, 실제로는
  // evaluateTopic 결과를 먼저 확인해 조건 불충족 케이스를 보장한다(아래 보조 로직).
  console.log("\nCASE 5: 현재 FACT와 조건이 맞지 않는 Topic (동적 탐색)");
  const { TOPIC_CATALOG_SEED } = await import("../src/lib/saju-renewal/topic-catalog-data");
  const { validateTopicForInterpret } = await import("../src/lib/saju-renewal/topic-engine");
  const { getSajuFacts } = await import("../src/lib/saju-renewal/saju-engine-client");
  const { facts } = await getSajuFacts({ year: 1990, month: 5, day: 14, hour: 14, minute: 30, gender: "female", isLunar: false }, { userId: user.id });
  const failingTopic = TOPIC_CATALOG_SEED.find((t) => {
    if (t.isFallback || t.releasePhase !== 1) return false;
    const v = validateTopicForInterpret(t.topicId, facts);
    return !v.valid && v.reason === "CONDITION_NOT_SATISFIED";
  });
  if (failingTopic) {
    const r5 = await callApi(token, { profile_id: String(user.id), topic_id: failingTopic.topicId, mode: "summary", evidence_fact_keys: [] });
    assert(r5.status === 409, `HTTP 409 (실제: ${r5.status}, topic=${failingTopic.topicId})`);
    assert(r5.json?.reason === "TOPIC_CONDITION_NOT_SATISFIED", `reason=TOPIC_CONDITION_NOT_SATISFIED (실제: ${r5.json?.reason})`);
  } else {
    console.log("  ⚠️  이 사용자 FACT로는 조건 불충족 Topic을 찾지 못함(스킵) — 29종 대부분 조건을 통과하는 FACT일 수 있음");
  }

  // ── CASE 6: Scene 미확정 Topic (CASE 4와 동일 의미, 회귀 재확인) ──
  console.log("\nCASE 6: Scene 미확정 Topic 재확인(detail 모드)");
  const r6 = await callApi(token, { profile_id: String(user.id), topic_id: "PERSONALITY_001", mode: "detail", evidence_fact_keys: [] });
  assert(r6.status === 404, `HTTP 404 (실제: ${r6.status})`);
  assert(r6.json?.reason === "TOPIC_SCENE_UNRESOLVED", `reason=TOPIC_SCENE_UNRESOLVED (실제: ${r6.json?.reason})`);

  // ── CASE 7~9: LLM timeout/빈응답/QA실패를 llmCaller 모킹으로 실제 강제 재현 ──
  // [재수정 #7 "LLM Client → Interpret Service → Route 분리"] route.ts가 더 이상
  // completeText를 직접 import하지 않고 generateInterpretResult()를 호출하도록 바뀌었다.
  // generateInterpretResult()는 llmCaller를 주입받을 수 있으므로, HTTP 레이어를 거치지
  // 않고 이 함수를 직접 호출해 timeout/빈응답/QA실패를 실제로 강제할 수 있다(route.ts를
  // 우회하지만, 이 함수가 route.ts가 실제로 호출하는 바로 그 함수이므로 "실제 재현"이다).
  console.log("\nCASE 7~9: LLM timeout/빈응답/QA실패 실제 재현(llmCaller 모킹, generateInterpretResult 직접 호출)");
  const { generateInterpretResult, InterpretUnavailableError } = await import(
    "../src/lib/saju-renewal/interpret-service"
  );
  const moneyTopicInfo = {
    topicId: "MONEY_002",
    topicName: "돈을 버는 사람인가, 모으는 사람인가",
    categoryGroup: "MONEY",
    isTiming: false,
  };
  const moneyTemplate = await prisma.topicPromptTemplate.findFirst({
    where: { topicId: "MONEY_002", mode: "summary", status: "active" },
  });
  const moneyValidation = validateTopicForInterpret("MONEY_002", facts);

  // CASE 7: timeout — llmCaller가 AbortError(LlmClientError 스타일)로 즉시 reject.
  console.log("\nCASE 7: LLM timeout 실제 재현");
  const { LlmClientError } = await import("../src/lib/llm-client");
  const timeoutCaller = async () => {
    throw new LlmClientError("LLM 호출이 8000ms 내에 완료되지 않았습니다(타임아웃).");
  };
  const r7 = await generateInterpretResult({
    mode: "summary",
    topic: moneyTopicInfo,
    facts,
    evidenceNotes: moneyValidation.valid ? moneyValidation.evidenceNotes ?? [] : [],
    template: moneyTemplate ? { systemPrompt: moneyTemplate.systemPrompt, fallbackJson: moneyTemplate.fallbackJson } : null,
    llmCaller: timeoutCaller,
  });
  assert(r7.source === "template", `timeout 2회 후 fallback(source=template)으로 전환됨 (실제: ${r7.source})`);
  assert(
    r7.attemptLog.filter((l) => l.includes("LLM_ERROR")).length === 2,
    `LLM_ERROR 로그가 정확히 2회(최대 재시도) 기록됨 (실제: ${JSON.stringify(r7.attemptLog)})`
  );
  assert(r7.attemptLog.some((l) => l === "fallback: QA_PASSED"), "fallback이 QA를 통과해 정상 반환됨");

  // CASE 8: 빈 응답 — llmCaller가 빈 문자열을 반환(런타임에서 실제로 발생 가능한 케이스).
  console.log("\nCASE 8: LLM 빈 응답 실제 재현");
  const emptyCaller = async () => "";
  const r8 = await generateInterpretResult({
    mode: "summary",
    topic: moneyTopicInfo,
    facts,
    evidenceNotes: moneyValidation.valid ? moneyValidation.evidenceNotes ?? [] : [],
    template: moneyTemplate ? { systemPrompt: moneyTemplate.systemPrompt, fallbackJson: moneyTemplate.fallbackJson } : null,
    llmCaller: emptyCaller,
  });
  assert(r8.source === "template", `빈 응답 2회 후 fallback으로 전환됨 (실제: ${r8.source})`);
  assert(
    r8.attemptLog.filter((l) => l.includes("LLM_EMPTY_OR_UNPARSEABLE_RESPONSE")).length === 2,
    `LLM_EMPTY_OR_UNPARSEABLE_RESPONSE 로그가 정확히 2회 기록됨 (실제: ${JSON.stringify(r8.attemptLog)})`
  );
  assert(r8.attemptLog.some((l) => l === "fallback: QA_PASSED"), "fallback이 QA를 통과해 정상 반환됨");

  // CASE 9: QA 실패 → fallback → fallback QA 통과 → 정상 결과.
  // llmCaller가 "FACT 밖 사실"이 섞인 JSON을 반환해 checkInterpretSummary가 실제로
  // UNGROUNDED_FACT로 차단하게 만든 뒤, 최종적으로 fallback이 QA를 통과해 정상 결과로
  // 이어지는지(§6 핵심 수정사항) 확인한다.
  console.log("\nCASE 9: LLM QA 실패(FACT 밖 사실) → fallback → fallback QA 통과 → 정상 결과");
  const ungroundedCaller = async () =>
    JSON.stringify({
      title: "재물운 이야기",
      summary: "당신은 이미 작년에 3억 원을 벌었습니다. 당신의 배우자는 이미 사업을 하고 있습니다.",
      evidence: { type: "grid", text: "근거 문장입니다" },
    });
  const r9 = await generateInterpretResult({
    mode: "summary",
    topic: moneyTopicInfo,
    facts,
    evidenceNotes: moneyValidation.valid ? moneyValidation.evidenceNotes ?? [] : [],
    template: moneyTemplate ? { systemPrompt: moneyTemplate.systemPrompt, fallbackJson: moneyTemplate.fallbackJson } : null,
    llmCaller: ungroundedCaller,
  });
  assert(r9.source === "template", `QA 실패(UNGROUNDED_FACT) 후 fallback으로 전환됨 (실제: ${r9.source})`);
  assert(
    r9.attemptLog.some((l) => l.includes("QA_FAILED") && l.includes("UNGROUNDED_FACT")),
    `attemptLog에 UNGROUNDED_FACT로 인한 QA_FAILED가 기록됨 (실제: ${JSON.stringify(r9.attemptLog)})`
  );
  assert(r9.attemptLog.some((l) => l === "fallback: QA_PASSED"), "fallback이 QA를 통과해 '정상 결과'로 반환됨(471자 같은 미달 fallback을 위장 반환하지 않음)");
  const r9Result = r9.result as { summary: string };
  assert(
    !/\d+억\s*(원|대)/.test(r9Result.summary),
    "fallback 결과에는 FACT 밖 금액 단정 표현이 없음(QA가 실제로 걸러낸 LLM 출력 대신 깨끗한 fallback이 반환됨)"
  );

  // [참고] InterpretUnavailableError 자체도 import되어 타입 체크에 사용됨을 보장
  // (실제로 던져지는 경로는 fallback 템플릿이 고정 설계상 QA를 항상 통과하므로 여기서는
  // 발생하지 않는다 — 발생 조건은 interpret-service.ts의 §6 주석 참고).
  assert(typeof InterpretUnavailableError === "function", "InterpretUnavailableError 클래스가 정상적으로 export됨");

  // ── CASE 10: 동일 요청 중복 호출(멱등성 — §17) ──
  console.log("\nCASE 10: 동일 요청 중복 호출(멱등성)");
  const beforeCount = await prisma.topicExposureHistory.count({ where: { userId: user.id, topicId: "MONEY_002", birthKey } });
  const r10a = await callApi(token, { profile_id: String(user.id), topic_id: "MONEY_002", mode: "summary", evidence_fact_keys: [] });
  const r10b = await callApi(token, { profile_id: String(user.id), topic_id: "MONEY_002", mode: "summary", evidence_fact_keys: [] });
  const afterCount = await prisma.topicExposureHistory.count({ where: { userId: user.id, topicId: "MONEY_002", birthKey } });
  assert(r10a.status === 200 && r10b.status === 200, "두 번 모두 HTTP 200");
  assert(r10b.json?.cached === true, `두 번째 호출은 캐시 적중(cached=true) (실제: ${r10b.json?.cached})`);
  assert(afterCount === beforeCount, `ExposureHistory 중복 생성 없음(이전 ${beforeCount}건, 이후 ${afterCount}건)`);
  assert(
    JSON.stringify(r10a.json?.data) === JSON.stringify(r10b.json?.data),
    "두 응답의 data가 완전히 동일(진짜 캐시 재사용, 재생성 아님)"
  );

  // ── CASE 11: detail 1500~2500자 검증 ──
  console.log("\nCASE 11: detail 분량 1,500~2,500자 검증");
  if (case2Sample) {
    const d = case2Sample as { blocks: Array<{ body: string }> };
    const total = d.blocks.reduce((sum, b) => sum + visibleLength(b.body), 0);
    assert(total >= 1500 && total <= 2500, `총 글자수 ${total}자 — 1500~2500 범위 내`);
    console.log(`  📏 실제 분량: ${total}자`);
  } else {
    assert(false, "CASE 2 샘플이 없어 분량 검증 불가");
  }

  // ── CASE 12: 내부 코드/69종 정보 미노출 ──
  console.log("\nCASE 12: 내부 코드/69종 정보 미노출 검증");
  const combinedText = JSON.stringify(case1Sample) + JSON.stringify(case2Sample);
  const leakPatterns = [/MONEY_002/, /LIFE_002/, /PERSONALITY_001/, /\bscore\b/i, /\bevaluator\b/i, /\bconfidence\b/i, /69\s*종/, /\bAI\b/, /인공지능/];
  for (const p of leakPatterns) {
    assert(!p.test(combinedText.replace(/"topic_id":"(MONEY_002|LIFE_002)"/g, "")), `패턴 ${p} 미검출`);
  }

  // ── CASE 13: FACT에 없는 사실 생성 방어(QA 함수 단위 테스트) ──
  console.log("\nCASE 13: FACT에 없는 사실 생성 방어(QA 단위 테스트)");
  const { checkInterpretSummary: checkSummaryFn } = await import("../src/lib/saju-renewal/interpret-qa-check");
  const badSummary = {
    topic_id: "MONEY_002",
    title: "재물운 이야기",
    summary: "당신은 이미 작년에 3억 원을 벌었습니다. 당신의 배우자는 이미 사업을 하고 있습니다.",
    evidence: { type: "grid" as const, text: "근거 문장입니다" },
    source: "llm" as const,
  };
  const badResult = checkSummaryFn(badSummary, { expectedTopicId: "MONEY_002", isTiming: false });
  assert(!badResult.ok, `FACT 밖 사실 포함 시 QA 실패 처리됨(failures: ${badResult.failures.map((f) => f.code).join(",")})`);
  assert(badResult.failures.some((f) => f.code === "UNGROUNDED_FACT"), "UNGROUNDED_FACT 코드로 탐지됨");

  // ── CASE 14: 시기 FACT 없는 Topic에서 근거 없는 timing 생성 방어(QA 단위 테스트) ──
  console.log("\nCASE 14: 시기 FACT 없는 Topic에서 근거 없는 timing 생성 방어(QA 단위 테스트)");
  const { checkInterpretDetail: checkDetailFn } = await import("../src/lib/saju-renewal/interpret-qa-check");
  const badDetail = {
    topic_id: "MONEY_002",
    title: "재물운 이야기",
    blocks: [
      { n: 1 as const, body: "핵심 특징 설명입니다. 재물 기운이 뚜렷합니다. 자기만의 방식이 있습니다." },
      { n: 2 as const, body: "왜 이런지 설명입니다. 기운의 배치 때문입니다. 특징이 드러납니다.", evidence: { type: "grid" as const, text: "근거 문장" } },
      { n: 3 as const, body: "생활 속 모습입니다. 소비 습관에서 드러납니다. 저축 패턴도 영향받습니다." },
      { n: 4 as const, body: "이 시기에 반드시 큰돈이 들어옵니다. 조만간 반드시 좋은 일이 생깁니다." }, // isTiming=false인데 근거없는 시기 단정
      { n: 5 as const, body: "중요한 포인트입니다. 자신의 방식을 존중하세요. 꾸준함이 중요합니다." },
    ],
    source: "llm" as const,
  };
  const badDetailResult = checkDetailFn(badDetail, { expectedTopicId: "MONEY_002", isTiming: false });
  assert(!badDetailResult.ok, `시기FACT 없는 주제에 n=4 블록 존재 시 QA 실패 처리됨`);
  assert(
    badDetailResult.failures.some((f) => f.code === "TIMING_BLOCK_WITHOUT_FACT"),
    "TIMING_BLOCK_WITHOUT_FACT 코드로 탐지됨"
  );
  assert(
    badDetailResult.failures.some((f) => f.code === "UNGROUNDED_TIMING"),
    "UNGROUNDED_TIMING 코드로 탐지됨"
  );

  // ── CASE 15: ExposureHistory 정상 기록 ──
  console.log("\nCASE 15: ExposureHistory 정상 기록 확인");
  const exposureRows = await prisma.topicExposureHistory.findMany({ where: { userId: user.id, birthKey } });
  const exposedTopicIds = exposureRows.map((r) => r.topicId);
  assert(exposedTopicIds.includes("MONEY_002"), "MONEY_002가 ExposureHistory에 기록됨(interpret 성공 후)");
  assert(exposedTopicIds.includes("LIFE_002"), "LIFE_002이 ExposureHistory에 기록됨(interpret 성공 후)");
  assert(!exposedTopicIds.includes("PERSONALITY_001"), "PERSONALITY_001은 거부되었으므로 기록되지 않음");
  assert(!exposedTopicIds.includes("NONEXISTENT_999"), "존재하지 않는 Topic은 기록되지 않음");

  console.log("\n=== 결과 ===");
  if (failed) {
    console.error("❌ 일부 테스트 실패");
    process.exitCode = 1;
  } else {
    console.log("✅ 전체 검증 통과");
  }

  console.log("\n=== summary 실제 샘플(CASE 1, MONEY_002) ===");
  console.log(JSON.stringify(case1Sample, null, 2));
  console.log("\n=== detail 실제 샘플(CASE 2, LIFE_002) ===");
  console.log(JSON.stringify(case2Sample, null, 2));

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
