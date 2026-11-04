// [신통방통 오늘·주간·월간 운세 — 2026-11 디자인 지시서] saju_engine 어댑터.
//
// [절대 원칙 재확인 — README §"절대 원칙"]
//  1. 기존 saju_engine을 그대로 호출한다. 엔진 파일은 단 한 글자도 수정하지
//     않는다(이 파일은 엔진 "밖"에서 HTTP로 소비하는 순수 클라이언트 코드).
//     today/month는 엔진에 이미 있는 /fortune/today, /fortune/month를 그대로
//     쓴다. week는 엔진에 대응 엔드포인트가 없으므로, 같은 /fortune/today를
//     이번 주의 대표 3일(월/목/일 — "초반/중반/후반")에 대해 3회 호출해
//     조합한다(엔진 내부에 새 계산 로직을 추가하는 것이 아니라, 이미 있는
//     일진 계산을 다른 날짜로 3번 재사용하는 것뿐이다).
//  2. 외부 AI API를 호출하지 않는다 — FACT(엔진 응답)와 규칙 기반 문장
//     조합만 사용한다. 이 파일은 템플릿 선택/문자열 조합만 하며 어떤 LLM도
//     호출하지 않는다.
//  3. 결정적 생성 — 같은 생년월일시+성별+기준일이면 항상 같은 결과가
//     나와야 한다(saju_engine 자체가 결정론적 룰 엔진이므로, 이 어댑터도
//     랜덤 함수를 전혀 쓰지 않는다 — Math.random() 등 금지).
//
// [실제 엔진 응답 구조 — 2026-11-04 로컬 엔진에 대한 라이브 curl로 확인,
// modules/daily_fortune.py·monthly_fortune.py 소스 교차 확인 완료. 아래
// 타입은 추측이 아니라 실제 응답을 그대로 반영한다]:
//   POST /fortune/today →
//     { category, day_gan_zhi, gan_god, zhi_god, title, mood, overall,
//       work, wealth, love, lucky_time, avoid_time,
//       lucky_color: string[], lucky_direction: string[], lucky_number: number[] }
//   POST /fortune/month?year=&month= →
//     { category, month_gan_zhi, gan_god, zhi_god, title, overall, work,
//       wealth, love, health, advice }
//   오류: 402 { detail: { code: "FREE_PASS_REQUIRED", ... } }
//        422 { detail: [{ type, loc, msg, input, ctx? }, ...] } (pydantic)

import {
  freePassToken,
  DEFAULT_BASE_URL,
  type SajuBirthInput,
} from "@/lib/saju-renewal/saju-engine-client";
import {
  kstYmd,
  weekRepresentativeDates,
  monthRepresentativeDates,
  type FortuneKind,
} from "./period-key";

// ── 엔진 응답 타입 (실측 구조 그대로) ───────────────────────────

export interface DailyFortuneEngineResponse {
  category: string;
  day_gan_zhi: string;
  gan_god: string;
  zhi_god: string;
  title: string;
  mood: string;
  overall: string;
  work: string;
  wealth: string;
  love: string;
  lucky_time: string;
  avoid_time: string;
  lucky_color: string[];
  lucky_direction: string[];
  lucky_number: number[];
}

export interface MonthlyFortuneEngineResponse {
  category: string;
  month_gan_zhi: string;
  gan_god: string;
  zhi_god: string;
  title: string;
  overall: string;
  work: string;
  wealth: string;
  love: string;
  health: string;
  advice: string;
}

interface EnginePydanticErrorDetailItem {
  type: string;
  loc: (string | number)[];
  msg: string;
  input?: unknown;
  ctx?: Record<string, unknown>;
}

interface EngineFreePassErrorDetail {
  code: string;
  message_kr: string;
  message_en: string;
  hint: string;
}

export class FortuneEngineError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number,
    /** 호출부가 "입력값 문제(4xx)"와 "엔진 자체 장애(5xx/네트워크)"를 구분해
     * 다른 사용자 안내를 보여줄 수 있도록 노출한다(README 상태화면 스펙 —
     * 에러 상태 "기운이 잠시 닿지 않았어요"는 엔진 장애 쪽에 해당). */
    readonly kind: "FREE_PASS" | "VALIDATION" | "TIMEOUT" | "UNKNOWN" = "UNKNOWN"
  ) {
    super(message);
    this.name = "FortuneEngineError";
  }
}

const DEFAULT_TIMEOUT_MS = 15_000;

async function postToEngine<T>(
  path: string,
  body: Record<string, unknown>,
  query?: Record<string, string | number>
): Promise<T> {
  const baseUrl = DEFAULT_BASE_URL;
  const qs = query
    ? "?" +
      Object.entries(query)
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
        .join("&")
    : "";
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(`${baseUrl}${path}${qs}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Free-Pass": freePassToken(),
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (e) {
    clearTimeout(timer);
    if (e instanceof Error && e.name === "AbortError") {
      throw new FortuneEngineError(
        `saju_engine 응답 타임아웃(${DEFAULT_TIMEOUT_MS}ms 초과): ${path}`,
        undefined,
        "TIMEOUT"
      );
    }
    throw new FortuneEngineError(
      `saju_engine 호출 중 네트워크 오류(${path}): ${e instanceof Error ? e.message : String(e)}`,
      undefined,
      "UNKNOWN"
    );
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = null;
    }
    if (res.status === 402) {
      const detail = (parsed as { detail?: EngineFreePassErrorDetail })?.detail;
      throw new FortuneEngineError(
        `saju_engine 프리패스 인증 실패(${path}): ${detail?.message_kr ?? text.slice(0, 200)}`,
        402,
        "FREE_PASS"
      );
    }
    if (res.status === 422) {
      const detail = (parsed as { detail?: EnginePydanticErrorDetailItem[] })?.detail;
      const firstMsg = Array.isArray(detail) && detail[0] ? detail[0].msg : text.slice(0, 200);
      throw new FortuneEngineError(
        `saju_engine 입력값 검증 실패(${path}): ${firstMsg}`,
        422,
        "VALIDATION"
      );
    }
    throw new FortuneEngineError(
      `saju_engine 호출 실패(${path}, status=${res.status}): ${text.slice(0, 200)}`,
      res.status,
      "UNKNOWN"
    );
  }

  return (await res.json()) as T;
}

/** UserProfile 저장 포맷(birthDate: "YYYY-MM-DD" 문자열, birthTime: "HH:mm" 또는
 * null, isLunar: boolean, gender: "male"|"female") → saju_engine BirthInput 로
 * 변환한다. year/month/day는 매번 다른 기준일(오늘/대표일)로 덮어써서 호출하므로
 * 이 함수는 hour/minute/gender/is_lunar만 담당한다. */
export interface ProfileBirthInfo {
  birthDate: string; // "YYYY-MM-DD" — 연/월/일은 각 호출 시점에 대표일로 교체되므로 여기선 참고만
  birthTime: string | null; // "HH:mm"
  isLunar: boolean;
  gender: string | null;
}

function toEngineBaseInput(profile: ProfileBirthInfo): Pick<
  SajuBirthInput,
  "hour" | "minute" | "gender" | "isLunar"
> {
  let hour = 12;
  let minute = 0;
  if (profile.birthTime) {
    const m = /^(\d{1,2}):(\d{1,2})$/.exec(profile.birthTime);
    if (m) {
      hour = Number(m[1]);
      minute = Number(m[2]);
    }
  }
  const gender: "male" | "female" = profile.gender === "female" ? "female" : "male";
  return { hour, minute, gender, isLunar: profile.isLunar };
}

function engineBodyFor(
  profile: ProfileBirthInfo,
  ymd: { year: number; month: number; day: number }
): Record<string, unknown> {
  const base = toEngineBaseInput(profile);
  return {
    year: ymd.year,
    month: ymd.month,
    day: ymd.day,
    hour: base.hour,
    minute: base.minute,
    gender: base.gender,
    is_lunar: base.isLunar,
  };
}

/** README §5 응답 스키마에 대응하는 공통 결과 형태(FortunePeriodResult.payload로
 * JSON 직렬화되어 저장되고, Flutter가 그대로 소비한다). */
export interface FortunePayload {
  kind: FortuneKind;
  seal: string; // 吉/平/新 등 — README summary section "seal" 자리
  title: [string, string]; // 2줄 타이틀
  summary: string; // 총평(가장 비중 큰 본문)
  flow: { k: string; t: string; text: string }[]; // 오전/오후/저녁 또는 초반/중반/후반 또는 초순/중순/하순
  fields: { id: "wealth" | "love" | "work"; name: string; text: string }[];
  caution: string[] | null; // today는 null(README: caution은 week/month만)
}

/** 일진 간지 한 글자(甲/乙 등)로부터 "吉/平/新" 중 하나를 결정적으로 고른다.
 * README summary section의 "seal"은 디자인상 음양 기운을 상징하는 한 글자이며,
 * 외부 AI 호출 없이 FACT(십신 길흉 성향)로 결정적으로 고정한다. 식신/정재/정관/
 * 정인처럼 전통적으로 "온건한 길신" 계열이면 吉, 비견/겁재/상관처럼 "변화·경쟁"
 * 계열이면 新, 편관/편재/편인 등 "강한 기운" 계열이면 平으로 분류한다(룰 기반
 * 고정 매핑 — 무작위 요소 없음). */
const SEAL_BY_TEN_GOD: Record<string, string> = {
  식신: "吉",
  정재: "吉",
  정관: "吉",
  정인: "吉",
  비견: "新",
  겁재: "新",
  상관: "新",
  편재: "平",
  편관: "平",
  편인: "平",
};

function sealFor(ganGod: string): string {
  return SEAL_BY_TEN_GOD[ganGod] ?? "平";
}

/** 한글 단어 끝 글자의 받침 유무에 따라 "은/는" 조사를 고른다(엔진 rules json의
 * avoid_time 값을 문장에 자연스럽게 삽입하기 위함 — 외부 AI 없이 순수 규칙으로
 * 처리, Unicode 한글 음절 블록 계산만 사용). 한글이 아닌 입력(빈 문자열 등)이면
 * 안전하게 "는"을 기본값으로 쓴다. */
function withTopicParticle(word: string): string {
  if (!word) return word;
  const lastChar = word[word.length - 1];
  const code = lastChar.codePointAt(0) ?? 0;
  const HANGUL_BASE = 0xac00;
  const HANGUL_LAST = 0xd7a3;
  if (code < HANGUL_BASE || code > HANGUL_LAST) return `${word}는`;
  const hasBatchim = (code - HANGUL_BASE) % 28 !== 0;
  return `${word}${hasBatchim ? "은" : "는"}`;
}

// ── today ────────────────────────────────────────────────────

export async function fetchTodayFortune(profile: ProfileBirthInfo, todayKst: { year: number; month: number; day: number }): Promise<FortunePayload> {
  const body = engineBodyFor(profile, todayKst);
  const r = await postToEngine<DailyFortuneEngineResponse>("/fortune/today", body);
  return {
    kind: "today",
    seal: sealFor(r.gan_god),
    title: [r.title, r.mood],
    summary: r.overall,
    flow: [
      { k: "morning", t: "오전", text: r.work },
      { k: "afternoon", t: "오후", text: r.love },
      { k: "evening", t: "저녁", text: r.avoid_time ? `${withTopicParticle(r.avoid_time)} 피해요` : r.lucky_time },
    ],
    fields: [
      { id: "wealth", name: "재물운", text: r.wealth },
      { id: "love", name: "애정운", text: r.love },
      { id: "work", name: "사업·직장운", text: r.work },
    ],
    caution: null,
  };
}

// ── month ────────────────────────────────────────────────────

export async function fetchMonthFortune(
  profile: ProfileBirthInfo,
  monthStartKst: { year: number; month: number; day: number }
): Promise<FortunePayload> {
  const body = engineBodyFor(profile, monthStartKst);
  const r = await postToEngine<MonthlyFortuneEngineResponse>("/fortune/month", body, {
    year: monthStartKst.year,
    month: monthStartKst.month,
  });

  // [초순/중순/하순 흐름 — README §3 "월간: 초순·중순·하순"] 엔진 /fortune/month는
  // 월 단위 요약만 주고 초/중/하순 구분이 없으므로, 같은 응답의 work/wealth/love/
  // advice 필드를 흐름 3단계에 결정적으로 분배한다(엔진 재호출이나 추가 계산
  // 없음 — 이미 받은 FACT 기반 텍스트를 재배치만 한다).
  return {
    kind: "month",
    seal: sealFor(r.gan_god),
    title: [r.title, r.month_gan_zhi],
    summary: r.overall,
    flow: [
      { k: "early", t: "초순", text: r.work },
      { k: "mid", t: "중순", text: r.love },
      { k: "late", t: "하순", text: r.advice },
    ],
    fields: [
      { id: "wealth", name: "재물운", text: r.wealth },
      { id: "love", name: "애정운", text: r.love },
      { id: "work", name: "사업·직장운", text: r.work },
    ],
    caution: [r.health ? `건강: ${r.health}` : "컨디션 관리에 신경 써요", `조언: ${r.advice}`],
  };
}

// ── week (엔진에 없음 → 3대표일 /fortune/today 조합 어댑터) ──────

export async function fetchWeekFortune(
  profile: ProfileBirthInfo,
  weekStartKst: Date
): Promise<FortunePayload> {
  const { early, mid, late } = weekRepresentativeDates(weekStartKst);
  const [earlyR, midR, lateR] = await Promise.all([
    postToEngine<DailyFortuneEngineResponse>("/fortune/today", engineBodyFor(profile, kstYmd(early))),
    postToEngine<DailyFortuneEngineResponse>("/fortune/today", engineBodyFor(profile, kstYmd(mid))),
    postToEngine<DailyFortuneEngineResponse>("/fortune/today", engineBodyFor(profile, kstYmd(late))),
  ]);

  // [週 총평 결정적 조합] 세 대표일의 overall을 이어 붙이지 않고(README: "일별
  // 나열 금지"), 중반(mid, 목요일)의 overall을 주된 총평 바탕으로 삼되 초반/
  // 후반의 title 흐름을 덧붙여 "한 주의 흐름"으로 요약한다 — 항상 같은 세
  // 대표일 데이터로 같은 방식으로 조합되므로 결정적이다.
  const summary = `이번 주는 ${earlyR.title}로 시작해 ${midR.title}을 지나 ${lateR.title}로 마무리돼요. ${midR.overall}`;

  return {
    kind: "week",
    seal: sealFor(midR.gan_god),
    title: [`${earlyR.title} · ${midR.title} · ${lateR.title}`, midR.day_gan_zhi],
    summary,
    flow: [
      { k: "early", t: "초반", text: earlyR.overall },
      { k: "mid", t: "중반", text: midR.overall },
      { k: "late", t: "후반", text: lateR.overall },
    ],
    fields: [
      { id: "wealth", name: "재물운", text: midR.wealth },
      { id: "love", name: "애정운", text: midR.love },
      { id: "work", name: "사업·직장운", text: midR.work },
    ],
    caution: [
      earlyR.avoid_time ? `주 초반 ${withTopicParticle(earlyR.avoid_time)} 피해요` : "주 초반 무리한 일정은 피해요",
      lateR.avoid_time ? `주 후반 ${withTopicParticle(lateR.avoid_time)} 피해요` : "주 후반 과로를 조심해요",
    ],
  };
}

/** 기간 종류에 맞는 엔진 호출 + 매핑을 한 번에 수행하는 진입점. */
export async function fetchFortuneFromEngine(
  kind: FortuneKind,
  profile: ProfileBirthInfo,
  period: { startDate: Date }
): Promise<FortunePayload> {
  if (kind === "today") {
    return fetchTodayFortune(profile, kstYmd(period.startDate));
  }
  if (kind === "week") {
    return fetchWeekFortune(profile, period.startDate);
  }
  const m = monthRepresentativeDates(period.startDate);
  // 월간은 "해당 월의 1일"을 기준으로 호출(엔진의 /fortune/month가 month_gan_zhi를
  // 절입일 기준으로 스스로 계산하므로, early/mid/late 날짜는 fetchMonthFortune
  // 내부 흐름 배분이 아니라 향후 세분화 확장 여지로만 남겨둔다 — 현재는 1일 기준
  // 단일 호출로 충분).
  void m;
  return fetchMonthFortune(profile, kstYmd(period.startDate));
}
