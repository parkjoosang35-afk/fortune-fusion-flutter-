// [신통방통 오늘·주간·월간 운세 — 2026-11 디자인 지시서 §5] KST(Asia/Seoul,
// UTC+9) 기준 period_key 계산. 서버가 계산하고 클라이언트 값은 절대 신뢰하지
// 않는다(README §5 "period_key는 서버가 KST 기준으로 계산한다").
//
// 규칙(README §5):
//  - today: `YYYY-MM-DD` (00:00~23:59 KST, 다음날 00:00에 새 기간)
//  - week : 월요일의 `YYYY-MM-DD` (월 00:00~일 23:59 KST, 다음주 월요일에 새 기간)
//  - month: `YYYY-MM` (1일~말일 KST, 다음달 1일 00:00에 새 기간)
//
// [설계 원천] design_files/fortune-period.js의 Period.monday/sunday/key를
// 참고하되(README §4 "각 화면은 디자인 참고용 — 서버 로직은 TypeScript로
// 새로 작성"), 날짜 연산은 UTC 타임스탬프에 KST 오프셋을 직접 가감하는
// 방식으로 다시 작성한다(런타임 타임존 설정에 의존하지 않기 위함 — 서버가
// 어느 타임존에서 돌든 항상 KST 기준 결과가 나와야 한다).

export type FortuneKind = "today" | "week" | "month";

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 임의의 Date(UTC 기준 instant)를 "KST로 본 달력 날짜"로 변환한 Date 객체를
 * 반환한다. 반환값의 getUTC*() 메서드를 쓰면 KST 기준 연/월/일/요일을 얻을
 * 수 있다(실제 타임존 변환이 아니라, KST 벽시계 값을 UTC 필드에 그대로
 * 담아두는 트릭 — 이후 모든 날짜 산술은 이 "KST-as-UTC" 표현으로 수행한다). */
function toKstFields(date: Date): Date {
  return new Date(date.getTime() + KST_OFFSET_MS);
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function ymd(kst: Date): string {
  return `${kst.getUTCFullYear()}-${pad2(kst.getUTCMonth() + 1)}-${pad2(kst.getUTCDate())}`;
}

/** KST 기준 "오늘" 자정(00:00 KST)에 해당하는 실제 UTC Date를 반환한다. */
export function kstStartOfToday(now: Date = new Date()): Date {
  const k = toKstFields(now);
  const kstMidnightAsUtcFields = Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), k.getUTCDate());
  return new Date(kstMidnightAsUtcFields - KST_OFFSET_MS);
}

/** KST 기준 이번 주 월요일 00:00(KST)에 해당하는 실제 UTC Date를 반환한다. */
export function kstStartOfWeek(now: Date = new Date()): Date {
  const k = toKstFields(now);
  const dow = k.getUTCDay(); // 0=일 ... 1=월 ... 6=토
  const daysSinceMonday = dow === 0 ? 6 : dow - 1;
  const mondayAsUtcFields = Date.UTC(
    k.getUTCFullYear(),
    k.getUTCMonth(),
    k.getUTCDate() - daysSinceMonday
  );
  return new Date(mondayAsUtcFields - KST_OFFSET_MS);
}

/** KST 기준 이번 달 1일 00:00(KST)에 해당하는 실제 UTC Date를 반환한다. */
export function kstStartOfMonth(now: Date = new Date()): Date {
  const k = toKstFields(now);
  const firstAsUtcFields = Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), 1);
  return new Date(firstAsUtcFields - KST_OFFSET_MS);
}

export interface PeriodInfo {
  kind: FortuneKind;
  /** DB 저장/조회용 키. today=YYYY-MM-DD, week=월요일 YYYY-MM-DD, month=YYYY-MM */
  periodKey: string;
  /** 화면 표시용 라벨(mono, README 공통 레이아웃 스펙의 "TODAY/THIS WEEK/THIS MONTH" 자리) */
  label: string;
  /** 큰 타이틀 — 예: "11월 4일 화요일", "11월 첫째 주", "2026년 11월" */
  main: string;
  /** 보조 설명 — 예: "11월 4일(월) ~ 11월 10일(일)" */
  sub: string;
  /** 이 기간 결과가 유지되는 종료 시각(KST, 다음 기간 시작 직전)의 ISO 문자열 */
  until: string;
  /** 이 period_key에 해당하는 KST 시작일(월간/주간 어댑터가 대표일 선정에 사용) */
  startDate: Date;
  endDate: Date;
}

const WEEKDAY_KR = ["일", "월", "화", "수", "목", "금", "토"];

export function computePeriod(kind: FortuneKind, now: Date = new Date()): PeriodInfo {
  if (kind === "today") {
    const start = kstStartOfToday(now);
    const k = toKstFields(start);
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    const weekday = WEEKDAY_KR[toKstFields(start).getUTCDay()];
    return {
      kind,
      periodKey: ymd(k),
      label: "TODAY",
      main: `${k.getUTCMonth() + 1}월 ${k.getUTCDate()}일 ${weekday}요일`,
      sub: "오늘 자정까지 같은 풀이가 유지돼요",
      until: new Date(end.getTime() - 1).toISOString(),
      startDate: start,
      endDate: end,
    };
  }

  if (kind === "week") {
    const start = kstStartOfWeek(now);
    const end = new Date(start.getTime() + 7 * 24 * 60 * 60 * 1000);
    const k = toKstFields(start);
    const endK = toKstFields(new Date(end.getTime() - 24 * 60 * 60 * 1000));
    return {
      kind,
      periodKey: ymd(k),
      label: "THIS WEEK",
      main: `${k.getUTCMonth() + 1}월 ${weekOfMonthLabel(k)}`,
      sub: `${k.getUTCMonth() + 1}월 ${k.getUTCDate()}일(월) ~ ${endK.getUTCMonth() + 1}월 ${endK.getUTCDate()}일(일)`,
      until: new Date(end.getTime() - 1).toISOString(),
      startDate: start,
      endDate: end,
    };
  }

  // month
  const start = kstStartOfMonth(now);
  const k = toKstFields(start);
  const nextMonthStart = new Date(Date.UTC(k.getUTCFullYear(), k.getUTCMonth() + 1, 1) - KST_OFFSET_MS);
  return {
    kind,
    periodKey: `${k.getUTCFullYear()}-${pad2(k.getUTCMonth() + 1)}`,
    label: "THIS MONTH",
    main: `${k.getUTCFullYear()}년 ${k.getUTCMonth() + 1}월`,
    sub: "이번 달이 끝날 때까지 같은 풀이가 유지돼요",
    until: new Date(nextMonthStart.getTime() - 1).toISOString(),
    startDate: start,
    endDate: nextMonthStart,
  };
}

/** 월 중 몇 째 주인지 "첫째 주/둘째 주.../다섯째 주" 형태로 표기(월요일 기준). */
function weekOfMonthLabel(mondayKst: Date): string {
  const dateOfMonth = mondayKst.getUTCDate();
  const weekIndex = Math.ceil(dateOfMonth / 7); // 대략치 — 월요일 기준 n번째 주
  const names = ["첫째 주", "둘째 주", "셋째 주", "넷째 주", "다섯째 주"];
  return names[Math.min(weekIndex - 1, names.length - 1)];
}

/** 주간운세 어댑터가 "초반/중반/후반" 대표일로 쓸 3개의 KST 날짜(월/수/금 또는
 * 초반=월요일, 중반=목요일, 후반=일요일)를 반환한다. README §3 "일별 운세를
 * 지나치게 나열하지 않고 한 주의 흐름을 중심으로 해석" — 요일별 전부가 아니라
 * 대표 3일만 뽑아 흐름을 구성한다. */
export function weekRepresentativeDates(weekStartKst: Date): { early: Date; mid: Date; late: Date } {
  const early = weekStartKst; // 월요일
  const mid = new Date(weekStartKst.getTime() + 3 * 24 * 60 * 60 * 1000); // 목요일
  const late = new Date(weekStartKst.getTime() + 6 * 24 * 60 * 60 * 1000); // 일요일
  return { early, mid, late };
}

/** 월간운세 어댑터가 "초순/중순/하순" 대표일로 쓸 3개의 KST 날짜(5일/15일/25일). */
export function monthRepresentativeDates(monthStartKst: Date): { early: Date; mid: Date; late: Date } {
  const k = toKstFields(monthStartKst);
  const mk = (day: number) =>
    new Date(Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), day) - KST_OFFSET_MS);
  return { early: mk(5), mid: mk(15), late: mk(25) };
}

/** 어댑터에서 saju_engine에 보낼 "KST 기준 연/월/일" 필드를 뽑아낸다. */
export function kstYmd(date: Date): { year: number; month: number; day: number } {
  const k = toKstFields(date);
  return { year: k.getUTCFullYear(), month: k.getUTCMonth() + 1, day: k.getUTCDate() };
}
