// 신당(THE SHRINE) v3 공개 API 공용 헬퍼.
//
// [설계 원칙] ResultAccessService(§8)의 결제 게이트를 그대로 재사용하고,
// 이 파일은 신당 전용 로직(사주 한자 팔자 포맷, KST 날짜키, 唯一 일련번호)만
// 담당한다 — wishes/_shared.ts(requireUser/unauthorizedResponse)와 동일한
// 패턴을 따른다(신규 인증 로직을 만들지 않는다).
import { calculateSaju } from "@/lib/saju-manseryeok-engine";

export { requireUser, unauthorizedResponse } from "../wishes/_shared";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** [어뷰징 방지, §7] KST(UTC+9) 기준 "오늘"의 날짜키("YYYY-MM-DD"). 다른
 * 서비스(result-access-service.ts/open-pass-service.ts)와 동일한 절단 규칙. */
export function todayKstKey(): string {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** dateKey("YYYY-MM-DD")에 KST 기준 일수를 더한 새 날짜키를 반환한다. */
export function addDaysToKstKey(dateKey: string, days: number): string {
  const [y, m, d] = dateKey.split("-").map(Number);
  // UTC 정오로 고정해 DST/경계 문제 없이 날짜 산술만 수행한다(KST는 DST 없음).
  const base = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  base.setUTCDate(base.getUTCDate() + days);
  const ny = base.getUTCFullYear();
  const nm = base.getUTCMonth() + 1;
  const nd = base.getUTCDate();
  return `${ny}-${String(nm).padStart(2, "0")}-${String(nd).padStart(2, "0")}`;
}

/** dateKey 기준으로 dateKey가 오늘(KST)보다 과거인지(만료) 여부. */
export function isKstKeyBefore(dateKey: string, otherKey: string): boolean {
  return dateKey < otherKey; // "YYYY-MM-DD" 문자열은 사전식 비교 == 날짜 비교.
}

/** 09 부적함/부적함 상세 화면이 요구하는 "N일 남음"을 서버 상태로부터 계산한다.
 * 만료됐으면(expiresDateKey < 오늘) 0을 반환한다. */
export function daysRemainingFromExpiry(expiresDateKey: string): number {
  const today = todayKstKey();
  if (isKstKeyBefore(expiresDateKey, today)) return 0;
  const [ey, em, ed] = expiresDateKey.split("-").map(Number);
  const [ty, tm, td] = today.split("-").map(Number);
  const expires = Date.UTC(ey, em - 1, ed);
  const now = Date.UTC(ty, tm - 1, td);
  return Math.max(0, Math.round((expires - now) / 86400000));
}

export const SHRINE_LIFE_DAYS = 49;
export const SHRINE_INCENSE_BONUS_DAYS = 3;

/**
 * README §2/§6 — UserProfile(realName/birthDate/...)로 신통방통 정통사주
 * 엔진 결과를 계산하고, 唯一 기록에 쓰일 한자 팔자 문자열
 * (예: "乙亥 甲申 丁丑 丁未")을 만든다. **프로토타입의 하드코딩 SAJU8
 * 상수는 여기서 영구히 대체된다.**
 *
 * [신뢰 모델] gunghap/direct, guinji DIRECT 라우트와 동일하게, 로그인 본인의
 * 사주라도 서버가 UserProfile에 저장된 생년월일로 직접 계산한다(클라이언트가
 * 보낸 사주 문자열을 신뢰하지 않음 — 05 상세 화면은 "회원 정보 확인"만
 * 하고 실제 계산은 전부 이 함수가 서버에서 수행).
 */
export function buildSajuPillarsHanja(profile: {
  birthDate: string; // "YYYY-MM-DD"
  birthTime: string | null;
  isLunar: boolean;
  isLeapMonth: boolean;
  birthTimeUnknown: boolean;
  gender: string | null;
}): string {
  const [y, m, d] = profile.birthDate.split("-").map(Number);
  let hour: number | undefined;
  let minute = 0;
  if (!profile.birthTimeUnknown && profile.birthTime) {
    const match = /^(\d{1,2}):(\d{1,2})$/.exec(profile.birthTime);
    if (match) {
      hour = Number(match[1]);
      minute = Number(match[2]);
    }
  }
  const result = calculateSaju({
    year: y,
    month: m,
    day: d,
    hour,
    minute,
    gender: profile.gender === "female" ? "female" : "male",
    isLunar: profile.isLunar,
    isLeapMonth: profile.isLeapMonth,
    timeUnknown: profile.birthTimeUnknown || hour === undefined,
  });
  const { year: yp, month: mp, day: dp, hour: hp } = result.pillars;
  // [唯一 §6] "시 모름이면 3주"만 표기 — README 3-2/3-3 예시와 동일한 형식.
  if (result.timeUnknown) {
    return `${yp.gan}${yp.zhi} ${mp.gan}${mp.zhi} ${dp.gan}${dp.zhi}`;
  }
  return `${yp.gan}${yp.zhi} ${mp.gan}${mp.zhi} ${dp.gan}${dp.zhi} ${hp.gan}${hp.zhi}`;
}
