// [정통사주 AI 프롬프트 개선 — saju-output-spec.pdf 대응]
//
// 이 모듈은 PDF 스펙의 "원칙 1 — 계산과 표현을 분리한다"를 구현한다.
//
//   ① 계산 엔진(route.ts의 computeChart) — 생년월일시 → 사주 원국(pillars).
//      [범위 밖] 여전히 결정론적 해시 기반이다(진짜 만세력 아님). 이 파일은
//      그 값을 바꾸지 않는다 — computeChart()의 출력(pillars/fiveElements/seed)은
//      그대로 두고, 오직 "이미 나온 pillars 문자열"만 재료로 사용한다.
//
//   ② 판정 레이어(이 파일) — pillars(간지 문자열) → day_master/ten_gods_count/
//      elements_ratio/verdict/flow. 여기서 사용하는 오행 상생상극표·연도
//      간지 공식은 전부 결정론적 실제 규칙(해시/랜덤 아님)이다:
//        - 간지 8자(년/월/일/시 각 간+지)를 오행으로 환산해 십신 유사 분류를
//          계산한다(일간 대비 동일=비겁/내가생함=식상/내가극함=재성/
//          나를극함=관성/나를생함=인성 — 명리학 표준 상생상극 사이클).
//        - 세운(올해 간지)은 실제 달력 공식 (year-4)%10 / (year-4)%12로
//          계산한다(1984=갑자년 기준, 하드코딩·해시 아님).
//        - 대운(10년 흐름)은 진짜 대운수(절입일수÷3, 성별+음양 순역)를
//          계산할 만세력 인프라가 없어 seed 기반으로 "그럴듯한 시작 나이"만
//          생성한다 — 이 부분만 여전히 근사치임을 아래 주석/필드로 명시한다.
//
//   ③ 표현 레이어(LLM) — 이 파일이 만든 JSON만 받아서 문장을 쓴다.
//      route.ts가 buildSajuJudgment()의 결과를 system prompt의 {{saju_json}}
//      자리에 주입한다.

export type SajuGrade = "good" | "neutral" | "caution";

export interface SajuVerdictEntry {
  grade: SajuGrade;
  primary_evidence: string;
  hook: string;
}

export interface SajuJudgment {
  birth: { solar: string; gender: string; truesolar_applied: boolean };
  pillars: { year: string; month: string; day: string; hour: string | null };
  day_master: { stem: string; element: string; note: string };
  ten_gods_count: Record<string, number>;
  elements_ratio: Record<string, number>;
  verdict: {
    wealth: SajuVerdictEntry;
    relation: SajuVerdictEntry;
    career: SajuVerdictEntry;
    health: SajuVerdictEntry;
  };
  flow: {
    daewoon: { start_age: number; current: string; until: number };
    sewoon: { year: number; ganji: string; keyword: string };
  };
}

const STEM_ELEMENT: Record<string, string> = {
  갑: "목",
  을: "목",
  병: "화",
  정: "화",
  무: "토",
  기: "토",
  경: "금",
  신: "금",
  임: "수",
  계: "수",
};

const BRANCH_ELEMENT: Record<string, string> = {
  자: "수",
  축: "토",
  인: "목",
  묘: "목",
  진: "토",
  사: "화",
  오: "화",
  미: "토",
  신: "금",
  유: "금",
  술: "토",
  해: "수",
};

const DAY_MASTER_NOTE: Record<string, string> = {
  갑: "큰 나무처럼 뻗어나가는 기질",
  을: "화초처럼 유연하게 적응하는 기질",
  병: "태양처럼 널리 비추는 기질",
  정: "촛불처럼 은은하게 밝히는 기질",
  무: "산처럼 묵직하게 자리를 지키는 기질",
  기: "밭처럼 두루 품고 키우는 기질",
  경: "쇠처럼 단단하고 결단력 있는 기질",
  신: "보석처럼 섬세하고 정교한 기질",
  임: "큰 강물처럼 흐름을 만드는 기질",
  계: "이슬비처럼 조용히 스며드는 기질",
};

// 상생 사이클(내가 생하는 다음 원소): 목→화→토→금→수→목
const GENERATES: Record<string, string> = {
  목: "화",
  화: "토",
  토: "금",
  금: "수",
  수: "목",
};
// 상극 사이클(내가 극하는 원소): 목→토, 화→금, 토→수, 금→목, 수→화
const OVERCOMES: Record<string, string> = {
  목: "토",
  화: "금",
  토: "수",
  금: "목",
  수: "화",
};

const STEMS_ORDER = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const BRANCHES_ORDER = [
  "자",
  "축",
  "인",
  "묘",
  "진",
  "사",
  "오",
  "미",
  "신",
  "유",
  "술",
  "해",
];

/** 일간(day master) element 기준으로, 주어진 element가 어떤 십신 범주인지 분류한다. */
function classifyTenGod(dmElement: string, targetElement: string): string {
  if (targetElement === dmElement) return "비겁";
  if (GENERATES[dmElement] === targetElement) return "식상";
  if (OVERCOMES[dmElement] === targetElement) return "재성";
  if (OVERCOMES[targetElement] === dmElement) return "관성";
  if (GENERATES[targetElement] === dmElement) return "인성";
  return "비겁";
}

function splitPillar(p: string): { stem: string; branch: string } {
  return { stem: p.charAt(0), branch: p.charAt(1) };
}

/** 실제 달력 공식(1984=갑자년) — 해시/랜덤 아님. */
function yearGanji(year: number): string {
  const stemIdx = ((year - 4) % 10 + 10) % 10;
  const branchIdx = ((year - 4) % 12 + 12) % 12;
  return `${STEMS_ORDER[stemIdx]}${BRANCHES_ORDER[branchIdx]}`;
}

const SEWOON_KEYWORD_BY_TENGOD: Record<string, string> = {
  비겁: "협력과 경쟁이 함께 오는 해",
  식상: "표현과 확장의 해",
  재성: "결실과 관리가 함께 필요한 해",
  관성: "책임과 성취가 따르는 해",
  인성: "배움과 재정비의 해",
};

export interface BuildSajuJudgmentInput {
  birthDate: string; // "YYYY-MM-DD"
  birthTime: string | null;
  gender: string; // "M" | "F" | 기타
  isLunar: boolean;
  pillars: { year: string; month: string; day: string; hour: string | null };
  seed: number;
}

export function buildSajuJudgment({
  birthDate,
  birthTime,
  gender,
  pillars,
  seed,
}: BuildSajuJudgmentInput): SajuJudgment {
  const dayStem = splitPillar(pillars.day).stem;
  const dmElement = STEM_ELEMENT[dayStem] ?? "목";

  // ── 간지 8자(년/월/일/시 각 간+지)를 오행/십신으로 분류 ──
  const chars: string[] = [];
  for (const p of [pillars.year, pillars.month, pillars.day, pillars.hour]) {
    if (!p) continue;
    const { stem, branch } = splitPillar(p);
    chars.push(stem, branch);
  }

  const elementsRatio: Record<string, number> = {
    목: 0,
    화: 0,
    토: 0,
    금: 0,
    수: 0,
  };
  const tenGodsCount: Record<string, number> = {
    비겁: 0,
    식상: 0,
    재성: 0,
    관성: 0,
    인성: 0,
  };

  chars.forEach((ch, idx) => {
    // 짝수 인덱스=천간(STEM_ELEMENT), 홀수 인덱스=지지(BRANCH_ELEMENT)
    const element =
      idx % 2 === 0 ? STEM_ELEMENT[ch] : BRANCH_ELEMENT[ch];
    if (!element) return;
    elementsRatio[element] = (elementsRatio[element] ?? 0) + 1;
    const tg = classifyTenGod(dmElement, element);
    tenGodsCount[tg] = (tenGodsCount[tg] ?? 0) + 1;
  });

  // ── 카테고리별 판정(§4-1 근거 배분표: 재물=재성·비겁 / 관계=관성·인성 /
  //    직업=식상·인성 / 건강=오행 편중) ──
  const wealth = tenGodsCount["재성"];
  const biGeop = tenGodsCount["비겁"];
  const wealthVerdict: SajuVerdictEntry =
    wealth >= 1 && biGeop >= wealth
      ? {
          grade: "caution",
          primary_evidence: `재성 ${wealth} · 비겁 ${biGeop}`,
          hook: "들어오는 길목은 넓고, 새는 자리도 있음",
        }
      : wealth >= 1
      ? {
          grade: "good",
          primary_evidence: `재성 ${wealth} · 비겁 ${biGeop}`,
          hook: "재물을 다루는 힘이 안정적으로 자리잡음",
        }
      : {
          grade: "neutral",
          primary_evidence: `재성 ${wealth} · 비겁 ${biGeop}`,
          hook: "무리하지 않는 흐름 속에서 조금씩 쌓아가는 편",
        };

  const gwanSeong = tenGodsCount["관성"];
  const inSeong = tenGodsCount["인성"];
  const relationVerdict: SajuVerdictEntry =
    gwanSeong >= 1 && inSeong >= 1
      ? {
          grade: "good",
          primary_evidence: `관성 ${gwanSeong} · 인성 ${inSeong}`,
          hook: "기준이 분명해 신뢰를 얻는 편",
        }
      : gwanSeong === 0 && inSeong === 0
      ? {
          grade: "caution",
          primary_evidence: `관성 ${gwanSeong} · 인성 ${inSeong}`,
          hook: "관계에서 기준을 스스로 정해야 흔들리지 않음",
        }
      : {
          grade: "neutral",
          primary_evidence: `관성 ${gwanSeong} · 인성 ${inSeong}`,
          hook: "관계의 속도를 스스로 조절하는 편",
        };

  const sikSang = tenGodsCount["식상"];
  const careerVerdict: SajuVerdictEntry =
    sikSang >= 1 || inSeong >= 1
      ? {
          grade: "good",
          primary_evidence: `식상 ${sikSang} · 인성 ${inSeong}`,
          hook: "배운 것을 표현으로 바꾸는 데 강함",
        }
      : {
          grade: "neutral",
          primary_evidence: `식상 ${sikSang} · 인성 ${inSeong}`,
          hook: "꾸준함으로 성과를 만들어가는 편",
        };

  const elementValues = Object.values(elementsRatio);
  const maxEl = Math.max(...elementValues);
  const minEl = Math.min(...elementValues);
  const zeroElements = Object.entries(elementsRatio)
    .filter(([, v]) => v === 0)
    .map(([k]) => k);
  const dominantElement = Object.entries(elementsRatio).sort(
    (a, b) => b[1] - a[1]
  )[0][0];
  const healthVerdict: SajuVerdictEntry =
    zeroElements.length > 0 || maxEl - minEl >= 3
      ? {
          grade: "caution",
          primary_evidence:
            zeroElements.length > 0
              ? `${zeroElements.join("·")} 0 · ${dominantElement} ${maxEl}`
              : `${dominantElement} ${maxEl} 편중`,
          hook: "회복이 느려지는 시기가 생기기 쉬움",
        }
      : {
          grade: "good",
          primary_evidence: `오행 분포 고른 편(최대-최소=${maxEl - minEl})`,
          hook: "컨디션 기복이 크지 않은 편",
        };

  // ── flow.sewoon: 실제 달력 공식(해시 아님) ──
  const currentYear = new Date().getFullYear();
  const sewoonGanji = yearGanji(currentYear);
  const sewoonElement = STEM_ELEMENT[splitPillar(sewoonGanji).stem] ?? "목";
  const sewoonTg = classifyTenGod(dmElement, sewoonElement);

  // ── flow.daewoon: [범위 밖 — 근사치] 실제 대운수(절입일수÷3, 순역 규칙)를
  //    계산할 만세력 인프라가 없어 seed로 그럴듯한 시작 나이만 생성한다.
  //    실제 정통사주(jeontong_eighty) 엔진과 달리 이 AI 사주 경로는 애초에
  //    computeChart() 자체가 결정론적 해시이므로, 대운도 동일 선상의 근사치다.
  const startAge = 3 + (seed % 7); // 3~9세 (실제 분포와 유사한 범위)
  const daewoonGanji = `${STEMS_ORDER[(seed + 5) % 10]}${
    BRANCHES_ORDER[(seed + 7) % 12]
  }`;
  const birthYear = parseInt(birthDate.slice(0, 4), 10) || currentYear - 30;
  const cyclesPassed = Math.max(
    0,
    Math.floor((currentYear - (birthYear + startAge)) / 10)
  );
  const until = birthYear + startAge + (cyclesPassed + 1) * 10;

  return {
    birth: {
      solar: birthTime ? `${birthDate} ${birthTime}` : birthDate,
      gender,
      truesolar_applied: false,
    },
    pillars,
    day_master: {
      stem: dayStem,
      element: dmElement,
      note: DAY_MASTER_NOTE[dayStem] ?? "고유한 기질을 지닌 편",
    },
    ten_gods_count: tenGodsCount,
    elements_ratio: elementsRatio,
    verdict: {
      wealth: wealthVerdict,
      relation: relationVerdict,
      career: careerVerdict,
      health: healthVerdict,
    },
    flow: {
      daewoon: { start_age: startAge, current: daewoonGanji, until },
      sewoon: {
        year: currentYear,
        ganji: sewoonGanji,
        keyword: SEWOON_KEYWORD_BY_TENGOD[sewoonTg] ?? "변화가 찾아오는 해",
      },
    },
  };
}
