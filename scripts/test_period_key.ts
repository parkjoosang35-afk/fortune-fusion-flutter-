import { computePeriod, kstStartOfToday, kstStartOfWeek, kstStartOfMonth, weekRepresentativeDates, monthRepresentativeDates, kstYmd } from "../src/lib/fortune-period/period-key";

function assertEq(actual: unknown, expected: unknown, label: string) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    console.error(`❌ FAIL: ${label}\n  expected: ${e}\n  actual:   ${a}`);
    process.exitCode = 1;
  } else {
    console.log(`✅ PASS: ${label} => ${a}`);
  }
}

// 1) 고정 시각 테스트 — 2026-11-04(수) 15:30 UTC = 2026-11-05(목) 00:30 KST
const t1 = new Date("2026-11-04T15:30:00.000Z"); // KST 2026-11-05 00:30 (목요일 자정 막 지남)
const today1 = computePeriod("today", t1);
assertEq(today1.periodKey, "2026-11-05", "KST 2026-11-05 00:30 -> today periodKey");

// 2) 자정 경계 직전 — UTC 14:59:59 = KST 23:59:59 (전날)
const t2 = new Date("2026-11-04T14:59:59.000Z"); // KST 2026-11-04 23:59:59
const today2 = computePeriod("today", t2);
assertEq(today2.periodKey, "2026-11-04", "KST 2026-11-04 23:59:59 -> today periodKey (자정 직전)");

// 3) week: 2026-11-05(목)이 포함된 주의 월요일 = 2026-11-02
const week1 = computePeriod("week", t1);
assertEq(week1.periodKey, "2026-11-02", "2026-11-05(목) 포함 주 -> 월요일 periodKey");

// 4) 일요일 23:59:59 KST는 여전히 같은 주(그 주의 월요일)
// KST 2026-11-08(일) 23:59:59 = UTC 2026-11-08 14:59:59
const t4 = new Date("2026-11-08T14:59:59.000Z");
const week4 = computePeriod("week", t4);
assertEq(week4.periodKey, "2026-11-02", "주 마지막 순간(일요일 23:59:59 KST)도 같은 주");

// 5) 다음 주 월요일 00:00:00 KST = 새 주
// KST 2026-11-09(월) 00:00:00 = UTC 2026-11-08 15:00:00
const t5 = new Date("2026-11-08T15:00:00.000Z");
const week5 = computePeriod("week", t5);
assertEq(week5.periodKey, "2026-11-09", "다음주 월요일 00:00 KST -> 새 주 시작");

// 6) month
const month1 = computePeriod("month", t1);
assertEq(month1.periodKey, "2026-11", "2026-11-05 -> month periodKey");

// 7) 월 마지막 날 23:59:59 KST -> 같은 달, 다음날 00:00 -> 새 달
// 2026년 11월은 30일까지. KST 2026-11-30 23:59:59 = UTC 2026-11-30 14:59:59
const t7a = new Date("2026-11-30T14:59:59.000Z");
assertEq(computePeriod("month", t7a).periodKey, "2026-11", "11월 말일 23:59:59 KST -> 여전히 11월");
const t7b = new Date("2026-11-30T15:00:00.000Z"); // KST 2026-12-01 00:00:00
assertEq(computePeriod("month", t7b).periodKey, "2026-12", "12월 1일 00:00 KST -> 새 달");

// 8) 연도 경계 — 12/31 -> 1/1
const t8 = new Date("2026-12-31T15:00:00.000Z"); // KST 2027-01-01 00:00
assertEq(computePeriod("today", t8).periodKey, "2027-01-01", "연말 자정 경계(today)");
assertEq(computePeriod("month", t8).periodKey, "2027-01", "연말 자정 경계(month)");
assertEq(computePeriod("week", t8).periodKey <= "2027-01-01", true, "연말 자정 경계(week) 월요일 <= 2027-01-01");

// 9) weekRepresentativeDates: 월/목/일 간격 확인
const weekStart = kstStartOfWeek(t1);
const reps = weekRepresentativeDates(weekStart);
const earlyYmd = kstYmd(reps.early);
const midYmd = kstYmd(reps.mid);
const lateYmd = kstYmd(reps.late);
assertEq(earlyYmd, { year: 2026, month: 11, day: 2 }, "week 대표일 early(월)");
assertEq(midYmd, { year: 2026, month: 11, day: 5 }, "week 대표일 mid(목)");
assertEq(lateYmd, { year: 2026, month: 11, day: 8 }, "week 대표일 late(일)");

// 10) monthRepresentativeDates: 5/15/25일 확인
const monthStart = kstStartOfMonth(t1);
const mreps = monthRepresentativeDates(monthStart);
assertEq(kstYmd(mreps.early), { year: 2026, month: 11, day: 5 }, "month 대표일 early(5일)");
assertEq(kstYmd(mreps.mid), { year: 2026, month: 11, day: 15 }, "month 대표일 mid(15일)");
assertEq(kstYmd(mreps.late), { year: 2026, month: 11, day: 25 }, "month 대표일 late(25일)");

// 11) 결정성 — 같은 입력(same Date instant)에 대해 항상 같은 결과
const repeatA = computePeriod("today", t1);
const repeatB = computePeriod("today", t1);
assertEq(repeatA.periodKey === repeatB.periodKey, true, "결정적 생성: 같은 입력 -> 같은 periodKey");

console.log(process.exitCode === 1 ? "\n=== 일부 테스트 실패 ===" : "\n=== 전체 테스트 통과 ===");
