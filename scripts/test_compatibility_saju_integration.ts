// [궁합 사주 팩터 개선 — 조건부 구현 승인 범위] I1~I4 통합 테스트.
//
// U1~U5(scripts/test_compatibility_saju_engine_score.ts)는 getSajuCompatibilityScore()
// 자체의 순수 함수 단위테스트다. 이 파일은 실제 `/api/public/compatibility/request`
// 라우트(POST)를 통해 saju_engine 호출 결과가 DB(detail.scoreEngineVersion)에
// 올바르게 저장되고, ErrorLog 집계가 발생하며, 기존 결과보기/재열람 흐름이
// 전혀 깨지지 않는지를 로컬 DB·실제 라우트 레벨에서 검증한다
// (test_compatibility_daily_access.ts와 동일한 패턴을 재사용).
//
// I1: saju_engine 정상 응답 → detail.scoreEngineVersion === 'saju-v1', ErrorLog 미생성.
// I2: saju_engine 연결 실패 → 요청은 여전히 200 성공(폴백), detail.scoreEngineVersion
//     === 'hash-fallback-network', ErrorLog 1건 생성(source/errorCode로 집계 가능).
// I3: 기존 결과보기(FREEPASS) 소비 흐름 불변 — saju_engine 상태와 무관하게
//     잔여횟수 정확히 1 차감, resultAccessTransaction.status === 'success'.
// I4: 재열람(idempotent) — scoreEngineVersion 필드가 아예 없는 "과거 레코드"를
//     흉내 낸 detail JSON으로도 재열람 응답이 깨지지 않는다(하위호환).
// I5: [운영 전 보완] 정상/422/비정상응답/타임아웃/네트워크오류 5종 전부가
//     동일한 라우트 경로를 통해 "기록(detail.scoreEngineVersion)"과
//     "집계(ErrorLog.errorCode)"가 1:1로 일관되게 연결되는지 실제 라우트
//     레벨에서 확인한다(U1~U5는 getSajuCompatibilityScore() 단위 검증이고,
//     이 블록은 route.ts까지 통째로 거친 결과가 DB에 그대로 반영되는지
//     보는 것이 다르다 — saju-v1만 ErrorLog 미생성, 나머지 4종은 모두
//     errorCode가 scoreEngineVersion과 정확히 일치하는 1건씩 생성).
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { NextRequest } from "next/server";
import { prisma } from "../src/lib/db";
import { signUserToken } from "../src/lib/user-auth";
import { grantOpenPass } from "../src/lib/open-pass-service";
import { POST } from "../src/app/api/public/compatibility/request/route";

async function main() {
  assert.equal(process.env.REGRESSION_LOCAL_DB, "1");
  assert.ok(process.env.DATABASE_URL?.includes("/home/user/workspace/"), "샌드박스 DB만 허용");

  const suffix = randomUUID().slice(0, 8);
  const user = await prisma.user.create({
    data: { email: `compat_saju_${suffix}@example.com`, nickname: `compat_saju_${suffix}`, passwordHash: "test" },
  });
  const policy = await prisma.passPolicy.create({
    data: { name: `궁합사주연동검증 ${suffix}`, passType: "event", durationMin: 1, grantCount: 12, validityDays: 1, isActive: false },
  });
  const { userPass } = await grantOpenPass({ userId: user.id, policyId: policy.id, sourceType: "test_mode" });
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });
  const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
  const templates = await prisma.aiPromptTemplate.findMany({ where: { fortuneTypeOrDomain: "compatibility", isActive: true } });

  const originalFetch = globalThis.fetch;
  // sajuMode로 saju_engine mock 응답을 테스트 케이스별로 바꾼다. LLM(completeText)
  // 쪽은 항상 정상 응답(3토픽)으로 둬 궁합 생성 자체는 항상 성공하게 한다 —
  // 이번 작업의 관심사는 "saju 팩터 출처 구분과 폴백"이지 LLM 실패 처리가 아니다
  // (LLM 실패 처리는 test_compatibility_daily_access.ts에서 이미 검증됨).
  let sajuMode: "ok" | "down" | "422" | "invalid" | "timeout" = "ok";
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    if (url.endsWith("/compatibility")) {
      if (sajuMode === "down") throw new Error("ECONNREFUSED(모의)");
      if (sajuMode === "422") return new Response(JSON.stringify({ detail: "validation error" }), { status: 422 });
      if (sajuMode === "invalid") return new Response(JSON.stringify({ final_score: 999 }), { status: 200 });
      if (sajuMode === "timeout") {
        // getSajuCompatibilityScore()가 넘긴 AbortController.signal이 실제로
        // abort될 때까지 응답하지 않는다 — 라우트 레벨에서도 타임아웃 코드
        // 경로(hash-fallback-timeout)가 실제로 타는지 확인하기 위함.
        return new Promise((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            const err = new Error("aborted");
            err.name = "AbortError";
            reject(err);
          });
        }) as Promise<Response>;
      }
      return new Response(JSON.stringify({ final_score: 81, band: "80-89" }), { status: 200 });
    }
    await new Promise((resolve) => setTimeout(resolve, 20));
    return new Response(
      JSON.stringify({ content: [{ type: "text", text: "검증용 궁합 해석: 서로의 장점을 존중하세요." }] }),
      { status: 200 }
    );
  };

  const remaining = async () => (await prisma.userPass.findUniqueOrThrow({ where: { id: userPass.id } })).remainingCount;
  const send = async (id: string, patch: Record<string, unknown> = {}) => {
    const response = await POST(
      new NextRequest("http://localhost/api/public/compatibility/request", {
        method: "POST",
        headers,
        body: JSON.stringify({
          type: "love", nameA: "나", nameB: "상대", birthDateA: "1992-05-10", birthDateB: "1993-08-21",
          paymentMethod: "FREEPASS", transactionId: id, ...patch,
        }),
      })
    );
    return { status: response.status, body: await response.json() };
  };
  const detailOf = async (compatIdSuffix: string) => {
    const id = Number(compatIdSuffix.replace("compat_", ""));
    const result = await prisma.compatibilityResult.findUniqueOrThrow({ where: { requestId: id } });
    return JSON.parse(result.detail) as { scoreEngineVersion?: string; factorScores?: Record<string, number> };
  };
  const errorLogCount = (errorCode: string) => prisma.errorLog.count({ where: { source: "api:compatibility:saju-engine", errorCode } });

  try {
    await prisma.aiPromptTemplate.updateMany({ where: { id: { in: templates.map((t) => t.id) } }, data: { isActive: false } });
    const templateId = (
      await prisma.aiPromptTemplate.create({ data: { fortuneTypeOrDomain: "compatibility", version: 9999, templateBody: "검증용", isActive: true } })
    ).id;

    // ── I1: saju_engine 정상 응답 → saju-v1, ErrorLog 미생성 ──
    sajuMode = "ok";
    const beforeOkErrorLog = await errorLogCount("saju-v1"); // saju-v1은 애초에 로그 안 남김(참고용 0 유지 확인)
    const okId = `compat_i1_${suffix}`;
    const okResult = await send(okId);
    assert.equal(okResult.status, 200);
    const okDetail = await detailOf(okResult.body.data.id);
    assert.equal(okDetail.scoreEngineVersion, "saju-v1");
    assert.equal(okDetail.factorScores?.saju, 81, "saju_engine의 final_score(81)가 그대로 factorScores.saju에 반영되어야 한다");
    assert.equal(await errorLogCount("saju-v1"), beforeOkErrorLog, "saju-v1 정상 경로는 ErrorLog를 남기지 않는다");
    assert.equal(await remaining(), 11);
    console.log("PASS I1: saju_engine 정상 응답 → detail.scoreEngineVersion=saju-v1, factorScores.saju=엔진값, ErrorLog 미생성");

    // ── I2: saju_engine 연결 실패 → 요청은 여전히 200(폴백), hash-fallback-network, ErrorLog 1건 ──
    sajuMode = "down";
    const beforeDownErrorLog = await errorLogCount("hash-fallback-network");
    const downId = `compat_i2_${suffix}`;
    const downResult = await send(downId);
    assert.equal(downResult.status, 200, "saju_engine 다운이어도 폴백으로 궁합 생성은 여전히 성공해야 한다(GENERATION_FAILED 아님)");
    const downDetail = await detailOf(downResult.body.data.id);
    assert.equal(downDetail.scoreEngineVersion, "hash-fallback-network");
    assert.notEqual(downDetail.factorScores?.saju, 81, "폴백 시 엔진값(81)을 그대로 쓰면 안 된다");
    assert.equal(await errorLogCount("hash-fallback-network"), beforeDownErrorLog + 1, "폴백 발생 1건이 ErrorLog로 집계되어야 한다");
    const errLog = await prisma.errorLog.findFirst({
      where: { source: "api:compatibility:saju-engine", errorCode: "hash-fallback-network" },
      orderBy: { id: "desc" },
    });
    assert.ok(errLog, "ErrorLog 행이 실제로 존재해야 한다");
    assert.ok(!errLog!.message.includes("1992-05-10") && !errLog!.message.includes("1993-08-21"), "ErrorLog 메시지에 생년월일(PII)이 포함되면 안 된다");
    assert.equal(await remaining(), 10);
    console.log("PASS I2: saju_engine 연결 실패 → 폴백으로 200 성공 유지, hash-fallback-network 기록, ErrorLog 1건(PII 미포함) 집계");

    // ── I3: 기존 FREEPASS 결과보기 소비 흐름 불변(saju_engine 상태와 무관) ──
    // I1/I2에서 이미 매 호출마다 remainingCount가 정확히 1씩만 줄었음을 확인했다
    // (11 → 10). 거래 상태도 함께 재확인한다.
    const i1Txn = await prisma.resultAccessTransaction.findUniqueOrThrow({ where: { transactionId: okId } });
    const i2Txn = await prisma.resultAccessTransaction.findUniqueOrThrow({ where: { transactionId: downId } });
    assert.equal(i1Txn.status, "success");
    assert.equal(i2Txn.status, "success");
    assert.equal(i1Txn.contentId, okResult.body.data.id);
    assert.equal(i2Txn.contentId, downResult.body.data.id);
    console.log("PASS I3: saju_engine 정상/폴백 모두 FREEPASS 1회 소비·거래 success 확정은 기존과 동일");

    // ── I4: 재열람(idempotent) — detail에 scoreEngineVersion이 "아예 없는" 과거
    // 레코드를 흉내 내도 재열람 응답이 깨지지 않아야 한다(하위호환, route.ts가
    // history/result와 마찬가지로 detail.topicResults/summary만 읽는 경로). ──
    const legacyId = `compat_i4_${suffix}`;
    const legacyResult = await send(legacyId);
    assert.equal(legacyResult.status, 200);
    const legacyCompatId = Number(legacyResult.body.data.id.replace("compat_", ""));
    // scoreEngineVersion 필드를 제거해 "이번 배포 이전 레코드"를 재현한다.
    const legacyDetail = await prisma.compatibilityResult.findUniqueOrThrow({ where: { requestId: legacyCompatId } });
    const legacyParsed = JSON.parse(legacyDetail.detail);
    delete legacyParsed.scoreEngineVersion;
    assert.ok(!("scoreEngineVersion" in legacyParsed), "제거가 제대로 되었는지 확인");
    await prisma.compatibilityResult.update({ where: { requestId: legacyCompatId }, data: { detail: JSON.stringify(legacyParsed) } });
    const beforeReviewRemaining = await remaining();
    const reviewResult = await send(legacyId); // 같은 transactionId → 재열람(existing.status==='success') 경로
    assert.equal(reviewResult.status, 200);
    assert.equal(reviewResult.body.data.id, legacyResult.body.data.id);
    assert.equal(reviewResult.body.data.resultAccess?.idempotent, true);
    assert.equal(reviewResult.body.data.summary, legacyParsed.summary);
    assert.equal(await remaining(), beforeReviewRemaining, "재열람은 추가 차감이 없어야 한다");
    console.log("PASS I4: scoreEngineVersion 없는 과거 레코드 형태로도 재열람(idempotent) 정상 동작, 추가 차감 없음");

    // ── I5: [운영 전 보완] 정상/422/비정상응답/타임아웃/네트워크오류 5종 전부를
    // 실제 라우트(POST)로 한 번씩 호출해, "기록(detail.scoreEngineVersion)"과
    // "집계(ErrorLog.errorCode)"가 모든 케이스에서 서로 정확히 일치하고,
    // saju-v1만 ErrorLog를 남기지 않음을 일괄 확인한다.
    // I1/I2/I4에서 이미 메인 유저(user)가 일일 절대 상한(5회) 중 3회를
    // 소비했으므로, 5개 시나리오를 그대로 추가하면 한도(DAILY_ABSOLUTE_AI_
    // CALL_LIMIT=5)에 걸려 403이 발생한다 — 이는 이 테스트가 깨는 "회귀"가
    // 아니라 테스트 설계상 별도 유저가 필요하다는 뜻이므로, I5 전용 유저를
    // 새로 만들어 격리한다(기존 테스트들의 "화이트리스트 테스트 계정" 패턴과
    // 동일하게 UNLIMITED_TEST_USER_IDS에 이 유저 id를 임시로 포함시킨다). ──
    const i5User = await prisma.user.create({
      data: { email: `compat_i5_${suffix}@example.com`, nickname: `compat_i5_${suffix}`, passwordHash: "test" },
    });
    const i5Policy = await prisma.passPolicy.create({
      data: { name: `궁합사주I5검증 ${suffix}`, passType: "event", durationMin: 1, grantCount: 12, validityDays: 1, isActive: false },
    });
    const { userPass: i5UserPass } = await grantOpenPass({ userId: i5User.id, policyId: i5Policy.id, sourceType: "test_mode" });
    const i5Token = await signUserToken({ userId: i5User.id, nickname: i5User.nickname });
    const i5Headers = { Authorization: `Bearer ${i5Token}`, "Content-Type": "application/json" };
    const originalUnlimitedIds = process.env.UNLIMITED_TEST_USER_IDS;
    process.env.UNLIMITED_TEST_USER_IDS = `${originalUnlimitedIds ? originalUnlimitedIds + "," : ""}${i5User.id}`;
    const sendI5 = async (id: string) => {
      const response = await POST(
        new NextRequest("http://localhost/api/public/compatibility/request", {
          method: "POST",
          headers: i5Headers,
          body: JSON.stringify({
            type: "love", nameA: "나", nameB: "상대", birthDateA: "1992-05-10", birthDateB: "1993-08-21",
            paymentMethod: "FREEPASS", transactionId: id,
          }),
        })
      );
      return { status: response.status, body: await response.json() };
    };
    try {
      type SajuMode = "ok" | "down" | "422" | "invalid" | "timeout";
      const scenarios: Array<{ mode: SajuMode; expected: string; label: string }> = [
        { mode: "ok", expected: "saju-v1", label: "정상" },
        { mode: "422", expected: "hash-fallback-unsupported-input", label: "422 입력거부" },
        { mode: "invalid", expected: "hash-fallback-invalid-response", label: "비정상응답(범위밖)" },
        { mode: "timeout", expected: "hash-fallback-timeout", label: "타임아웃" },
        { mode: "down", expected: "hash-fallback-network", label: "네트워크오류" },
      ];
      for (const sc of scenarios) {
        sajuMode = sc.mode;
        const id = `compat_i5_${sc.mode}_${suffix}`;
        const beforeCount = await errorLogCount(sc.expected);
        const result = await sendI5(id);
        assert.equal(result.status, 200, `[I5:${sc.label}] saju_engine 상태와 무관하게 궁합 요청은 200이어야 한다`);
        const detail = await detailOf(result.body.data.id);
        assert.equal(detail.scoreEngineVersion, sc.expected, `[I5:${sc.label}] detail.scoreEngineVersion 기록이 일치해야 한다`);
        if (sc.expected === "saju-v1") {
          assert.equal(await errorLogCount(sc.expected), beforeCount, `[I5:${sc.label}] saju-v1 정상 경로는 ErrorLog를 남기지 않는다`);
        } else {
          assert.equal(await errorLogCount(sc.expected), beforeCount + 1, `[I5:${sc.label}] ErrorLog 집계(errorCode=${sc.expected})가 기록과 1:1로 증가해야 한다`);
        }
      }
      console.log("PASS I5: 정상/422/비정상응답/타임아웃/네트워크오류 5종 전부 — 기록(scoreEngineVersion)과 집계(ErrorLog.errorCode) 일관성 확인");
    } finally {
      process.env.UNLIMITED_TEST_USER_IDS = originalUnlimitedIds;
      await prisma.resultAccessTransaction.deleteMany({ where: { userId: i5User.id } });
      await prisma.compatibilityResult.deleteMany({ where: { request: { requesterUserId: i5User.id } } });
      await prisma.aiRequestLog.deleteMany({
        where: { domain: "compatibility", requestRefId: { in: (await prisma.compatibilityRequest.findMany({ where: { requesterUserId: i5User.id }, select: { id: true } })).map((r) => r.id) } },
      });
      await prisma.compatibilityRequest.deleteMany({ where: { requesterUserId: i5User.id } });
      await prisma.userPass.deleteMany({ where: { userId: i5User.id } });
      await prisma.passPolicy.delete({ where: { id: i5Policy.id } });
      await prisma.user.delete({ where: { id: i5User.id } });
      void i5UserPass;
    }

    console.log(`궁합 saju_engine 연동 통합테스트(I1~I5) 전부 통과. (suffix=${suffix})`);

    await prisma.aiPromptTemplate.delete({ where: { id: templateId } });
  } finally {
    globalThis.fetch = originalFetch;
    await prisma.aiPromptTemplate.updateMany({ where: { id: { in: templates.map((t) => t.id) } }, data: { isActive: true } });
    await prisma.errorLog.deleteMany({ where: { source: "api:compatibility:saju-engine", message: { contains: `compat_` } } });
    await prisma.resultAccessTransaction.deleteMany({ where: { userId: user.id } });
    await prisma.compatibilityResult.deleteMany({ where: { request: { requesterUserId: user.id } } });
    await prisma.aiRequestLog.deleteMany({
      where: { domain: "compatibility", requestRefId: { in: (await prisma.compatibilityRequest.findMany({ where: { requesterUserId: user.id }, select: { id: true } })).map((r) => r.id) } },
    });
    await prisma.compatibilityRequest.deleteMany({ where: { requesterUserId: user.id } });
    await prisma.userPass.deleteMany({ where: { userId: user.id } });
    await prisma.passPolicy.delete({ where: { id: policy.id } });
    await prisma.user.delete({ where: { id: user.id } });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("TEST FAILED:", error);
    process.exit(1);
  });
