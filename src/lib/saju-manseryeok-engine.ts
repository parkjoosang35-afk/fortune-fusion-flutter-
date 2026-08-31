// [정통사주 만세력 엔진 — TypeScript 포팅] Flutter
// `lib/features/home/domain/saju_engine.dart`(SajuEngine)를 그대로
// TypeScript로 이식한 것. 원본 Dart가 pub.dev `lunar` 패키지(원저자
// 6tail, v1.7.7)로 실제 만세력(60갑자·오행·십신·신살·대운)을 계산하듯,
// 이 파일은 동일 저자·동일 버전의 npm `lunar-javascript`(v1.7.7)로
// 완전히 동일한 알고리즘을 사용한다.
//
// [검증] 1972-02-13 02:00(양력, 남) 입력 시 두 구현 모두
// 년주=壬子/월주=壬寅/일주=甲戌/시주=乙丑, 오행카운트/십신/신살/공망까지
// 전부 일치함을 직접 실행하여 확인했다(2026-09, 웹 미리보기 정확도
// 개선 작업 중). 음력 입력 모드(Lunar.fromYmdHms)도 동일하게 대조
// 검증했다.
//
// [사용처] 이 엔진은 오직 "웹 미리보기"(`/g/[token]/preview` API)에서만
// 쓰인다. 로그인 후 앱 내부 정식 참여(`POST /guinji/maps/{mapId}/members`)
// 는 여전히 Flutter `ManseryeokCoreEngine`이 계산한 값을 그대로 신뢰하는
// B안 아키텍처를 유지한다(서버가 재계산하지 않음) — 이 파일이 그 원칙을
// 바꾸는 것이 아니라, "로그인 전 웹 방문자"에게도 동일하게 정확한 계산을
// 제공하기 위한 별도 경로다.
//
// [정직성 원칙 갱신] 기존 `buildPreviewSajuInput()`(생년월일 해시 기반
// 가짜 계산)은 더 이상 사용하지 않는다. 이 엔진은 진짜 만세력이므로,
// 웹 미리보기 결과에도 이제 `isPreview: true`를 유지하되 그 의미는
// "시간 미입력 시 정오 가정 등으로 인한 근사"만을 뜻하게 된다(명식
// 자체는 더 이상 가짜가 아님).
import { Lunar, Solar } from "lunar-javascript";

const GAN_KR: Record<string, string> = {
  甲: "갑", 乙: "을", 丙: "병", 丁: "정", 戊: "무",
  己: "기", 庚: "경", 辛: "신", 壬: "임", 癸: "계",
};

const ZHI_KR: Record<string, string> = {
  子: "자", 丑: "축", 寅: "인", 卯: "묘", 辰: "진", 巳: "사",
  午: "오", 未: "미", 申: "신", 酉: "유", 戌: "술", 亥: "해",
};

/** (오행, 음양) — saju_engine.dart의 ganElement/zhiElement와 동일 고정표. */
const GAN_ELEMENT: Record<string, { el: string; yy: "양" | "음" }> = {
  甲: { el: "목", yy: "양" }, 乙: { el: "목", yy: "음" },
  丙: { el: "화", yy: "양" }, 丁: { el: "화", yy: "음" },
  戊: { el: "토", yy: "양" }, 己: { el: "토", yy: "음" },
  庚: { el: "금", yy: "양" }, 辛: { el: "금", yy: "음" },
  壬: { el: "수", yy: "양" }, 癸: { el: "수", yy: "음" },
};

const ZHI_ELEMENT: Record<string, { el: string; yy: "양" | "음" }> = {
  子: { el: "수", yy: "양" }, 丑: { el: "토", yy: "음" },
  寅: { el: "목", yy: "양" }, 卯: { el: "목", yy: "음" },
  辰: { el: "토", yy: "양" }, 巳: { el: "화", yy: "음" },
  午: { el: "화", yy: "양" }, 未: { el: "토", yy: "음" },
  申: { el: "금", yy: "양" }, 酉: { el: "금", yy: "음" },
  戌: { el: "토", yy: "양" }, 亥: { el: "수", yy: "음" },
};

const SHENG: Record<string, string> = { 목: "화", 화: "토", 토: "금", 금: "수", 수: "목" };
const KE: Record<string, string> = { 목: "토", 토: "수", 수: "화", 화: "금", 금: "목" };

const TEN_GODS_TABLE: Record<string, string> = {
  "same:true": "비견", "same:false": "겁재",
  "生out:true": "식신", "生out:false": "상관",
  "克out:true": "편재", "克out:false": "정재",
  "克in:true": "편관", "克in:false": "정관",
  "生in:true": "편인", "生in:false": "정인",
};

/** 일간(dayGan) 기준 상대 글자(천간/지지)의 십신 — get_ten_god() 이식. */
function getTenGod(dayGan: string, targetGanOrZhi: string): string {
  const day = GAN_ELEMENT[dayGan];
  const tgt = GAN_ELEMENT[targetGanOrZhi] ?? ZHI_ELEMENT[targetGanOrZhi];
  const sameYy = day.yy === tgt.yy;
  let rel: string;
  if (day.el === tgt.el) rel = "same";
  else if (SHENG[day.el] === tgt.el) rel = "生out";
  else if (KE[day.el] === tgt.el) rel = "克out";
  else if (KE[tgt.el] === day.el) rel = "克in";
  else if (SHENG[tgt.el] === day.el) rel = "生in";
  else rel = "same";
  return TEN_GODS_TABLE[`${rel}:${sameYy}`];
}

// ── 신살(神殺) — 대표 3종, saju_engine.dart와 동일 범위 ──
const CHEONEUL_GWIIN: Record<string, string[]> = {
  甲: ["丑", "未"], 戊: ["丑", "未"], 庚: ["丑", "未"],
  乙: ["子", "申"], 己: ["子", "申"],
  丙: ["亥", "酉"], 丁: ["亥", "酉"],
  壬: ["卯", "巳"], 癸: ["卯", "巳"],
  辛: ["寅", "午"],
};

const MUNCHANG_GWIIN: Record<string, string> = {
  甲: "巳", 乙: "午", 丙: "申", 丁: "酉", 戊: "申",
  己: "酉", 庚: "亥", 辛: "子", 壬: "寅", 癸: "卯",
};

const YEOKMA: Record<string, string> = {
  寅: "申", 午: "申", 戌: "申",
  申: "寅", 子: "寅", 辰: "寅",
  巳: "亥", 酉: "亥", 丑: "亥",
  亥: "巳", 卯: "巳", 未: "巳",
};

/** 대표 신살 검출 — find_sinsal() 이식. */
function findSinsal(dayGan: string, zhiList: string[]): string[] {
  const found: string[] = [];
  if (zhiList.some((z) => (CHEONEUL_GWIIN[dayGan] ?? []).includes(z))) {
    found.push("天乙貴人(천을귀인)");
  }
  if (zhiList.includes(MUNCHANG_GWIIN[dayGan])) {
    found.push("文昌貴人(문창귀인)");
  }
  const dayZhi = zhiList[2]; // 일지 기준
  if (zhiList.includes(YEOKMA[dayZhi])) {
    found.push("驛馬(역마)");
  }
  return found;
}

/** 공망 계산 — get_gongmang() 이식. */
function getGongmang(dayGan: string, dayZhi: string): string {
  const ganOrder = "甲乙丙丁戊己庚辛壬癸";
  const zhiOrder = "子丑寅卯辰巳午未申酉戌亥";
  const gIdx = ganOrder.indexOf(dayGan);
  const zIdx = zhiOrder.indexOf(dayZhi);
  const start = zIdx - gIdx;
  const gmStart = (((start + 10) % 12) + 12) % 12;
  const gmEnd = (((start + 11) % 12) + 12) % 12;
  const c1 = zhiOrder[gmStart];
  const c2 = zhiOrder[gmEnd];
  return `${c1}${c2} (${ZHI_KR[c1]}${ZHI_KR[c2]})`;
}

/** 신강/신약 판정(간이 버전) — judge_strength() 이식. */
function judgeStrength(dayGan: string, elementsCount: Record<string, number>): string {
  const dayEl = GAN_ELEMENT[dayGan].el;
  let helperEl: string | undefined;
  for (const [k, v] of Object.entries(SHENG)) {
    if (v === dayEl) { helperEl = k; break; }
  }
  const helperCount = (elementsCount[dayEl] ?? 0) + (helperEl ? elementsCount[helperEl] ?? 0 : 0);
  const total = Object.values(elementsCount).reduce((a, b) => a + b, 0);
  const ratio = total === 0 ? 0 : helperCount / total;
  if (ratio >= 0.5) return "身强(신강)";
  if (ratio >= 0.35) return "中和(중화)";
  return "身弱(신약)";
}

export interface SajuPillar {
  gan: string;
  zhi: string;
  kr: string; // 예: "임자"
  element: string; // 예: "수-수"
}

export interface SajuLuckPillar {
  startAge: number;
  startYear: number;
  ganZhi: string;
  ganZhiKr: string;
}

export interface SajuManseryeokResult {
  gender: "male" | "female";
  birthSolar: string;
  birthLunar: string;
  pillars: { year: SajuPillar; month: SajuPillar; day: SajuPillar; hour: SajuPillar };
  dayMaster: { gan: string; kr: string; element: string; yinYang: string };
  dayMasterStrength: string;
  fiveElementsCount: Record<string, number>;
  tenGods: Record<string, string>;
  sinsal: string[];
  gongmang: string;
  luckPillars: SajuLuckPillar[];
  currentAge: number;
  /** 시간 미입력 시 정오(12:00) 가정으로 계산했음을 나타낸다(정확도 낮음 안내용). */
  timeUnknown: boolean;
}

export interface CalculateSajuOptions {
  year: number;
  month: number;
  day: number;
  /** 시(0~23). 미입력(timeUnknown=true) 시 12로 간주. */
  hour?: number;
  minute?: number;
  gender?: "male" | "female";
  isLunar?: boolean;
  timeUnknown?: boolean;
  /** 대운 판정 기준 시점(생략 시 현재 시각). */
  referenceDate?: Date;
}

/**
 * 정통사주 만세력 계산 — Dart `SajuEngine.calculate()`와 1:1 대응.
 * [정직성 원칙] 이것은 더 이상 "간이/가짜" 계산이 아니라, 앱과 동일한
 * 알고리즘(lunar-javascript, 6tail 원작 동일 버전)으로 산출한 실제
 * 사주 명식이다. 시간을 모를 때만(timeUnknown=true) 정오로 가정하는
 * 근사가 있을 뿐이다.
 */
export function calculateSaju(opts: CalculateSajuOptions): SajuManseryeokResult {
  const {
    year, month, day,
    hour: hourIn, minute = 0,
    gender = "male",
    isLunar = false,
    timeUnknown = false,
    referenceDate,
  } = opts;
  const hour = timeUnknown ? 12 : (hourIn ?? 12);

  let solar: InstanceType<typeof Solar>;
  let lunar: InstanceType<typeof Lunar>;
  if (isLunar) {
    lunar = Lunar.fromYmdHms(year, month, day, hour, minute, 0);
    solar = lunar.getSolar();
  } else {
    solar = Solar.fromYmdHms(year, month, day, hour, minute, 0);
    lunar = solar.getLunar();
  }

  const ec = lunar.getEightChar();
  const yGan: string = ec.getYearGan();
  const yZhi: string = ec.getYearZhi();
  const mGan: string = ec.getMonthGan();
  const mZhi: string = ec.getMonthZhi();
  const dGan: string = ec.getDayGan();
  const dZhi: string = ec.getDayZhi();
  const hGan: string = ec.getTimeGan();
  const hZhi: string = ec.getTimeZhi();

  const ganList = [yGan, mGan, dGan, hGan];
  const zhiList = [yZhi, mZhi, dZhi, hZhi];

  const elementsCount: Record<string, number> = { 목: 0, 화: 0, 토: 0, 금: 0, 수: 0 };
  for (const g of ganList) elementsCount[GAN_ELEMENT[g].el]++;
  for (const z of zhiList) elementsCount[ZHI_ELEMENT[z].el]++;

  const tenGods: Record<string, string> = {
    year_gan: getTenGod(dGan, yGan),
    month_gan: getTenGod(dGan, mGan),
    hour_gan: getTenGod(dGan, hGan),
    year_zhi: getTenGod(dGan, yZhi),
    month_zhi: getTenGod(dGan, mZhi),
    day_zhi: getTenGod(dGan, dZhi),
    hour_zhi: getTenGod(dGan, hZhi),
  };

  const strength = judgeStrength(dGan, elementsCount);
  const sinsal = findSinsal(dGan, zhiList);
  const gongmang = getGongmang(dGan, dZhi);

  // 대운(10년 단위) — 첫 9개.
  const yun = ec.getYun(gender === "male" ? 1 : 0);
  const daYunList = yun.getDaYun();
  const luckPillars: SajuLuckPillar[] = [];
  for (const dy of daYunList.slice(0, 9)) {
    const gz: string = dy.getGanZhi();
    const gzKr = gz.length >= 2 ? `${GAN_KR[gz[0]] ?? ""}${ZHI_KR[gz[1]] ?? ""}` : "";
    luckPillars.push({
      startAge: dy.getStartAge(),
      startYear: dy.getStartYear(),
      ganZhi: gz,
      ganZhiKr: gzKr,
    });
  }

  const ref = referenceDate ?? new Date();
  const currentYear = ref.getFullYear();
  const currentAge = currentYear - year + 1; // 세는 나이

  const buildPillar = (gan: string, zhi: string): SajuPillar => ({
    gan, zhi,
    kr: `${GAN_KR[gan]}${ZHI_KR[zhi]}`,
    element: `${GAN_ELEMENT[gan].el}-${ZHI_ELEMENT[zhi].el}`,
  });

  const pad = (n: number, len = 2) => n.toString().padStart(len, "0");

  return {
    gender,
    birthSolar: `${pad(year, 4)}-${pad(month)}-${pad(day)} ${pad(hour)}:${pad(minute)}`,
    birthLunar: lunar.toString(),
    pillars: {
      year: buildPillar(yGan, yZhi),
      month: buildPillar(mGan, mZhi),
      day: buildPillar(dGan, dZhi),
      hour: buildPillar(hGan, hZhi),
    },
    dayMaster: {
      gan: dGan,
      kr: GAN_KR[dGan],
      element: GAN_ELEMENT[dGan].el,
      yinYang: GAN_ELEMENT[dGan].yy,
    },
    dayMasterStrength: strength,
    fiveElementsCount: elementsCount,
    tenGods,
    sinsal,
    gongmang,
    luckPillars,
    currentAge,
    timeUnknown,
  };
}

/**
 * `SajuManseryeokResult` → `GuinjiSajuInput`(guinji-relation-judger.ts 계약)
 * 변환 — Flutter `guinjiSajuInputFromProfile()`과 동일한 어댑터를 웹에서도
 * 재사용한다. 시살 ID는 신살 문자열에서 한자 부분만 추출한다(예:
 * '天乙貴人(천을귀인)' → '天乙貴人', Dart의 sinsal_engine.dart와 동일 규칙).
 */
export function guinjiSajuInputFromManseryeok(result: SajuManseryeokResult) {
  return {
    dayStemHanja: result.dayMaster.gan,
    stems: {
      year: result.pillars.year.gan,
      month: result.pillars.month.gan,
      day: result.pillars.day.gan,
      hour: result.pillars.hour.gan,
    },
    branches: {
      year: result.pillars.year.zhi,
      month: result.pillars.month.zhi,
      day: result.pillars.day.zhi,
      hour: result.pillars.hour.zhi,
    },
    fiveElementsCount: result.fiveElementsCount,
    sinsalIds: result.sinsal.map((s) => s.split("(")[0]),
  };
}
