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
//
// [중대 수정 이력 — 2026-09, 사용자 피드백 반영]
// 위 1차 버전은 Flutter의 **레거시** `saju_engine.dart`(SajuEngine)만
// 이식한 것이었다. 그런데 실제 앱의 귀인지도(`guinji_provider.dart` →
// `JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4()`)는
// 레거시 엔진을 쓰지 않고, **신규 엔진**(`ManseryeokCoreEngine` +
// `SinsalEngine` + `RelationshipsEngine`, 신살 15종 이상 계산)을 쓴다는
// 것을 뒤늦게 발견했다. 레거시는 신살을 3종(천을귀인/문창귀인/역마)만
// 계산해, 앱이 실제로 산출하는 명식과 웹 미리보기 명식 사이에 기능적
// 격차가 있었다 — 이는 명백한 검증 부실이었다. 이번 수정으로 Flutter
// `sinsal_engine.dart`(공망 포함 다수 신살)와 `relationships_engine.dart`
// (원진 관계)를 그대로 이식해 신규 엔진과 신살 목록을 동등하게 만든다.
//
// [2차 외부 검증 — 2026-09] 자체 구현끼리의 대조만으로는 불충분하다는
// 반성 하에, 이 코드베이스와 무관한 외부 자료와 교차검증했다.
// 1988-09-17 09:00(양력) 케이스 계산 결과(년주=戊辰/월주=辛酉/일주=乙亥/
// 시주=辛巳)를, 이 생년월일의 실존 인물(이용대)을 다루는 외부 사이트
// (unseon.com)가 명시한 "년주 戊辰·월주 辛酉·일주 乙亥"와 대조해 3주
// 전부 일치를 확인했다. 또한 자시(子時) 경계 시각(23:30/00:30)을 직접
// 테스트해 `EightChar.setSect()` 패키지 기본값이 이 프로젝트가 채택한
// 정책(sect=2, 야자시도 당일)과 정확히 일치함을 코드 실행으로 확인했다
// (`manseryeok_policy.dart` 정책 문서와 패키지 실제 동작 일치 재검증).
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

/** 대표 신살 검출 — find_sinsal() 이식(레거시 3종, SinsalEngine ①에서 재사용). */
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

// ── [신규 엔진 이식 — 2026-09 수정] Flutter `sinsal_engine.dart` +
// `relationships_engine.dart`의 신살 15종 이상 계산을 그대로 이식한다.
// 아래 상수/로직은 Dart 원본과 완전히 동일한 고정표를 사용하며, 새로운
// 명리 판정 규칙을 임의로 만들지 않는다(원본 Dart 파일 주석 "절대 원칙"과
// 동일 원칙 적용).

const ZHI_ORDER = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"];

/** 지지 → 그 지지가 속한 삼합 그룹의 생지(生地). sinsal_engine.dart 동일. */
const BRANCH_TO_GROUP_SAENGJI: Record<string, string> = {
  申: "申", 子: "申", 辰: "申",
  巳: "巳", 酉: "巳", 丑: "巳",
  寅: "寅", 午: "寅", 戌: "寅",
  亥: "亥", 卯: "亥", 未: "亥",
};

/** 지살(오프셋 0) 기준 12신살 순서 오프셋. sinsal_engine.dart 동일. */
const TWELVE_SINSAL_OFFSETS: Array<[number, string]> = [
  [-3, "겁살"], [-2, "재살"], [-1, "천살"], [0, "지살"],
  [1, "년살"], [2, "월살"], [3, "망신살"], [4, "장성살"],
  [5, "반안살"], [6, "역마살"], [7, "육해살"], [8, "화개살"],
];

function computeTwelveSinsalTable(basisBranch: string): Record<string, string> {
  const saengJi = BRANCH_TO_GROUP_SAENGJI[basisBranch];
  const saengJiIdx = ZHI_ORDER.indexOf(saengJi);
  const table: Record<string, string> = {};
  for (const [offset, name] of TWELVE_SINSAL_OFFSETS) {
    table[name] = ZHI_ORDER[(((saengJiIdx + offset) % 12) + 12) % 12];
  }
  return table;
}

/** 양인살 — 일간(양간만) 기준. sinsal_engine.dart 동일. */
const YANG_IN_BY_DAY_GAN: Record<string, string> = {
  甲: "卯", 丙: "午", 戊: "午", 庚: "酉", 壬: "子",
};

/** 괴강살 — 일주 고정표. sinsal_engine.dart 동일. */
const GOEGANG_DAY_PILLARS = ["庚辰", "庚戌", "壬辰", "戊戌"];

/** 백호대살 — 일주 고정표(7주). sinsal_engine.dart 동일. */
const BAEKHO_DAESAL_PILLARS = ["甲辰", "乙未", "丙戌", "丁丑", "戊辰", "壬戌", "癸丑"];

/** 원진(怨嗔) 쌍 — relationships_engine.dart의 _yuanChenPairs와 동일. */
const YUAN_CHEN_PAIRS: Array<[string, string]> = [
  ["子", "未"], ["丑", "午"], ["寅", "酉"], ["卯", "申"], ["辰", "亥"], ["巳", "戌"],
];

export interface SinsalEntry {
  id: string;
  nameKr: string;
  nameHanja: string;
  basis: string;
  foundOn: string[];
}

/**
 * [신규 엔진 이식] `SinsalEngine.analyze()`(sinsal_engine.dart) 전체를
 * TypeScript로 이식 — 신살 15종 이상(천을귀인/문창귀인/역마/공망/12신살/
 * 양인살/괴강살/백호대살/원진살)을 계산한다. 이전(1차) 버전은 레거시의
 * 3종만 반영해 실제 앱(신규 엔진)과 결과 격차가 있었다 — 이 함수가 그
 * 격차를 없앤다.
 */
function analyzeSinsal(
  yearPillar: SajuPillar,
  monthPillar: SajuPillar,
  dayPillar: SajuPillar,
  hourPillar: SajuPillar
): SinsalEntry[] {
  const positions: Record<string, SajuPillar> = {
    year: yearPillar, month: monthPillar, day: dayPillar, hour: hourPillar,
  };
  const posLabel: Record<string, string> = { year: "년지", month: "월지", day: "일지", hour: "시지" };
  const branches: Record<string, string> = {
    year: yearPillar.zhi, month: monthPillar.zhi, day: dayPillar.zhi, hour: hourPillar.zhi,
  };
  const dayGan = dayPillar.gan;
  const dayZhi = dayPillar.zhi;
  const entries: SinsalEntry[] = [];

  // ① 레거시 3종(천을귀인/문창귀인/역마) 재사용 + 발동 위치 역추적.
  const zhiList = [yearPillar.zhi, monthPillar.zhi, dayPillar.zhi, hourPillar.zhi];
  const legacyFound = findSinsal(dayGan, zhiList);
  const matchesLegacy = (name: string, zhi: string): boolean => {
    if (name === "天乙貴人") return (CHEONEUL_GWIIN[dayGan] ?? []).includes(zhi);
    if (name === "文昌貴人") return MUNCHANG_GWIIN[dayGan] === zhi;
    if (name === "驛馬") return YEOKMA[dayZhi] === zhi;
    return false;
  };
  for (const f of legacyFound) {
    const name = f.split("(")[0];
    const foundOn = Object.entries(branches)
      .filter(([, z]) => matchesLegacy(name, z))
      .map(([k]) => posLabel[k]);
    const nameKr = f.includes("(") ? f.split("(")[1].replace(")", "") : name;
    entries.push({ id: name, nameKr, nameHanja: name, basis: "일간", foundOn });
  }

  // ② 공망(空亡).
  const gongmang = getGongmang(dayGan, dayZhi);
  const gongmangBranches = gongmang.split(" ")[0];
  const gongmangFoundOn = Object.entries(branches)
    .filter(([, z]) => gongmangBranches.includes(z))
    .map(([k]) => posLabel[k]);
  entries.push({ id: "空亡", nameKr: "공망", nameHanja: "空亡", basis: "일주", foundOn: gongmangFoundOn });

  // ③ 12신살(일지 기준).
  const table = computeTwelveSinsalTable(dayZhi);
  for (const [name, branch] of Object.entries(table)) {
    const foundOn = Object.entries(branches)
      .filter(([, z]) => z === branch)
      .map(([k]) => posLabel[k]);
    entries.push({ id: `12신살_${name}`, nameKr: name, nameHanja: branch, basis: "일지", foundOn });
  }

  // ④ 양인살(일간 기준).
  const yangIn = YANG_IN_BY_DAY_GAN[dayGan];
  if (yangIn) {
    const foundOn = Object.entries(branches)
      .filter(([, z]) => z === yangIn)
      .map(([k]) => posLabel[k]);
    entries.push({ id: "羊刃", nameKr: "양인살", nameHanja: yangIn, basis: "일간", foundOn });
  }

  // ⑤ 괴강살(4주 전체).
  const goeGangFoundOn = Object.entries(positions)
    .filter(([, p]) => GOEGANG_DAY_PILLARS.includes(p.gan + p.zhi))
    .map(([k]) => posLabel[k]);
  if (goeGangFoundOn.length > 0) {
    entries.push({ id: "魁罡", nameKr: "괴강살", nameHanja: "魁罡", basis: "주(柱) 전체", foundOn: goeGangFoundOn });
  }

  // ⑥ 백호대살(4주 전체).
  const baekhoFoundOn = Object.entries(positions)
    .filter(([, p]) => BAEKHO_DAESAL_PILLARS.includes(p.gan + p.zhi))
    .map(([k]) => posLabel[k]);
  if (baekhoFoundOn.length > 0) {
    entries.push({ id: "白虎", nameKr: "백호대살", nameHanja: "白虎", basis: "주(柱) 전체", foundOn: baekhoFoundOn });
  }

  // ⑦ 원진(元辰) — relationships_engine.dart의 원진 판정 로직 이식.
  const branchPosLabel = ["년지", "월지", "일지", "시지"];
  const branchArr = [yearPillar.zhi, monthPillar.zhi, dayPillar.zhi, hourPillar.zhi];
  const yuanChenFoundOn = new Set<string>();
  for (const [a, b] of YUAN_CHEN_PAIRS) {
    for (let i = 0; i < 4; i++) {
      for (let j = i + 1; j < 4; j++) {
        if ((branchArr[i] === a && branchArr[j] === b) || (branchArr[i] === b && branchArr[j] === a)) {
          yuanChenFoundOn.add(branchPosLabel[i]);
          yuanChenFoundOn.add(branchPosLabel[j]);
        }
      }
    }
  }
  if (yuanChenFoundOn.size > 0) {
    entries.push({
      id: "元辰", nameKr: "원진살", nameHanja: "元辰", basis: "지지 조합",
      foundOn: Array.from(yuanChenFoundOn),
    });
  }

  return entries;
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
  /**
   * [2026-09 수정] 이전에는 레거시 3종(문자열 배열)이었으나, 이제
   * `SinsalEngine.analyze()`(신규 엔진) 이식으로 15종 이상을 반환한다.
   */
  sinsal: SinsalEntry[];
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
  const gongmang = getGongmang(dGan, dZhi);

  // 대운(10년 단위) — 첫 9개.
  //
  // [중대 수정 — 2026-09, 대운 검증 중 발견된 버그 수정]
  // 기존에는 레거시 Dart `saju_engine.dart`의 패턴(`getYun(gender)`,
  // sect 인자 없음, `getDaYun()` → `.slice(0, 9)`)을 그대로 베꼈으나,
  // 이는 `lunar` 패키지 원본(Yun.dart/DaYun.dart, npm lunar-javascript
  // 동일)의 index 처리 방식을 오해한 버그였다:
  //   - `getDaYun()`은 index 0~9(10개)를 반환하는데, index<1(=0)은
  //     "소운기"(출생~첫 대운 시작 전 과도기)로 `getGanZhi()`가 빈
  //     문자열을 반환한다.
  //   - 레거시 패턴은 `.slice(0, 9)`로 index 0~8을 취하므로, 결과
  //     목록 1번째에 빈 간지 항목이 섞여 들어가고, 실제 유효한 9번째
  //     대운(index 9)이 누락되는 문제가 있었다.
  // 신규 엔진(`daewoon_engine.dart`의 `DaewoonEngine.analyze()`)은
  // `getDaYunBy(count + 1)`로 넉넉히 가져온 뒤 `index < 1`을 명시적으로
  // 걸러내 진짜 대운 9개(index 1~9)만 담는다. 여기서도 동일하게 맞춘다.
  // (sect 기본값은 Dart/JS 모두 인자 없이 호출 시 1로 귀결되므로 영향
  // 없음 — 검증 완료.)
  const yun = ec.getYun(gender === "male" ? 1 : 0);
  const daYunList = yun.getDaYun(10);
  const luckPillars: SajuLuckPillar[] = [];
  for (const dy of daYunList) {
    if (dy.getIndex() < 1) continue; // 소운기(빈 간지) 제외.
    const gz: string = dy.getGanZhi();
    if (gz.length < 2) continue;
    const gzKr = `${GAN_KR[gz[0]] ?? ""}${ZHI_KR[gz[1]] ?? ""}`;
    luckPillars.push({
      startAge: dy.getStartAge(),
      startYear: dy.getStartYear(),
      ganZhi: gz,
      ganZhiKr: gzKr,
    });
    if (luckPillars.length >= 9) break;
  }

  const ref = referenceDate ?? new Date();
  const currentYear = ref.getFullYear();
  const currentAge = currentYear - year + 1; // 세는 나이

  const buildPillar = (gan: string, zhi: string): SajuPillar => ({
    gan, zhi,
    kr: `${GAN_KR[gan]}${ZHI_KR[zhi]}`,
    element: `${GAN_ELEMENT[gan].el}-${ZHI_ELEMENT[zhi].el}`,
  });

  const yearPillarObj = buildPillar(yGan, yZhi);
  const monthPillarObj = buildPillar(mGan, mZhi);
  const dayPillarObj = buildPillar(dGan, dZhi);
  const hourPillarObj = buildPillar(hGan, hZhi);

  // [신규 엔진 이식] 신살 15종 이상 계산(sinsal_engine.dart 이식).
  const sinsal = analyzeSinsal(yearPillarObj, monthPillarObj, dayPillarObj, hourPillarObj);

  const pad = (n: number, len = 2) => n.toString().padStart(len, "0");

  return {
    gender,
    birthSolar: `${pad(year, 4)}-${pad(month)}-${pad(day)} ${pad(hour)}:${pad(minute)}`,
    birthLunar: lunar.toString(),
    pillars: {
      year: yearPillarObj,
      month: monthPillarObj,
      day: dayPillarObj,
      hour: hourPillarObj,
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
 * 재사용한다. [2026-09 수정] `sinsal`이 이제 `SinsalEntry[]`(신규 엔진,
 * 15종 이상)이므로 각 항목의 `id`를 그대로 사용한다(Dart
 * `guinji_saju_adapter.dart`의 `profile.sinsal?.map((e) => e.id)`와 동일).
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
    sinsalIds: result.sinsal.map((s) => s.id),
  };
}
