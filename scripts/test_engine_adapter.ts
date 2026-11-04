import { fetchTodayFortune, fetchMonthFortune, fetchWeekFortune, fetchFortuneFromEngine } from "../src/lib/fortune-period/engine-adapter";
import { kstStartOfWeek, kstStartOfMonth, kstYmd } from "../src/lib/fortune-period/period-key";

const SAMPLE_PROFILE = {
  birthDate: "1990-05-15",
  birthTime: "14:30",
  isLunar: false,
  gender: "male",
};

function assertTrue(cond: boolean, label: string) {
  if (!cond) {
    console.error(`❌ FAIL: ${label}`);
    process.exitCode = 1;
  } else {
    console.log(`✅ PASS: ${label}`);
  }
}

async function main() {
  const fixedNow = new Date("2026-11-04T15:30:00.000Z"); // KST 2026-11-05 00:30

  // 1) today
  const today = await fetchTodayFortune(SAMPLE_PROFILE, kstYmd(fixedNow));
  console.log("today payload:", JSON.stringify(today, null, 2));
  assertTrue(today.kind === "today", "today.kind === 'today'");
  assertTrue(typeof today.summary === "string" && today.summary.length > 0, "today.summary 비어있지 않음");
  assertTrue(today.caution === null, "today.caution === null (README: today는 caution 없음)");
  assertTrue(today.fields.length === 3, "today.fields 3개(재물/애정/사업)");
  assertTrue(["吉", "平", "新"].includes(today.seal), "today.seal이 吉/平/新 중 하나");

  // 2) 결정성 — 같은 입력 2번 호출 -> 같은 결과
  const today2 = await fetchTodayFortune(SAMPLE_PROFILE, kstYmd(fixedNow));
  assertTrue(JSON.stringify(today) === JSON.stringify(today2), "today 결정적 생성: 동일 입력 -> 동일 결과");

  // 3) month
  const monthStart = kstStartOfMonth(fixedNow);
  const month = await fetchMonthFortune(SAMPLE_PROFILE, kstYmd(monthStart));
  console.log("month payload:", JSON.stringify(month, null, 2));
  assertTrue(month.kind === "month", "month.kind === 'month'");
  assertTrue(Array.isArray(month.caution) && month.caution.length > 0, "month.caution 배열(README: week/month만 caution 있음)");
  assertTrue(month.flow.length === 3 && month.flow[0].t === "초순" && month.flow[1].t === "중순" && month.flow[2].t === "하순", "month.flow가 초순/중순/하순");

  // 4) week (3대표일 조합)
  const weekStart = kstStartOfWeek(fixedNow);
  const week = await fetchWeekFortune(SAMPLE_PROFILE, weekStart);
  console.log("week payload:", JSON.stringify(week, null, 2));
  assertTrue(week.kind === "week", "week.kind === 'week'");
  assertTrue(week.flow.length === 3 && week.flow[0].t === "초반" && week.flow[1].t === "중반" && week.flow[2].t === "후반", "week.flow가 초반/중반/후반");
  assertTrue(!week.summary.match(/\d{1,2}월 \d{1,2}일.*\d{1,2}월 \d{1,2}일.*\d{1,2}월 \d{1,2}일/), "week.summary가 일별 나열식이 아님(단순 날짜 3연속 패턴 없음)");

  // 5) week 결정성
  const week2 = await fetchWeekFortune(SAMPLE_PROFILE, weekStart);
  assertTrue(JSON.stringify(week) === JSON.stringify(week2), "week 결정적 생성: 동일 입력 -> 동일 결과");

  // 6) fetchFortuneFromEngine 통합 진입점
  const viaEntry = await fetchFortuneFromEngine("today", SAMPLE_PROFILE, { startDate: fixedNow });
  assertTrue(JSON.stringify(viaEntry) === JSON.stringify(today), "fetchFortuneFromEngine('today') === fetchTodayFortune() 직접호출과 동일");

  // 7) 음력 입력도 엔진이 받아주는지(에러 없이)
  const lunarProfile = { ...SAMPLE_PROFILE, isLunar: true, birthDate: "1990-04-21" };
  const lunarToday = await fetchTodayFortune(lunarProfile, kstYmd(fixedNow));
  assertTrue(typeof lunarToday.summary === "string" && lunarToday.summary.length > 0, "음력(isLunar=true) 입력도 정상 처리");

  // 8) 오류 처리 — 잘못된 토큰으로 강제 실패 유도(FREE_PASS 오류 타입 확인)
  const originalEnv = process.env.SAJU_ENGINE_FREE_PASS_TOKEN;
  process.env.SAJU_ENGINE_FREE_PASS_TOKEN = "WRONG-TOKEN-FOR-TEST";
  try {
    await fetchTodayFortune(SAMPLE_PROFILE, kstYmd(fixedNow));
    assertTrue(false, "잘못된 토큰이면 예외가 발생해야 함(실패)");
  } catch (e: unknown) {
    const err = e as { kind?: string; statusCode?: number };
    assertTrue(err.kind === "FREE_PASS" && err.statusCode === 402, `잘못된 토큰 -> FortuneEngineError(kind=FREE_PASS, status=402), 실제: kind=${err.kind}, status=${err.statusCode}`);
  } finally {
    if (originalEnv) process.env.SAJU_ENGINE_FREE_PASS_TOKEN = originalEnv;
    else delete process.env.SAJU_ENGINE_FREE_PASS_TOKEN;
  }

  console.log(process.exitCode === 1 ? "\n=== 일부 테스트 실패 ===" : "\n=== 전체 테스트 통과 ===");
}

main().catch((e) => {
  console.error("테스트 실행 중 예외:", e);
  process.exitCode = 1;
});
