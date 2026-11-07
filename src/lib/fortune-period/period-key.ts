// [신통방통 오늘의 운세 — 2026-11 AI 무당체 전환] KST(Asia/Seoul, UTC+9)
// 기준 period_key 계산. 서버가 계산하고 클라이언트 값은 절대 신뢰하지 않는다.
//
// [주간/월간 삭제 — 2026-11 사용자 피드백] 기존에는 today/week/month 3종을
// 지원했으나, 엔진에 전용 주간/월간 계산 로직이 없어 일진 짜깁기에 불과하다는
// 피드백에 따라 주간·월간운세 자체를 삭제했다. 이 파일은 이제 today만 다룬다
// (week/month 관련 함수 kstStartOfWeek/kstStartOfMonth/weekRepresentativeDates/
// monthRepresentativeDates는 더 이상 쓰이지 않으므로 함께 제거했다).
//
// 규칙: today: `YYYY-MM-DD` (00:00~23:59 KST, 다음날 00:00에 새 기간)
//
// [설계 원천] 날짜 연산은 UTC 타임스탬프에 KST 오프셋을 직접 가감하는 방식으로
// 작성한다(런타임 타임존 설정에 의존하지 않기 위함 — 서버가 어느 타임존에서
// 돌든 항상 KST 기준 결과가 나와야 한다).

export type FortuneKind = "today";

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
  void kind; // today만 남음 — 시그니처는 호출부 호환을 위해 유지
  const start = kstStartOfToday(now);
  const k = toKstFields(start);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  const weekday = WEEKDAY_KR[toKstFields(start).getUTCDay()];
  return {
    kind: "today",
    periodKey: ymd(k),
    label: "TODAY",
    main: `${k.getUTCMonth() + 1}월 ${k.getUTCDate()}일 ${weekday}요일`,
    sub: "오늘 자정까지 같은 풀이가 유지돼요",
    until: new Date(end.getTime() - 1).toISOString(),
    startDate: start,
    endDate: end,
  };
}

/** 어댑터에서 saju_engine에 보낼 "KST 기준 연/월/일" 필드를 뽑아낸다. */
export function kstYmd(date: Date): { year: number; month: number; day: number } {
  const k = toKstFields(date);
  return { year: k.getUTCFullYear(), month: k.getUTCMonth() + 1, day: k.getUTCDate() };
}
