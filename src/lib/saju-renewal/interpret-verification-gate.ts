// [정통사주 LLM 해석 공통 스펙 v2.0 — §8 전 주제 공통 검증 게이트] TK-2 구현.
//
// [포팅 출처] saju-handoff-spec.pdf §8.3 "예시 코드(레퍼런스 구현 · 실행 검증 완료)"의
// Python 코드(run_gate/Violation/Engine/Daeun dataclass, AGE_RANGE_RE/AGE_RE/YEAR_RE/
// extract_ganzhi 등)를 TypeScript로 그대로 포팅한다. §8.1 검증표의 11개 코드 중
// 8개(AGE_OUT_OF_RANGE, AGE_RANGE_NOT_A_DAEUN, YEAR_OUT_OF_LIFE,
// YEAR_NOT_A_DAEUN_BOUNDARY, GANZHI_NOT_IN_ENGINE, YONGSIN_HALLUCINATION,
// ANCHOR_DAEUN_MISSING, ANCHOR_AGE_MISSING)는 Python 레퍼런스를 1:1로 포팅했다.
// 나머지 3개(SINSAL_HALLUCINATION, TOPIC_PREMISE_NOT_IN_FACTS,
// PREMISE_TENSE_MISMATCH)는 §8.3에 실행 가능한 레퍼런스 코드가 없고 §5.4/§5.5/§5.6/
// §8.1 표의 규칙 설명만 존재하므로, 그 규칙 설명을 그대로 구현한 최초 구현이다
// (아래 각 함수 주석에 근거 조항을 명시).
//
// [엔진 재계산 금지] 이 파일은 LLM이 생성한 텍스트(narrative)를 facts/finding과
// 대조만 할 뿐, 사주를 다시 계산하지 않는다(§4-C1과 동일 원칙을 검증 단계에도 적용).
import type { SajuV3Facts } from "./saju-facts-types";
import { buildDaeunTimeline, type DaeunTense, type DaeunTimelineEntry } from "./daeun-timeline";
import type { Finding } from "./finding-detector";

// ════════════════════════════════════════════════════════════════
// §8.1 검증 코드 전체(11개) — PDF 표 그대로. "NO_CURRENT_DAEUN"은 §8.1 표에는 없지만
// Python 레퍼런스 run_gate()가 "엔진에서 현재 대운을 찾을 수 없음" 상황을 별도로
// 방출하므로(엔진 데이터 결함 신호), 운영상 숨기지 않고 그대로 포팅해 둔다.
// ════════════════════════════════════════════════════════════════
export type ViolationCode =
  | "AGE_OUT_OF_RANGE"
  | "AGE_RANGE_NOT_A_DAEUN"
  | "YEAR_OUT_OF_LIFE"
  | "YEAR_NOT_A_DAEUN_BOUNDARY"
  | "GANZHI_NOT_IN_ENGINE"
  | "YONGSIN_HALLUCINATION"
  | "SINSAL_HALLUCINATION"
  | "ANCHOR_DAEUN_MISSING"
  | "ANCHOR_AGE_MISSING"
  | "TOPIC_PREMISE_NOT_IN_FACTS"
  | "PREMISE_TENSE_MISMATCH"
  | "NO_CURRENT_DAEUN";

/** §8.1 표의 "심각도" 컬럼 — 차단(block) 코드는 재생성을 트리거하고, 경고(warn)
 * 코드는 재생성을 트리거하지 않는다(§8.1: YEAR_NOT_A_DAEUN_BOUNDARY만 "경고"). */
export const VIOLATION_SEVERITY: Record<ViolationCode, "block" | "warn"> = {
  AGE_OUT_OF_RANGE: "block",
  AGE_RANGE_NOT_A_DAEUN: "block",
  YEAR_OUT_OF_LIFE: "block",
  YEAR_NOT_A_DAEUN_BOUNDARY: "warn",
  GANZHI_NOT_IN_ENGINE: "block",
  YONGSIN_HALLUCINATION: "block",
  SINSAL_HALLUCINATION: "block",
  ANCHOR_DAEUN_MISSING: "block",
  ANCHOR_AGE_MISSING: "block",
  TOPIC_PREMISE_NOT_IN_FACTS: "block",
  PREMISE_TENSE_MISMATCH: "block",
  NO_CURRENT_DAEUN: "warn",
};

export interface Violation {
  code: ViolationCode;
  detail: string;
  excerpt: string;
}

/** §8.5 게이트 프로파일 — 주제의 gate_profile 한 줄로 어떤 확장 검사를 적용할지 정한다.
 * multi_subject(궁합)는 이 함수가 처리하지 않는다 — 호출부가 subject_id별로 facts/
 * text를 분리해 이 게이트를 2회(또는 N회) 호출해야 한다(§8.5 "대상별 분리 검증"). */
export type GateProfile = "default" | "time_scoped" | "no_time" | "multi_subject" | "sinsal";

export interface GateTopicInput {
  topicId: string;
  /** §5.3 topic 스키마의 premise_ref — 이 주제의 전제가 되는 finding_id. 없으면(시기
   * 무관 주제) TOPIC_PREMISE_NOT_IN_FACTS/PREMISE_TENSE_MISMATCH 검사를 건너뛴다. */
  premiseRef?: string | null;
  /** §5.3 time_scoped — true면 §4-C2 앵커링(ANCHOR_DAEUN_MISSING/ANCHOR_AGE_MISSING)을
   * 강제한다(Python 레퍼런스의 strict_anchor와 동일). */
  timeScoped: boolean;
  gateProfile: GateProfile;
}

export interface GateInput {
  facts: SajuV3Facts;
  topic: GateTopicInput;
  /** §5.6 "topic.premise_ref → finding → facts 경로" 대조에 쓰는 전체 findings
   * (보통 finding-detector.ts의 detectFindings(facts) 결과를 그대로 전달). */
  findings: Finding[];
  text: string;
}

// ────────────────────────────────────────────────────────────────
// §8.3 Python 레퍼런스 "GAN/ZHI/all_ganzhi/GANZHI_SET" 포팅.
// 레퍼런스는 한자(漢字) 60갑자만 다루지만, 우리 LLM 응답은 한국어 서술이라 한글
// 간지("정축")로 쓰일 가능성이 더 높다. 그래서 한자·한글 60갑자 집합을 모두 만들어
// 합집합으로 검사한다(레퍼런스의 의도 — "엔진 목록에 없는 간지 차단" — 를 한국어
// 출력 환경에 맞게 확장한 것일 뿐, 판정 로직 자체는 그대로다).
// ────────────────────────────────────────────────────────────────
const GAN_HANJA = "甲乙丙丁戊己庚辛壬癸";
const ZHI_HANJA = "子丑寅卯辰巳午未申酉戌亥";
const GAN_HANGUL = "갑을병정무기경신임계";
const ZHI_HANGUL = "자축인묘진사오미신유술해";

function allGanzhi(ganStr: string, zhiStr: string): string[] {
  const out: string[] = [];
  for (let i = 0; i < 60; i++) {
    out.push(ganStr[i % 10] + zhiStr[i % 12]);
  }
  return out;
}

const GANZHI_SET = new Set<string>([...allGanzhi(GAN_HANJA, ZHI_HANJA), ...allGanzhi(GAN_HANGUL, ZHI_HANGUL)]);

/** Python extract_ganzhi(text) 포팅 — 본문에서 "유효한 60갑자 2글자" 부분문자열을
 * 전부 추출한다(한자/한글 모두 인식). */
function extractGanzhi(text: string): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length - 1; i++) {
    const pair = text.slice(i, i + 2);
    if (GANZHI_SET.has(pair)) out.push(pair);
  }
  return out;
}

// §8.3 레퍼런스의 AGE_RANGE_RE / AGE_RE / YEAR_RE 포팅. 한국어 숫자+세 표기(예:
// "44~53세", "44-53세", "44–53세")를 모두 받는다.
const AGE_RANGE_RE = /(\d{1,3})\s*(?:세)?\s*[~\-–]\s*(\d{1,3})\s*세/g;
const AGE_RE = /(\d{1,3})\s*세/g;
const YEAR_RE = /(?<!\d)(19\d{2}|20\d{2})(?!\d)/g;

// §8.3 OROHIN_KR(오행 한글↔한자 매핑) 포팅.
const ELEMENT_KR_TO_HANJA: Record<string, string> = { 금: "金", 목: "木", 수: "水", 화: "火", 토: "土" };

/**
 * [내부 유틸] facts.luck_pillars(→buildDaeunTimeline)로부터 "엔진 산출값" 집합을
 * 만든다 — Python의 Engine/Daeun dataclass 역할을 facts에서 직접 파생해 대체한다
 * (별도 엔진 재계산 없음, daeun-timeline.ts를 단일 소스로 재사용).
 */
interface EngineView {
  birthYear: number | null;
  dayPillarHangul: string | null;
  dayPillarHanja: string | null;
  entries: DaeunTimelineEntry[];
  currentEntry: DaeunTimelineEntry | null;
  currentAge: number | null;
  /** §4-C4 "오행·용신은 FACT 값만" — 용신+희신을 "필요로 하는 기운" 허용 집합으로
   * 합친다(§8.3 데모의 yongsin=["木","水"]가 용신+희신 조합인 것과 동일 해석). */
  allowedElements: string[]; // 한글 오행("목","화","토","금","수") 집합
  sinsalList: string[]; // facts.sinsal 원문 그대로(한자+한글 혼합 문자열)
}

function buildEngineView(facts: SajuV3Facts): EngineView {
  const timeline = buildDaeunTimeline(facts);
  // birth_year 역산: luck_pillars 각 원소는 "start_year = birth_year + start_age - 1"
  // 관계를 만족한다(세는나이 정의) — 별도 입력 파싱 없이 이미 계산된 값에서 역산한다.
  const first = timeline.entries[0];
  const birthYear = first ? first.startYear - first.startAge + 1 : null;

  const dayPillarHangul = facts.pillars?.day?.kr ?? null;
  const dayPillarHanja =
    facts.pillars?.day?.gan && facts.pillars?.day?.zhi ? `${facts.pillars.day.gan}${facts.pillars.day.zhi}` : null;

  const allowedElements = Array.from(
    new Set([facts.yongshin?.yong, facts.yongshin?.hee].filter((v): v is string => !!v))
  );

  return {
    birthYear,
    dayPillarHangul,
    dayPillarHanja,
    entries: timeline.entries,
    currentEntry: timeline.currentEntry,
    currentAge: timeline.currentAge,
    allowedElements,
    sinsalList: facts.sinsal ?? [],
  };
}

// ════════════════════════════════════════════════════════════════
// §8.3 run_gate() 1:1 포팅 (1~6단계) + §8.1 나머지 3개 코드(7~9단계, 최초 구현)
// ════════════════════════════════════════════════════════════════

/** 1) 나이 단독 주장 범위 검사 — Python run_gate() 1단계 그대로. */
function checkAgeOutOfRange(text: string, violations: Violation[]): void {
  for (const m of text.matchAll(AGE_RE)) {
    const age = parseInt(m[1], 10);
    if (!(age >= 1 && age <= 120)) {
      violations.push({ code: "AGE_OUT_OF_RANGE", detail: `${age}세는 유효 범위(1~120)를 벗어남`, excerpt: m[0] });
    }
  }
}

/** 2) 나이 '구간'은 반드시 실제 대운 스팬에 정렬되어야 한다 — Python 2단계 그대로
 * (±1 허용, 또는 한 대운 구간에 완전히 포함되는 경우도 허용). */
function checkAgeRangeAlignment(text: string, engine: EngineView, violations: Violation[]): void {
  const spans = engine.entries.map((e) => [e.startAge, e.endAge] as [number, number]);
  for (const m of text.matchAll(AGE_RANGE_RE)) {
    let a = parseInt(m[1], 10);
    let b = parseInt(m[2], 10);
    if (a > b) [a, b] = [b, a];
    const aligned =
      spans.some(([s, e]) => Math.abs(a - s) <= 1 && Math.abs(b - e) <= 1) ||
      spans.some(([s, e]) => s <= a && b <= e);
    if (!aligned) {
      violations.push({
        code: "AGE_RANGE_NOT_A_DAEUN",
        detail: `${a}~${b}세 구간이 어떤 대운(${JSON.stringify(spans)})과도 대응하지 않음`,
        excerpt: m[0],
      });
    }
  }
}

/** 3) 연도 주장은 생애 범위 안이어야 하고, '대운 경계'와 어긋나면 경고 — Python 3단계
 * 그대로. birthYear를 모르면(엔진 데이터 부족) 이 검사 전체를 건너뛴다(facts-only
 * 원칙상 근거 없는 판정을 내리지 않음). */
function checkYearClaims(text: string, engine: EngineView, violations: Violation[]): void {
  if (engine.birthYear === null) return;
  const validYears = new Set<number>();
  for (const e of engine.entries) {
    validYears.add(e.startYear);
    validYears.add(e.endYear);
  }
  for (const m of text.matchAll(YEAR_RE)) {
    const y = parseInt(m[1], 10);
    if (!(y >= engine.birthYear && y <= engine.birthYear + 120)) {
      violations.push({ code: "YEAR_OUT_OF_LIFE", detail: `${y}년이 생애 범위를 벗어남`, excerpt: m[0] });
    } else if (validYears.size > 0 && !validYears.has(y)) {
      violations.push({
        code: "YEAR_NOT_A_DAEUN_BOUNDARY",
        detail: `${y}년은 대운 경계 연도(${JSON.stringify([...validYears].sort((a, b) => a - b))})가 아님`,
        excerpt: m[0],
      });
    }
  }
}

/** 4) '대운'/'일주' 문맥과 함께 등장한 간지는 엔진 목록에 있어야 함 — Python 4단계
 * 그대로(윈도우 ±20자 안에 "대운" 또는 "일주"가 있을 때만 검사 — 문맥 없는 간지
 * 2글자 우연 일치는 오탐 방지를 위해 무시). */
function checkGanzhiInEngine(text: string, engine: EngineView, violations: Violation[]): void {
  const daeunSet = new Set<string>();
  for (const e of engine.entries) {
    daeunSet.add(e.ganZhiKr);
    if (e.ganZhi) daeunSet.add(e.ganZhi);
  }
  if (engine.dayPillarHangul) daeunSet.add(engine.dayPillarHangul);
  if (engine.dayPillarHanja) daeunSet.add(engine.dayPillarHanja);

  for (const gz of extractGanzhi(text)) {
    if (daeunSet.has(gz)) continue;
    const idx = text.indexOf(gz);
    const window = text.slice(Math.max(0, idx - 20), idx + 20);
    if (window.includes("대운") || window.includes("일주")) {
      violations.push({
        code: "GANZHI_NOT_IN_ENGINE",
        detail: `'${gz}'가 엔진 대운/일주 목록에 없음(허위 간지 의심)`,
        excerpt: window,
      });
    }
  }
}

/** 5) 용신/보충 오행 주장은 엔진 값만 허용(환각 오행 차단) — Python 5단계 그대로,
 * 한글/한자 양쪽 표기를 모두 검사한다. */
function checkYongsinHallucination(text: string, engine: EngineView, violations: Violation[]): void {
  if (engine.allowedElements.length === 0) return;
  const CONTEXT = ["필요로 하는", "필요한", "용신", "보충", "채워", "부족", "공급되"];
  const pairs: [string, string][] = [
    ...Object.entries(ELEMENT_KR_TO_HANJA),
    ...Object.values(ELEMENT_KR_TO_HANJA).map((hj) => [hj, hj] as [string, string]),
  ];
  for (const [form, hj] of pairs) {
    const kr = Object.keys(ELEMENT_KR_TO_HANJA).find((k) => ELEMENT_KR_TO_HANJA[k] === hj) ?? hj;
    let searchIdx = 0;
    while (true) {
      const i = text.indexOf(form, searchIdx);
      if (i === -1) break;
      searchIdx = i + form.length;
      const w = text.slice(Math.max(0, i - 25), i + 15);
      if (CONTEXT.some((c) => w.includes(c)) && !engine.allowedElements.includes(kr)) {
        violations.push({
          code: "YONGSIN_HALLUCINATION",
          detail: `'${form}(${kr})'은 엔진 용신(${JSON.stringify(engine.allowedElements)})에 없음`,
          excerpt: w,
        });
      }
    }
  }
}

/** 6) [필수] 현재 대운 앵커링 — Python 6단계 그대로. topic.timeScoped(=strict_anchor)
 * 일 때만 적용한다. */
function checkCurrentAnchor(text: string, engine: EngineView, strictAnchor: boolean, violations: Violation[]): void {
  if (!strictAnchor) return;
  const cur = engine.currentEntry;
  if (!cur) {
    violations.push({ code: "NO_CURRENT_DAEUN", detail: "엔진에서 현재 대운을 찾을 수 없음", excerpt: "" });
    return;
  }
  const hasGanzhi = text.includes(cur.ganZhiKr) || (cur.ganZhi ? text.includes(cur.ganZhi) : false);
  if (!hasGanzhi) {
    violations.push({
      code: "ANCHOR_DAEUN_MISSING",
      detail: `현재 대운 간지 '${cur.ganZhiKr}'가 본문에 없음(앵커링 누락)`,
      excerpt: "",
    });
  }
  const ca = engine.currentAge;
  if (ca !== null) {
    const ages = [...text.matchAll(AGE_RE)].map((m) => parseInt(m[1], 10));
    const hasAge = ages.some((a) => Math.abs(a - ca) <= 1);
    if (!hasAge) {
      violations.push({
        code: "ANCHOR_AGE_MISSING",
        detail: `현재 나이(약 ${ca}세) 언급이 본문에 없음(앵커링 누락)`,
        excerpt: "",
      });
    }
  }
}

// ────────────────────────────────────────────────────────────────
// 7~9) §8.1 표에는 있으나 §8.3에 실행 가능한 레퍼런스 코드가 없는 3개 — §5.4/§5.5/
// §5.6 규칙 설명을 그대로 구현한 최초 구현. (PDF 원문에 Python 코드가 없으므로
// "포팅"이 아니라 "신규 구현"임을 주석으로 명시한다.)
// ────────────────────────────────────────────────────────────────

/** [SINSAL_HALLUCINATION — §5.5 "finding SINSAL_*의 facts.sinsal만 인용"] gateProfile
 * === "sinsal"일 때만 적용. facts.sinsal에 없는 신살명이 본문에 등장하면 차단한다.
 * facts.sinsal 원문은 "天乙貴人(천을귀인)" 형태(한자(한글))이므로 괄호 안 한글만
 * 추출해 허용집합으로 쓴다. 본문에서 찾을 "알려진 신살명" 목록은 이 앱이 쓰는
 * saju_engine이 산출 가능한 대표 신살 명칭(만세력 공통 용어)으로 구성했다 — PDF에
 * 전체 목록이 없으므로 가장 널리 쓰이는 명칭들로 커버리지를 확보한 것이며, 새
 * 신살명이 엔진에 추가되면 이 목록도 함께 갱신해야 한다. */
const KNOWN_SINSAL_NAMES_KR = [
  "천을귀인", "화개", "역마", "도화", "양인", "괴강", "백호", "원진", "귀문", "공망",
  "홍염", "문창귀인", "태극귀인", "금여", "암록", "월덕귀인", "천덕귀인", "상문", "조객", "현침",
];

function extractAllowedSinsalKr(sinsalList: string[]): Set<string> {
  const out = new Set<string>();
  for (const s of sinsalList) {
    const m = s.match(/\(([^)]+)\)/);
    if (m) out.add(m[1]);
    else out.add(s); // 괄호 형식이 아니면 원문 그대로도 허용 집합에 포함
  }
  return out;
}

function checkSinsalHallucination(text: string, engine: EngineView, gateProfile: GateProfile, violations: Violation[]): void {
  if (gateProfile !== "sinsal") return;
  const allowed = extractAllowedSinsalKr(engine.sinsalList);
  for (const name of KNOWN_SINSAL_NAMES_KR) {
    if (text.includes(name) && !allowed.has(name)) {
      const idx = text.indexOf(name);
      violations.push({
        code: "SINSAL_HALLUCINATION",
        detail: `'${name}'은 엔진 sinsal 목록(${JSON.stringify([...allowed])})에 없음`,
        excerpt: text.slice(Math.max(0, idx - 15), idx + 15),
      });
    }
  }
}

/** [TOPIC_PREMISE_NOT_IN_FACTS — §5.6] "topic.premise_ref → finding → facts" 경로로
 * 전제가 실재하는지 확인한다. premiseRef가 없는 주제(시기 무관)는 검사 대상이
 * 아니다(§1 매트릭스 "성격·기질: 앵커링 면제 가능"과 동일 취지). */
function findPremise(findings: Finding[], premiseRef: string | null | undefined): Finding | null {
  if (!premiseRef) return null;
  return findings.find((f) => f.finding_id === premiseRef) ?? null;
}

function checkTopicPremiseInFacts(topic: GateTopicInput, findings: Finding[], violations: Violation[]): Finding | null {
  if (!topic.premiseRef) return null;
  const premise = findPremise(findings, topic.premiseRef);
  if (!premise) {
    violations.push({
      code: "TOPIC_PREMISE_NOT_IN_FACTS",
      detail: `premise_ref '${topic.premiseRef}'가 facts.findings에 없음`,
      excerpt: "",
    });
  }
  return premise;
}

/** [PREMISE_TENSE_MISMATCH — §5.4 표] finding.tense에 따라 허용되는 서술 시제 표현이
 * 본문에 있어야 한다: past→"이미 지난"류, now→"지금"류, future→"앞으로"류. 이
 * finding의 구간(span.ganzhi)이 본문에 실제로 언급된 경우에만 검사한다(언급되지
 * 않은 finding까지 시제를 강제하면 과검출되므로 — §5.4 "본문이 인용하는 구간·
 * 간지·오행은 그 finding의 evidence_refs만"이라는 전제하에, 언급 시에만 시제
 * 일치를 요구). */
const TENSE_PHRASES: Record<DaeunTense, string[]> = {
  past: ["지난", "이미 지난", "지나온", "과거"],
  now: ["지금", "현재", "지금 당신은"],
  future: ["앞으로", "향후", "다가올", "다가올 구간"],
};

function checkPremiseTenseMismatch(text: string, premise: Finding | null, violations: Violation[]): void {
  if (!premise) return;
  const mentioned = text.includes(premise.span.ganzhi);
  if (!mentioned) return; // 본문이 이 finding을 아예 언급하지 않으면 시제 대조 불가/불필요
  const allowedPhrases = TENSE_PHRASES[premise.tense];
  const hasTensePhrase = allowedPhrases.some((p) => text.includes(p));
  if (!hasTensePhrase) {
    violations.push({
      code: "PREMISE_TENSE_MISMATCH",
      detail: `finding.tense='${premise.tense}'인데 본문에 해당 시제 표현(${JSON.stringify(allowedPhrases)})이 없음`,
      excerpt: text.slice(0, 60),
    });
  }
}

/**
 * [메인 엔트리 — TK-2] §8.2 처리 흐름의 "[검증 게이트]" 박스 전체를 구현한다.
 * facts·topic(전제 finding 포함)·findings·LLM 출력 텍스트를 받아 위반 목록을
 * 반환한다. 위반이 비어 있으면 게시, 1건 이상이면 호출부(interpret-service.ts)가
 * §8.6 재생성 루프를 수행한다(이 함수 자체는 재시도하지 않는 순수 함수).
 */
export function runVerificationGate(input: GateInput): Violation[] {
  const { facts, topic, findings, text } = input;
  const engine = buildEngineView(facts);
  const violations: Violation[] = [];

  checkAgeOutOfRange(text, violations);
  checkAgeRangeAlignment(text, engine, violations);
  checkYearClaims(text, engine, violations);
  checkGanzhiInEngine(text, engine, violations);
  checkYongsinHallucination(text, engine, violations);

  // §8.5: time_scoped 프로파일(또는 topic.timeScoped=true)일 때만 앵커링 강제.
  // no_time 프로파일은 앵커 검사는 면제하되(Python strict_anchor=false와 동일)
  // 위 1~5단계(나이/연도/간지/오행 대조)는 "언급 시 대조"로 그대로 적용된다
  // (§8.5 "no_time: 앵커 검사 면제(단, 언급 시 나이/연도는 대조)").
  const strictAnchor = topic.gateProfile === "time_scoped" || (topic.timeScoped && topic.gateProfile !== "no_time");
  checkCurrentAnchor(text, engine, strictAnchor, violations);

  checkSinsalHallucination(text, engine, topic.gateProfile, violations);

  const premise = checkTopicPremiseInFacts(topic, findings, violations);
  checkPremiseTenseMismatch(text, premise, violations);

  return violations;
}

/** 차단(block) 등급 위반만 걸러낸다 — §8.6 실패 정책은 "위반 ≥1건 → 재생성"이라고
 * 쓰여 있지만 §8.1 표에서 YEAR_NOT_A_DAEUN_BOUNDARY/NO_CURRENT_DAEUN은 "경고"로
 * 명시했으므로, 재생성 트리거 여부는 이 필터를 거친 결과로 판단한다. */
export function hasBlockingViolations(violations: Violation[]): boolean {
  return violations.some((v) => VIOLATION_SEVERITY[v.code] === "block");
}

/** Python generate_with_gate()의 feedback 포맷팅 라인 포팅 — 재생성 프롬프트에
 * 그대로 덧붙일 문자열 배열을 만든다. */
export function formatViolationsForFeedback(violations: Violation[]): string[] {
  return violations.map((v) => `- [${v.code}] ${v.detail} (근거: '${v.excerpt}')`);
}
