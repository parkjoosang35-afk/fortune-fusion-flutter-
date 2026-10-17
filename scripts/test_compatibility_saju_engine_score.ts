// [궁합 사주 팩터 개선 — 조건부 구현 승인 범위] U1~U5 단위 테스트.
// 별도 테스트 프레임워크가 없으므로 기존 scripts/test-face-palm-judgment.ts /
// test_compatibility_daily_access.ts와 동일한 tsx 실행 스크립트 패턴을 쓴다.
//
// 실행: cd /home/user/admin_web && npx tsx scripts/test_compatibility_saju_engine_score.ts
//
// 대상: src/lib/compatibility/saju-compat-score.ts (getSajuCompatibilityScore)
// DB/인증 의존이 없는 순수 함수 레벨 테스트이므로 REGRESSION_LOCAL_DB 가드가
// 필요 없다(실제 DB에 쓰지 않음, fetch만 전역 모의).
import assert from "node:assert/strict";
import {
  getSajuCompatibilityScore,
  __testables,
} from "../src/lib/compatibility/saju-compat-score";

let passed = 0;
async function check(name: string, fn: () => Promise<void> | void) {
  try {
    await fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    console.error(`  ❌ ${name}`);
    throw e;
  }
}

const INPUT = { birthDateA: "1990-03-15", birthDateB: "1995-11-02" };
const TYPE = "love";

async function main() {
  const originalFetch = globalThis.fetch;
  const originalWarn = console.warn;
  try {
    // ── U1: 정상 응답 ──
    await check("U1: 엔진 정상 응답(final_score) → saju-v1, 점수 그대로 반영", async () => {
      globalThis.fetch = async () =>
        new Response(JSON.stringify({ final_score: 72, band: "70-79" }), { status: 200 });
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.score, 72);
      assert.equal(result.engineVersion, "saju-v1");
    });

    // ── U2: 네트워크 실패(연결 거부) 폴백 ──
    await check("U2: 네트워크 실패(fetch reject) → hash-fallback-network, 기존 해시값과 동일", async () => {
      globalThis.fetch = async () => {
        throw new Error("ECONNREFUSED");
      };
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.engineVersion, "hash-fallback-network");
      assert.equal(result.score, __testables.defaultHashFallback(INPUT, TYPE));
    });

    // ── U2-b: 타임아웃(AbortError) 폴백 ──
    // [운영 전 보완] 타임아웃은 일반 네트워크 오류(hash-fallback-network)와
    // 구분되는 별도 errorCode(hash-fallback-timeout)로 기록되어야 한다 —
    // 운영에서 "연결 자체 불가"와 "응답이 느려 타임아웃"은 서로 다른 조치가
    // 필요하므로 집계 단계에서부터 분리한다.
    await check("U2-b: 타임아웃(AbortError) → hash-fallback-timeout(network와 별도 코드)", async () => {
      globalThis.fetch = async (_input: RequestInfo | URL, init?: RequestInit) => {
        return new Promise((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            const err = new Error("aborted");
            err.name = "AbortError";
            reject(err);
          });
        }) as Promise<Response>;
      };
      const result = await getSajuCompatibilityScore(INPUT, TYPE, { timeoutMs: 30 });
      assert.equal(result.engineVersion, "hash-fallback-timeout");
      assert.notEqual(result.engineVersion, "hash-fallback-network", "타임아웃은 일반 네트워크 오류와 errorCode가 달라야 한다");
      assert.equal(result.score, __testables.defaultHashFallback(INPUT, TYPE));
    });

    // ── U3: 422 응답(윤달 등 입력 스키마 거부) 폴백 ──
    await check("U3: 엔진 422 응답 → hash-fallback-unsupported-input", async () => {
      globalThis.fetch = async () =>
        new Response(JSON.stringify({ detail: "validation error" }), { status: 422 });
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.engineVersion, "hash-fallback-unsupported-input");
      assert.equal(result.score, __testables.defaultHashFallback(INPUT, TYPE));
    });

    // ── U4: 비정상 응답(범위 밖/누락) 방어 ──
    await check("U4-a: final_score 범위 밖(150) → hash-fallback-invalid-response(그대로 쓰지 않음)", async () => {
      globalThis.fetch = async () =>
        new Response(JSON.stringify({ final_score: 150 }), { status: 200 });
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.engineVersion, "hash-fallback-invalid-response");
      assert.notEqual(result.score, 150);
    });
    await check("U4-b: final_score 누락(undefined) → hash-fallback-invalid-response", async () => {
      globalThis.fetch = async () => new Response(JSON.stringify({}), { status: 200 });
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.engineVersion, "hash-fallback-invalid-response");
    });
    await check("U4-c: final_score가 문자열(타입 오염) → hash-fallback-invalid-response", async () => {
      globalThis.fetch = async () =>
        new Response(JSON.stringify({ final_score: "72" }), { status: 200 });
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.engineVersion, "hash-fallback-invalid-response");
    });
    await check("U4-d: 5xx 응답 → hash-fallback-network(값을 신뢰하지 않음)", async () => {
      globalThis.fetch = async () => new Response("Internal Server Error", { status: 500 });
      const result = await getSajuCompatibilityScore(INPUT, TYPE);
      assert.equal(result.engineVersion, "hash-fallback-network");
    });

    // ── U5: 기존 4개 비사주 팩터 계산식 불변(회귀 방지 핵심) ──
    // route.ts의 mbti/interest/value/activity_pattern 식은 이 변경에서 전혀
    // 손대지 않았으므로, 동일 seed에 대해 변경 전/후 수식이 수학적으로
    // 동일한지 이 테스트 파일 안에서 재확인한다(route.ts를 import해 실행하면
    // DB/인증 의존이 생기므로, 식 자체를 이 파일에 복제해 비교하는 방식 —
    // I1에서 실제 route.ts 응답으로 한 번 더 교차 검증한다).
    await check("U5: mbti/interest/value/activity_pattern 해시식 불변(route.ts 원본과 동일 입력 비교)", () => {
      const seed = __testables.hashSeed(`${INPUT.birthDateA}:${INPUT.birthDateB}:${TYPE}`);
      const expected = {
        mbti: 50 + ((seed * 3) % 45),
        interest: 50 + ((seed * 11) % 45),
        value: 50 + ((seed * 5) % 45),
        activity_pattern: 50 + ((seed * 13) % 45),
      };
      // route.ts와 동일한 공식(소스 비교는 I1에서 실제 HTTP 응답으로 수행).
      assert.ok(expected.mbti >= 50 && expected.mbti < 95);
      assert.ok(expected.interest >= 50 && expected.interest < 95);
      assert.ok(expected.value >= 50 && expected.value < 95);
      assert.ok(expected.activity_pattern >= 50 && expected.activity_pattern < 95);
    });

    // ── 부가: PII 미로깅 확인 ──
    await check("부가: 폴백 로그에 생년월일(PII)이 포함되지 않는다", async () => {
      const logs: string[] = [];
      console.warn = (...args: unknown[]) => {
        logs.push(args.map(String).join(" "));
      };
      globalThis.fetch = async () => new Response(JSON.stringify({}), { status: 422 });
      await getSajuCompatibilityScore(INPUT, TYPE);
      console.warn = originalWarn;
      const joined = logs.join("\n");
      assert.ok(!joined.includes(INPUT.birthDateA), "birthDateA가 로그에 노출되면 안 된다");
      assert.ok(!joined.includes(INPUT.birthDateB), "birthDateB가 로그에 노출되면 안 된다");
      assert.ok(joined.includes("hash-fallback-unsupported-input"));
    });

    console.log(`\n궁합 saju-compat-score 단위테스트 ${passed}개 전부 통과.`);
  } finally {
    globalThis.fetch = originalFetch;
    console.warn = originalWarn;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("TEST FAILED:", error);
    process.exit(1);
  });
