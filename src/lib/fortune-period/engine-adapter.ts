// [신통방통 오늘의 운세 — 2026-11 AI 무당체 전환] saju_engine 어댑터.
//
// [배경 — 2026-11 사용자 피드백] 기존 오늘/주간/월간 3종 운세는
// daily_fortune_rules.json/monthly_fortune_rules.json의 "십신 10종 고정
// 템플릿"만 재배치하는 구조라 반복감이 심하다는 피드백을 받았다. 이에 따라:
//   1. 주간운세·월간운세는 완전히 삭제한다(엔진에 전용 계산 로직이 없어
//      3일치 일진을 짜깁기하던 임시 어댑터였다 — 제거).
//   2. 오늘의 운세는 saju_engine의 새 AI 해석 엔드포인트
//      `POST /fortune/today/mudang`(saju_engine_deploy 저장소, ai_layer/
//      mudang_service.py)를 호출하도록 전환한다. 이 엔드포인트는 사주
//      전체 FACT + 오늘 일진 FACT를 LLM에 주입해 "명확론·권위적·하대체"
//      (반말, 단정적 어투)의 하나의 이야기로 풀어준다. LLM 미설정/오류/QA
//      미통과 시 엔진 자체에서 기존 daily_fortune_rules.json 템플릿으로
//      안전하게 폴백한다(이 어댑터는 그 폴백 로직을 신경 쓸 필요 없음 —
//      엔진이 항상 200으로 일관된 스키마를 반환).
//
// [절대 원칙]
//  - saju_engine 엔진 파일(daily_fortune.py 등)은 이 변경과 무관하게
//    단 한 글자도 수정되지 않는다 — 신규 병행 엔드포인트만 호출한다.
//  - 이 어댑터 자체는 외부 AI를 직접 호출하지 않는다(엔진이 호출을
//    대행하고 결과만 돌려준다) — 기존 "어댑터 레이어는 HTTP 클라이언트일
//    뿐" 원칙 유지.
//
// [POST /fortune/today/mudang 응답 구조]
//   { source: "llm" | "rule_fallback", headline, text, evidence_used?,
//     qa_passed, day_gan_zhi, lucky_color: string[], lucky_direction: string[],
//     lucky_number: number[], engine }
//   오류: 402 { detail: { code: "FREE_PASS_REQUIRED", ... } }
//        422 { detail: [{ type, loc, msg, input, ctx? }, ...] } (pydantic)

import {
  freePassToken,
  DEFAULT_BASE_URL,
  type SajuBirthInput,
} from "@/lib/saju-renewal/saju-engine-client";
import { kstYmd } from "./period-key";

// ── 엔진 응답 타입 (실측 구조 그대로) ───────────────────────────

export interface MudangTodayEngineResponse {
  source: "llm" | "rule_fallback" | "cache";
  headline: string;
  text: string;
  evidence_used?: string[];
  qa_passed: boolean | null;
  fallback_reason?: string;
  day_gan_zhi?: string;
  lucky_color?: string[];
  lucky_direction?: string[];
  lucky_number?: number[];
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

// [AI 호출 포함 — 넉넉한 타임아웃] 기존 결정론적 룰 조합(15s)과 달리 실제
// LLM 왕복이 포함되므로(엔진 쪽 llm_adapter.py 타임아웃 60s와 정합되도록)
// 어댑터 타임아웃을 65s로 넉넉히 둔다.
const DEFAULT_TIMEOUT_MS = 65_000;

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
 * 변환한다. year/month/day는 매번 "오늘(KST)"로 덮어써서 호출하므로 이 함수는
 * hour/minute/gender/is_lunar만 담당한다. */
export interface ProfileBirthInfo {
  birthDate: string; // "YYYY-MM-DD" — 연/월/일은 호출 시점에 오늘 날짜로 교체되므로 여기선 참고만
  birthTime: string | null; // "HH:mm"
  isLunar: boolean;
  /** 음력 윤달 여부(isLunar=true일 때만 의미 있음) — 음력 핵심 결함 수정 지시에 따라 추가. */
  isLeapMonth: boolean;
  gender: string | null;
}

function toEngineBaseInput(profile: ProfileBirthInfo): Pick<
  SajuBirthInput,
  "hour" | "minute" | "gender" | "isLunar" | "isLeapMonth"
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
  return { hour, minute, gender, isLunar: profile.isLunar, isLeapMonth: profile.isLeapMonth };
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
    is_leap_month: base.isLeapMonth,
  };
}

/** 오늘의 운세 결과 형태(FortunePeriodResult.payload로 JSON 직렬화되어
 * 저장되고, Flutter가 그대로 소비한다). 기존 seal/title/summary/flow/
 * fields/caution 구조(섹션별 중복 노출 문제의 원인)를 전부 걷어내고,
 * "짧은 헤드라인 + 하나의 이야기 본문"으로 단순화했다. */
export interface FortunePayload {
  headline: string; // 4~12자 강렬한 한 줄 제목
  text: string; // 무당체 본문(두세 문단, 섹션 구분 없음)
  dayGanZhi: string | null; // 오늘 일진 간지(참고 표시용)
  luckyColor: string[];
  luckyDirection: string[];
  luckyNumber: number[];
  source: "llm" | "rule_fallback" | "cache";
}

export async function fetchTodayFortune(
  profile: ProfileBirthInfo,
  todayKst: { year: number; month: number; day: number }
): Promise<FortunePayload> {
  const body = engineBodyFor(profile, todayKst);
  const r = await postToEngine<MudangTodayEngineResponse>("/fortune/today/mudang", body);
  return {
    headline: r.headline || "오늘의 운세",
    text: r.text || "",
    dayGanZhi: r.day_gan_zhi ?? null,
    luckyColor: r.lucky_color ?? [],
    luckyDirection: r.lucky_direction ?? [],
    luckyNumber: r.lucky_number ?? [],
    source: r.source === "llm" || r.source === "cache" ? r.source : "rule_fallback",
  };
}

/** 기간 종류에 맞는 엔진 호출 + 매핑을 한 번에 수행하는 진입점.
 * [주간/월간 삭제] 더 이상 kind 분기가 필요 없다 — 오늘의 운세 전용. */
export async function fetchFortuneFromEngine(
  profile: ProfileBirthInfo,
  period: { startDate: Date }
): Promise<FortunePayload> {
  return fetchTodayFortune(profile, kstYmd(period.startDate));
}
