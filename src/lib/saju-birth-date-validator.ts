// [신통방통 정통사주 생년월일검증·일일재조회·어뷰징방지 최종지시서 §4·§5·§8·§10]
//
// 이 모듈은 "정통사주 엔진 상위 레이어"의 입력 검증 단계(§2 ①)를 구현한다.
// 정통사주 69개 메뉴(레거시, fortune/saju/route.ts 등)와 출생정보 저장 시점
// (auth/profile/route.ts) 양쪽 모두 이 모듈 하나만 호출해야 한다(§15류 "판정
// 기준 불일치 금지" 원칙과 동일하게, 검증 로직을 여러 곳에 복제하지 않는다).
//
// [지시서 §1 최우선 원칙 반영]
//   · 기존 정통사주 계산 엔진(saju_engine, saju-manseryeok-engine.ts 등)의
//     계산 규칙은 전혀 건드리지 않는다 — 이 모듈은 엔진 "이전" 단계에서만 동작.
//   · 미래 생년월일·존재하지 않는 날짜만 차단 대상이다. "같은 생년월일을
//     반복 입력하는 행위"는 이 모듈이 판단할 대상이 아니다(어뷰징 판정은
//     saju-abuse-risk-score.ts에서 별도로, 입력값 자체와는 독립적으로 수행).
//   · 서버 시각(KST) 기준으로만 "오늘"을 판정한다 — 클라이언트가 보낸 시각은
//     절대 신뢰하지 않는다(§4 공통 규칙, §10 "클라이언트 시각 의존 코드 제거").
//   · 현재 연도를 코드에 하드코딩하지 않는다(§10) — 항상 new Date() 기반.
//   · 최소 출생연도는 설정값(SystemSetting)으로 관리한다(§4 "범위 검증").
//
// [검증 순서 — §4 표 그대로] 형식 → 존재 날짜 → 미래 날짜 → 범위 → 태어난 시.
// 최초로 실패한 단계에서 즉시 반환한다(뒤 단계는 실행하지 않음).

import { prisma } from "@/lib/db";
import { Lunar } from "lunar-javascript";

export type BirthDateValidationErrorCode =
  | "INVALID_FORMAT"
  | "DATE_NOT_EXIST"
  | "FUTURE_DATE"
  | "OUT_OF_RANGE"
  | "INVALID_TIME";

export class BirthDateValidationError extends Error {
  code: BirthDateValidationErrorCode;
  constructor(code: BirthDateValidationErrorCode, message: string) {
    super(message);
    this.code = code;
    this.name = "BirthDateValidationError";
  }
}

/** [§4.2 차단 시 사용자 문구 — 입력 오류 안내, 어뷰징 문구 아님] */
export const BIRTH_DATE_ERROR_MESSAGE: Record<BirthDateValidationErrorCode, string> = {
  FUTURE_DATE: "태어난 날짜는 오늘보다 이전이어야 해요. 다시 확인해주세요.",
  DATE_NOT_EXIST: "존재하지 않는 날짜예요. 날짜를 다시 확인해주세요.",
  OUT_OF_RANGE: "입력 가능한 날짜 범위를 벗어났어요. 1900년 이후로 입력해주세요.",
  INVALID_FORMAT: "생년월일 형식을 확인해주세요.",
  INVALID_TIME: "태어난 시간을 확인해주세요.",
};

/** [§4 순서3 "에러 코드"] HTTP 상태는 전부 400(입력 오류) — §9 에러 코드 규격과 동일. */
export const BIRTH_DATE_ERROR_STATUS: Record<BirthDateValidationErrorCode, number> = {
  FUTURE_DATE: 400,
  DATE_NOT_EXIST: 400,
  OUT_OF_RANGE: 400,
  INVALID_FORMAT: 400,
  INVALID_TIME: 400,
};

/** [§4 순서4 "범위 검증" 초깃값] 만세력 커버 범위. SystemSetting으로 운영 중 조정 가능. */
const DEFAULT_MIN_BIRTH_YEAR = 1900;
const MIN_BIRTH_YEAR_SETTING_KEY = "saju_birth_min_year";

/**
 * [§4 순서4, §10 "설정값으로 노출"] system_settings(key-value, 기존 app-version/route.ts와
 * 동일 패턴 재사용)에서 최소 출생연도를 읽는다. 값이 없거나 파싱 실패 시 초깃값(1900)으로
 * 폴백한다 — 설정 자체가 없다고 서버가 죽거나 모든 입력을 거부하면 안 된다.
 */
export async function getMinBirthYear(): Promise<number> {
  try {
    const row = await prisma.systemSetting.findUnique({
      where: { key: MIN_BIRTH_YEAR_SETTING_KEY },
    });
    if (!row || row.status !== "active") return DEFAULT_MIN_BIRTH_YEAR;
    const parsed = JSON.parse(row.value);
    return typeof parsed === "number" && Number.isInteger(parsed) ? parsed : DEFAULT_MIN_BIRTH_YEAR;
  } catch {
    return DEFAULT_MIN_BIRTH_YEAR;
  }
}

/** [§4 공통 규칙 "미래 날짜 판정 기준은 서버 시각(KST)"] KST 자정 기준 "오늘" Date를 반환. */
function todayKstDate(): { year: number; month: number; day: number } {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return {
    year: kstNow.getUTCFullYear(),
    month: kstNow.getUTCMonth() + 1,
    day: kstNow.getUTCDate(),
  };
}

export interface BirthDateValidationInput {
  /** "YYYY-MM-DD" 형식 문자열(클라이언트 원본 그대로). */
  birthDate: string;
  isLunar?: boolean;
  /** 0~23 정수 또는 null/undefined("시간 모름"). */
  birthHour?: number | null;
  /** "시간 모름" 플래그 — true면 birthHour 값과 무관하게 시간 검증을 건너뛴다(§4 순서5). */
  birthTimeUnknown?: boolean;
}

export interface BirthDateValidationResult {
  year: number;
  month: number;
  day: number;
  /** 입력이 음력이었을 경우 양력으로 환산한 연월일(캐시 키 정규화 등에 사용 가능). */
  solarYear: number;
  solarMonth: number;
  solarDay: number;
}

/**
 * [§4 전체 — 서버 전용 검증, 엔진 도달 이전] 생년월일(+시간)을 순서대로 검증한다.
 * 실패하면 BirthDateValidationError를 던진다(호출측에서 바로 §9 에러 응답으로 변환).
 *
 * [§4.1 특수 케이스]
 *   · 오늘 태어난 경우 — 오늘 날짜 전체 허용(1차 범위, FUTURE_TIME 차단은 정책 선택
 *     사항이라 이 모듈 범위에 넣지 않는다 — §1 "개발 범위를 임의로 확장하지 말 것").
 *   · 음력 입력 — 양력 변환 후 동일 검증. 존재하지 않는 음력 날짜(윤달 아님 등)는
 *     lunar-javascript가 던지는 예외를 DATE_NOT_EXIST로 변환한다.
 *   · 윤년 2월 29일 — 존재하는 해만 허용(Date.UTC 롤오버로 자연스럽게 판정됨).
 */
export async function validateBirthDate(
  input: BirthDateValidationInput
): Promise<BirthDateValidationResult> {
  // ── 순서 1: 형식 검증 ──
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(input.birthDate ?? "");
  if (!match) {
    throw new BirthDateValidationError("INVALID_FORMAT", BIRTH_DATE_ERROR_MESSAGE.INVALID_FORMAT);
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw new BirthDateValidationError("INVALID_FORMAT", BIRTH_DATE_ERROR_MESSAGE.INVALID_FORMAT);
  }

  // ── 순서 2: 존재 날짜 검증(윤년 포함) ──
  let solarYear = year;
  let solarMonth = month;
  let solarDay = day;

  if (input.isLunar) {
    // 음력 입력: lunar-javascript가 "only 29 days in lunar year ... month ..." 같은
    // 예외를 던지면 존재하지 않는 음력 날짜 → DATE_NOT_EXIST로 변환한다.
    try {
      const lunar = Lunar.fromYmd(year, month, day);
      const solar = lunar.getSolar();
      solarYear = solar.getYear();
      solarMonth = solar.getMonth();
      solarDay = solar.getDay();
    } catch {
      throw new BirthDateValidationError("DATE_NOT_EXIST", BIRTH_DATE_ERROR_MESSAGE.DATE_NOT_EXIST);
    }
  } else {
    // 양력 입력: Date.UTC 롤오버 기법 — 2026-02-30처럼 존재하지 않는 날짜를 넣으면
    // JS Date가 다음 달로 "롤오버"시키므로, 되돌아온 연/월/일이 입력과 다르면 무효.
    const rolled = new Date(Date.UTC(year, month - 1, day));
    if (
      rolled.getUTCFullYear() !== year ||
      rolled.getUTCMonth() !== month - 1 ||
      rolled.getUTCDate() !== day
    ) {
      throw new BirthDateValidationError("DATE_NOT_EXIST", BIRTH_DATE_ERROR_MESSAGE.DATE_NOT_EXIST);
    }
  }

  // ── 순서 3: 미래 날짜 검증(서버 KST 기준, 예외 없음) ──
  // [§4.1 "오늘 태어난 경우"] 오늘 날짜 전체를 허용해야 하므로 양력 기준 "오늘보다
  // 이후"일 때만 차단한다(오늘 자정 포함 당일은 허용).
  const today = todayKstDate();
  const isFuture =
    solarYear > today.year ||
    (solarYear === today.year && solarMonth > today.month) ||
    (solarYear === today.year && solarMonth === today.month && solarDay > today.day);
  if (isFuture) {
    throw new BirthDateValidationError("FUTURE_DATE", BIRTH_DATE_ERROR_MESSAGE.FUTURE_DATE);
  }

  // ── 순서 4: 범위 검증(최소 출생연도, 설정값) ──
  // [원본 입력 연도(음력이면 음력 연도) 기준 — 사용자가 체감하는 "몇 년생"과 일치] 
  const minYear = await getMinBirthYear();
  if (year < minYear) {
    throw new BirthDateValidationError("OUT_OF_RANGE", BIRTH_DATE_ERROR_MESSAGE.OUT_OF_RANGE);
  }

  // ── 순서 5: 태어난 시 검증 ──
  if (!input.birthTimeUnknown && input.birthHour !== undefined && input.birthHour !== null) {
    if (
      !Number.isInteger(input.birthHour) ||
      input.birthHour < 0 ||
      input.birthHour > 23
    ) {
      throw new BirthDateValidationError("INVALID_TIME", BIRTH_DATE_ERROR_MESSAGE.INVALID_TIME);
    }
  }

  return { year, month, day, solarYear, solarMonth, solarDay };
}

/**
 * ["HH:MM" 문자열 편의 래퍼] fortune/saju 등 레거시 라우트는 birthTime을 "HH:MM"
 * 문자열로 받는다(숫자 hour가 아님). 파싱 실패/형식 오류 시 INVALID_TIME으로 던진다
 * — 기존처럼 조용히 기본값(12:00)으로 대체하지 않는다(§4 순서5 명시 검증 대상).
 * birthTime이 null/undefined이면("시간 모름") 검증을 건너뛰고 {}를 반환한다.
 */
export function parseBirthTimeString(
  birthTime: string | null | undefined
): { hour?: number; minute?: number } {
  if (!birthTime) return {};
  const match = /^(\d{1,2}):(\d{1,2})$/.exec(birthTime);
  if (!match) {
    throw new BirthDateValidationError("INVALID_TIME", BIRTH_DATE_ERROR_MESSAGE.INVALID_TIME);
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw new BirthDateValidationError("INVALID_TIME", BIRTH_DATE_ERROR_MESSAGE.INVALID_TIME);
  }
  return { hour, minute };
}
