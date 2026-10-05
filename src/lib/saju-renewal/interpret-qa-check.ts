// [정통사주 리뉴얼 v1.0 — STEP 4] Interpret 전용 서버 QA 검증.
//
// [기존 saju-qa-check.ts와 분리하는 이유] 기존 모듈은 레거시 69종 "7블록"
// (headline/sections/actions/closing/evidence_used) 구조 전용이다. STEP 4는
// docs/11_API_계약서.md §3이 고정한 전혀 다른 계약(summary: title+summary+evidence,
// detail: blocks[n=1..5])을 쓰므로, 같은 파일을 억지로 재사용하지 않고 새로 작성한다
// (2025 진행 승인 지시 STEP4 §14 "LLM 응답 후 서버 QA 필수"의 전용 구현체).
//
// [검증 항목 — STEP4 §14 원문 그대로]
//   구조: summary/detail 형식 정상 + 필수 필드 존재
//   분량: detail 1,500~2,500자(목표 1,800~2,200자) — 단순 길이뿐 아니라 "내용 품질"도 검증
//   내용: 선택 Topic과 일치 / FACT 밖의 사실 최소화 / 근거 없는 시기 없음
//   보안: 내부 Topic ID 없음 / 69종 코드 없음 / score·evaluator·DB 정보 없음 / "AI" 표현 없음
//
// [이 파일의 책임 범위] 이 파일은 "LLM이 이미 생성한 텍스트"를 검사만 한다 — 프롬프트
// 구성(interpret-prompt.ts)이나 LLM 호출(llm-client.ts)에는 관여하지 않는다.

export interface InterpretEvidence {
  type: "grid" | "elements" | "luck";
  cols?: number[];
  hl?: string | number;
  text: string;
}

export interface InterpretSummaryResult {
  topic_id: string;
  title: string;
  summary: string;
  evidence: InterpretEvidence;
  source: "llm" | "template";
}

export interface InterpretDetailBlock {
  n: 1 | 2 | 3 | 4 | 5;
  body: string;
  evidence?: InterpretEvidence;
  timing?: { luck_index: number };
}

export interface InterpretDetailResult {
  topic_id: string;
  title: string;
  blocks: InterpretDetailBlock[];
  source: "llm" | "template";
}

export interface QaCheckOptions {
  /** LLM이 생성한 topic_id가 실제 요청받은 topic_id와 같은지 비교하기 위한 기준값. */
  expectedTopicId: string;
  /** 시기(timing) 정보를 담을 수 있는 주제인지 — false면 n=4 블록 자체가 있으면 안 됨
   * (STEP4 §10 "시기 표현은 FACT 있을 때만", docs/07 E-14 "시기 Fact 없는 주제 → ④ 블록 생략"). */
  isTiming: boolean;
  /** detail 전용 — 서버 프롬프트가 실제로 사용한 termKey 화이트리스트(docs/06 §3).
   * 미등록 termKey가 `[[term|...]]` 마크업으로 등장하면 실패 처리(§9 FACT 밖 이야기 방지와
   * 별개로, 디자인 계약 docs/11 §3 "termKey가 사전에 존재" 요구사항). */
  knownTermKeys?: string[];
}

export const DETAIL_MIN_LENGTH = 1500;
export const DETAIL_MAX_LENGTH = 2500;
export const DETAIL_TARGET_MIN = 1800;
export const DETAIL_TARGET_MAX = 2200;

// [STEP4 §11 내부 정보 절대 노출 금지] 69종/내부코드/DB/평가자 용어. 대소문자 무시.
const INTERNAL_LEAK_PATTERNS: RegExp[] = [
  /\b69\s*종/i,
  /\bE0?\d{1,2}\b/, // E01, E1, E09 등 엣지케이스 코드
  /\bG0?\d{1,2}\b/, // G09 등
  /\bA0?\d{1,2}\b/, // A01, A02 등 근거 코드
  /\bB0?\d{1,2}\b/, // B01, B08, B10 등
  /\b[A-Z]+_\d{3}\b/, // PERSONALITY_001, MONEY_002 등 topic_id 패턴 전부
  /\bevaluator\b/i,
  /\bcategoryGroup\b/i,
  /\bconditionType\b/i,
  /\bfact\s*key\b/i,
  /\bDB\s*id\b/i,
  /\btopic\s*id\b/i,
  /\bscore\b/i,
  /\bconfidence\b/i,
];

// [STEP4 §12 "AI" 표현 금지] "AI"뿐 아니라 "인공지능" 등 동의어까지 포함.
const AI_WORD_PATTERNS: RegExp[] = [/\bAI\b/, /인공지능/, /에이아이/];

export interface QaFailure {
  code: string;
  message: string;
}

export interface QaCheckResult {
  ok: boolean;
  failures: QaFailure[];
}

function fail(failures: QaFailure[], code: string, message: string) {
  failures.push({ code, message });
}

/** 문자열에서 한글/영문/숫자만 남긴 "순수 본문 길이"를 잰다(공백은 포함해 사용자 체감
 * 분량에 가깝게 계산 — 마크업 `[[ ]]`는 화면에서 치환되므로 길이 계산에서 제외). */
function stripMarkup(text: string): string {
  return text.replace(/\[\[([^\]|]+)(\|[^\]]*)?\]\]/g, (_m, _key, display) =>
    display ? display.slice(1) : ""
  );
}

function visibleLength(text: string): number {
  return stripMarkup(text).length;
}

/** `[[termKey|쉬운 표현]]` 또는 `[[termKey]]` 패턴을 전부 추출한다. */
function extractTermKeys(text: string): string[] {
  const keys: string[] = [];
  const re = /\[\[([^\]|]+)(?:\|[^\]]*)?\]\]/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) {
    keys.push(m[1].trim());
  }
  return keys;
}

/** `[[`, `]]` 짝이 맞는지(개수 일치 + 교차 중첩 없음)만 간단히 검증한다. */
function hasUnbalancedMarkup(text: string): boolean {
  const openCount = (text.match(/\[\[/g) ?? []).length;
  const closeCount = (text.match(/\]\]/g) ?? []).length;
  return openCount !== closeCount;
}

/** 금지어/내부정보/AI표현 공통 검사(summary·detail 모든 본문 텍스트에 적용). */
function checkSecurityAndBanned(text: string, label: string, failures: QaFailure[]) {
  for (const pattern of INTERNAL_LEAK_PATTERNS) {
    if (pattern.test(text)) {
      fail(failures, "INTERNAL_LEAK", `[${label}] 내부 정보 노출 의심 패턴 발견(${pattern}): "${text.slice(0, 80)}"`);
    }
  }
  for (const pattern of AI_WORD_PATTERNS) {
    if (pattern.test(text)) {
      fail(failures, "AI_WORD_LEAK", `[${label}] "AI" 계열 표현 발견: "${text.slice(0, 80)}"`);
    }
  }
  if (hasUnbalancedMarkup(text)) {
    fail(failures, "MARKUP_UNBALANCED", `[${label}] [[ ]] 마크업 짝이 맞지 않음`);
  }
}

// [STEP4 §10 "시기 표현은 FACT 있을 때만"] FACT 근거 없이 미래를 확정하는 표현들.
// timing 블록(n=4)이 아예 없거나, isTiming=false인 주제의 본문에서 이런 표현이 보이면
// "근거 없는 시기 생성"으로 간주한다.
const UNGROUNDED_TIMING_PATTERNS = [
  /이\s*시기에\s*반드시/,
  /\d{4}년에\s*(반드시|틀림없이)/,
  /조만간\s*(반드시|틀림없이)/,
  /곧\s*(결혼|승진|합격|당첨)/,
  /머지않아\s*(반드시|틀림없이)/,
];

// [STEP4 §9 "FACT 밖 이야기 금지" — 금지 목록 그대로] 특정 사건/직업/금액/가족관계/
// 연애경험을 "이미 일어난 사실"처럼 단정하는 표현. 완벽한 자연어 이해는 불가능하므로
// 가장 명백한 단정 패턴만 방어선으로 둔다(서버 QA는 최종 방어선이지 유일한 방어선이
// 아니다 — 1차 방어는 프롬프트의 금지 지시다).
const UNGROUNDED_FACT_PATTERNS = [
  /당신은\s*이미\s*(이혼|결혼|취업|창업|합격|당첨)/,
  /작년에\s*(이혼|결혼|취업|창업|합격|당첨)/,
  /\d+억\s*(원|대)/, // 특정 금액 단정(예: "3억 원을 벌게 됩니다")
  /당신의\s*(배우자|자녀|부모)는\s*(이미|현재)/,
];

function checkUngroundedContent(
  text: string,
  label: string,
  isTiming: boolean,
  failures: QaFailure[]
) {
  for (const pattern of UNGROUNDED_FACT_PATTERNS) {
    if (pattern.test(text)) {
      fail(
        failures,
        "UNGROUNDED_FACT",
        `[${label}] FACT에 없는 사실 단정 의심: "${text.match(pattern)?.[0] ?? ""}"`
      );
    }
  }
  if (!isTiming) {
    for (const pattern of UNGROUNDED_TIMING_PATTERNS) {
      if (pattern.test(text)) {
        fail(
          failures,
          "UNGROUNDED_TIMING",
          `[${label}] 시기 FACT 없는 주제에서 근거 없는 시기 예측 발견: "${text.match(pattern)?.[0] ?? ""}"`
        );
      }
    }
  }
}

/** [STEP4 §7 "내용 품질"] 동일 문장(또는 구간)을 반복해 글자 수만 채운 결과를 방어한다.
 * 블록 본문을 문장 단위로 쪼개 완전히 동일한 문장이 2회 이상 등장하면 실패 처리한다. */
function checkRepetition(allBodies: string[], failures: QaFailure[]) {
  const sentenceCount = new Map<string, number>();
  for (const body of allBodies) {
    const sentences = body
      .split(/[.!?。]\s*/)
      .map((s) => s.trim())
      .filter((s) => s.length >= 8); // 너무 짧은 조각(어절)은 반복 검사에서 제외
    for (const s of sentences) {
      sentenceCount.set(s, (sentenceCount.get(s) ?? 0) + 1);
    }
  }
  for (const [sentence, count] of sentenceCount) {
    if (count >= 2) {
      fail(
        failures,
        "REPEATED_SENTENCE",
        `[내용 품질] 동일 문장이 ${count}회 반복됨: "${sentence.slice(0, 40)}"`
      );
    }
  }
}

/** summary 응답 전체를 검증한다(docs/11 §3 "summary" 계약 + STEP4 §14). */
export function checkInterpretSummary(
  result: InterpretSummaryResult,
  options: QaCheckOptions
): QaCheckResult {
  const failures: QaFailure[] = [];

  // ── 구조 ──
  if (!result.topic_id || typeof result.topic_id !== "string") {
    fail(failures, "STRUCTURE_MISSING_TOPIC_ID", "topic_id 필드가 없거나 문자열이 아님");
  } else if (result.topic_id !== options.expectedTopicId) {
    fail(
      failures,
      "TOPIC_MISMATCH",
      `응답 topic_id(${result.topic_id})가 요청 topic_id(${options.expectedTopicId})와 다름`
    );
  }
  if (!result.title || typeof result.title !== "string" || result.title.trim().length === 0) {
    fail(failures, "STRUCTURE_MISSING_TITLE", "title 필드가 없거나 비어 있음");
  }
  if (!result.summary || typeof result.summary !== "string" || result.summary.trim().length === 0) {
    fail(failures, "STRUCTURE_MISSING_SUMMARY", "summary 필드가 없거나 비어 있음");
  }
  if (!result.evidence || typeof result.evidence.text !== "string" || result.evidence.text.trim().length === 0) {
    fail(failures, "STRUCTURE_MISSING_EVIDENCE", "evidence.text 필드가 없거나 비어 있음");
  }

  if (result.title) checkSecurityAndBanned(result.title, "title", failures);
  if (result.summary) {
    checkSecurityAndBanned(result.summary, "summary", failures);
    checkUngroundedContent(result.summary, "summary", options.isTiming, failures);
  }
  if (result.evidence?.text) checkSecurityAndBanned(result.evidence.text, "evidence", failures);

  return { ok: failures.length === 0, failures };
}

/** detail 응답 전체를 검증한다(docs/11 §3 "detail" 계약 + STEP4 §6·§7·§8·§10·§14). */
export function checkInterpretDetail(
  result: InterpretDetailResult,
  options: QaCheckOptions
): QaCheckResult {
  const failures: QaFailure[] = [];

  // ── 구조 ──
  if (!result.topic_id || typeof result.topic_id !== "string") {
    fail(failures, "STRUCTURE_MISSING_TOPIC_ID", "topic_id 필드가 없거나 문자열이 아님");
  } else if (result.topic_id !== options.expectedTopicId) {
    fail(
      failures,
      "TOPIC_MISMATCH",
      `응답 topic_id(${result.topic_id})가 요청 topic_id(${options.expectedTopicId})와 다름`
    );
  }
  if (!result.title || typeof result.title !== "string" || result.title.trim().length === 0) {
    fail(failures, "STRUCTURE_MISSING_TITLE", "title 필드가 없거나 비어 있음");
  }
  if (!Array.isArray(result.blocks) || result.blocks.length === 0) {
    fail(failures, "STRUCTURE_MISSING_BLOCKS", "blocks 배열이 없거나 비어 있음");
    return { ok: false, failures }; // 이후 검증이 전부 무의미하므로 조기 반환
  }

  // [STEP4 §6 5단 구조] n=1~5 중 n=4(시기)만 선택적(시기 FACT 없으면 생략, docs/11 §3 +
  // docs/07 E-14). 그 외 1/2/3/5는 반드시 존재해야 한다.
  const ns = result.blocks.map((b) => b.n);
  const REQUIRED_NS: Array<1 | 2 | 3 | 5> = [1, 2, 3, 5];
  for (const required of REQUIRED_NS) {
    if (!ns.includes(required)) {
      fail(failures, "STRUCTURE_MISSING_BLOCK", `blocks에 n=${required} 블록이 없음(5단 구조 중 필수 블록 누락)`);
    }
  }
  // n 오름차순(docs/11 "n 오름차순") + 중복 금지
  const sorted = [...ns].sort((a, b) => a - b);
  if (JSON.stringify(ns) !== JSON.stringify(sorted)) {
    fail(failures, "STRUCTURE_BLOCK_ORDER", `blocks가 n 오름차순이 아님: [${ns.join(",")}]`);
  }
  if (new Set(ns).size !== ns.length) {
    fail(failures, "STRUCTURE_BLOCK_DUPLICATE", `blocks에 중복된 n 값이 있음: [${ns.join(",")}]`);
  }

  // [docs/11 §3 "n=2는 evidence 필수"]
  const block2 = result.blocks.find((b) => b.n === 2);
  if (block2 && (!block2.evidence || !block2.evidence.text)) {
    fail(failures, "BLOCK2_EVIDENCE_REQUIRED", "n=2(왜 이런 특징이 나타나는가) 블록에 evidence가 없음");
  }

  // [docs/07 E-14 + STEP4 §10] 시기 FACT가 없는 주제(isTiming=false)인데 n=4 블록이
  // 존재하면 "근거 없는 시기 생성"이다 — 반드시 배열에서 제외되어야 한다.
  const block4 = result.blocks.find((b) => b.n === 4);
  if (block4 && !options.isTiming) {
    fail(
      failures,
      "TIMING_BLOCK_WITHOUT_FACT",
      "시기 FACT가 없는 주제인데 n=4(어느 시기에) 블록이 존재함 — docs/07 E-14 위반"
    );
  }
  if (block4 && !block4.timing) {
    fail(failures, "TIMING_FIELD_MISSING", "n=4 블록에 timing.luck_index가 없음(docs/11 §3 필수)");
  }

  // ── 분량(§7) ──
  const bodies = result.blocks.map((b) => b.body ?? "");
  const totalVisibleLength = bodies.reduce((sum, b) => sum + visibleLength(b), 0);
  if (totalVisibleLength < DETAIL_MIN_LENGTH || totalVisibleLength > DETAIL_MAX_LENGTH) {
    fail(
      failures,
      "LENGTH_OUT_OF_RANGE",
      `detail 총 글자수 ${totalVisibleLength}자 — 허용 범위(${DETAIL_MIN_LENGTH}~${DETAIL_MAX_LENGTH}자) 벗어남`
    );
  }
  // 목표 범위(1800~2200)는 실패 처리하지 않고 경고만 남긴다(§7 "목표"이지 "허용범위"가 아님).
  if (totalVisibleLength < DETAIL_TARGET_MIN || totalVisibleLength > DETAIL_TARGET_MAX) {
    console.warn(
      `[interpret-qa-check] detail 분량이 목표 범위(${DETAIL_TARGET_MIN}~${DETAIL_TARGET_MAX}자)를 벗어남(실제 ${totalVisibleLength}자) — 허용 범위 내이므로 실패 처리는 하지 않음`
    );
  }

  // ── 내용 품질(§7 반복 문장 방어) ──
  checkRepetition(bodies, failures);

  // ── 보안 + FACT 밖 사실 + 근거없는 시기(블록별) ──
  if (result.title) checkSecurityAndBanned(result.title, "title", failures);
  for (const block of result.blocks) {
    const label = `block n=${block.n}`;
    checkSecurityAndBanned(block.body ?? "", label, failures);
    checkUngroundedContent(block.body ?? "", label, options.isTiming, failures);
    if (block.evidence?.text) checkSecurityAndBanned(block.evidence.text, `${label} evidence`, failures);

    // termKey 사전 존재 검증(docs/11 §3 "termKey가 사전에 존재").
    if (options.knownTermKeys) {
      const usedKeys = extractTermKeys(block.body ?? "");
      for (const key of usedKeys) {
        if (!options.knownTermKeys.includes(key)) {
          fail(failures, "UNKNOWN_TERM_KEY", `${label}에서 미등록 termKey 사용: "${key}"`);
        }
      }
    }
  }

  return { ok: failures.length === 0, failures };
}
