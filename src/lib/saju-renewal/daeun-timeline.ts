// [정통사주 LLM 해석 공통 스펙 v2.0 — §4-C2·C5, §6] 대운 타임라인 공통 유틸.
//
// [배경] saju-handoff-spec.pdf §2.2가 재현한 결함(“38세부터 48세”만 강조되고 “지금
// 내 나이”가 전혀 없음)의 근본 해결책은 "나이↔대운↔연도 매핑 표"(원인 C)를 모든
// 시기 관련 주제가 공통으로 쓸 수 있게 한 곳에서 만들어 두는 것이다. 이 파일은
// saju_engine(`/saju/v3/facts`)이 이미 내려준 `luck_pillars`(대운 배열) +
// `current_luck`/`current_age`(현재 대운·나이)만을 가공해(새 계산 없음, §4-C1
// facts-only 원칙) "과거/현재/미래"가 표기된 전체 타임라인을 만든다.
//
// [엔진을 다시 계산하지 않는다] saju_calculator.py/saju_facts.py의 대운 계산 로직
// (순행/역행, 대운수=일수÷3)은 이미 §6 규칙과 일치함을 소스 코드로 직접 확인했다
// (2026-10-08). 따라서 이 파일은 "이미 계산된 luck_pillars 배열"의 구간 경계(end_age/
// end_year)를 보정하고, 각 구간에 tense(past/now/future) 라벨만 부여한다 — 사주를
// 재계산하는 것이 아니라 이미 계산된 값을 표 형태로 재구성하는 것뿐이다.
import type { SajuV3Facts, SajuV3LuckPillar } from "./saju-facts-types";

export type DaeunTense = "past" | "now" | "future";

export interface DaeunTimelineEntry {
  /** 한글 간지 2글자(예: "병오"). saju_engine 응답 그대로. */
  ganZhiKr: string;
  /** 한자 간지(있으면). 검증 게이트가 한자 본문을 대조할 때 사용. */
  ganZhi?: string;
  /** 세는나이 시작(포함). */
  startAge: number;
  /** 세는나이 끝(포함) — 다음 구간의 startAge-1, 마지막 구간은 startAge+9로 보정. */
  endAge: number;
  startYear: number;
  endYear: number;
  tense: DaeunTense;
}

export interface DaeunTimeline {
  entries: DaeunTimelineEntry[];
  /** 현재 나이(세는나이) — facts.current_age 또는 현재 대운 엔트리로부터 역산. */
  currentAge: number | null;
  /** entries 중 현재 나이가 속한 구간(tense="now"). 없으면 null(facts 부족). */
  currentEntry: DaeunTimelineEntry | null;
}

/** luck_pillars[i]의 끝(end_age/end_year)을 다음 원소의 시작으로부터 역산한다.
 * 마지막 원소는 10년 구간으로 간주해 +9를 더한다(만세력 대운은 10년 주기 — §6.2 "이후
 * 대운은 정확히 10년마다 교체"). */
function buildEntriesFromLuckPillars(
  luckPillars: SajuV3LuckPillar[],
  currentAge: number | null
): DaeunTimelineEntry[] {
  const sorted = [...luckPillars]
    .filter((p) => typeof p.start_age === "number" && typeof p.start_year === "number" && !!p.gan_zhi_kr)
    .sort((a, b) => (a.start_age ?? 0) - (b.start_age ?? 0));

  const entries: DaeunTimelineEntry[] = [];
  for (let i = 0; i < sorted.length; i++) {
    const cur = sorted[i];
    const next = sorted[i + 1];
    const startAge = cur.start_age as number;
    const startYear = cur.start_year as number;
    const endAge = next ? (next.start_age as number) - 1 : startAge + 9;
    const endYear = next ? (next.start_year as number) - 1 : startYear + 9;
    let tense: DaeunTense = "future";
    if (currentAge !== null) {
      if (currentAge >= startAge && currentAge <= endAge) tense = "now";
      else if (currentAge > endAge) tense = "past";
      else tense = "future";
    }
    entries.push({
      ganZhiKr: cur.gan_zhi_kr as string,
      ganZhi: cur.gan_zhi,
      startAge,
      endAge,
      startYear,
      endYear,
      tense,
    });
  }
  return entries;
}

/**
 * [공통 타임라인 빌더 — C2·C5·finding 검출의 단일 소스]
 * facts.luck_pillars가 없거나 비어 있으면 entries=[]를 반환한다(호출부가 "시기 FACT
 * 없음"으로 처리 — 근거 없는 시기 생성 금지, §4-C1).
 */
export function buildDaeunTimeline(facts: SajuV3Facts): DaeunTimeline {
  const luckPillars = facts.luck_pillars ?? [];
  const currentAge =
    typeof facts.current_age === "number"
      ? facts.current_age
      : typeof facts.current_luck?.start_age === "number"
        ? null // current_luck.start_age는 "그 대운이 시작된 나이"일 뿐 현재 나이가 아니므로 대입하지 않음
        : null;

  if (luckPillars.length === 0) {
    return { entries: [], currentAge, currentEntry: null };
  }

  const entries = buildEntriesFromLuckPillars(luckPillars, currentAge);
  const currentEntry = entries.find((e) => e.tense === "now") ?? null;

  return { entries, currentAge, currentEntry };
}

/** C5 "facts의 daeun 배열을 그대로 옮긴 표" — 프롬프트/폴백 양쪽에서 공통으로 쓰는
 * 표 문자열 생성기(마크다운 표). LLM에게 "이 표를 그대로 출력"하라고 지시할 때 쓴다. */
export function renderDaeunTableMarkdown(timeline: DaeunTimeline): string {
  if (timeline.entries.length === 0) return "(대운 데이터 없음)";
  const TENSE_KR: Record<DaeunTense, string> = { past: "지난", now: "현재", future: "앞으로" };
  const header = "| 대운 | 기간(연도) | 나이(세는) | 시제 |\n| --- | --- | --- | --- |";
  const rows = timeline.entries.map(
    (e) => `| ${e.ganZhiKr} | ${e.startYear}–${e.endYear} | ${e.startAge}–${e.endAge} | ${TENSE_KR[e.tense]} |`
  );
  return [header, ...rows].join("\n");
}

/** C2 "지금 당신은 N세, OO 대운(YYYY~YYYY) 구간에 있습니다" 앵커 문장을 facts 그대로
 * 조립한다(LLM이 새로 만들 필요가 없도록 — facts-only 원칙의 가장 안전한 구현은 아예
 * 문장을 엔진 값으로 조립해 프롬프트/폴백에 공급하는 것). */
export function renderAnchorSentence(timeline: DaeunTimeline): string | null {
  if (!timeline.currentEntry || timeline.currentAge === null) return null;
  const e = timeline.currentEntry;
  return `지금 당신은 ${timeline.currentAge}세(세는나이), ${e.ganZhiKr} 대운(${e.startYear}~${e.endYear}) 구간에 있습니다.`;
}

/**
 * [TK-7 — §4-C5 "주제별 대운 브리핑 표 UI" 구현] 지금까지 이 파일의 타임라인
 * (entries)은 renderDaeunTableMarkdown()을 거쳐 "LLM 프롬프트 텍스트" 안에만
 * 주입되고 있었다(interpret-prompt.ts buildTimeAnchoringSection()). 이는 LLM이
 * 표를 "그대로 베껴 쓰라"는 지시일 뿐, 실제로 구조화된 형태로 API 응답에
 * 실려 Flutter에 전달되지는 않았다 — Flutter 쪽에 facts 기반 타임라인 표를
 * 렌더링할 데이터 자체가 없는 상태였다(이번 TK-7 조사로 확인한 근본 원인).
 *
 * C5 원문 "표 문자열을 새로 쓰지 말고 facts에서 복사"의 취지를 클라이언트까지
 * 그대로 연장하는 방법은, LLM이 만든 서술(body)과 완전히 분리된 이 구조화
 * 배열을 API 응답(InterpretDetailResult.daeun_timeline)에 별도 필드로 함께
 * 내려주는 것이다 — Flutter는 LLM 본문 텍스트를 파싱할 필요 없이 이 배열을
 * 그대로 표로 그리면 된다(facts→표 변환 로직이 서버 한 곳에만 존재하게 됨).
 *
 * snake_case로 변환하는 이유: 이 프로젝트의 모든 LLM/API JSON 필드(topic_id,
 * gan_zhi_kr 등)가 snake_case 컨벤션을 쓰므로 일관성을 맞춘다(camelCase인
 * DaeunTimelineEntry는 TypeScript 내부 전용, API 바깥으로 나가는 형태는 이
 * 함수가 담당).
 */
export interface DaeunTimelineApiEntry {
  gan_zhi_kr: string;
  gan_zhi?: string;
  start_year: number;
  end_year: number;
  start_age: number;
  end_age: number;
  tense: DaeunTense;
}

export function toDaeunTimelineApiEntries(timeline: DaeunTimeline): DaeunTimelineApiEntry[] {
  return timeline.entries.map((e) => ({
    gan_zhi_kr: e.ganZhiKr,
    gan_zhi: e.ganZhi,
    start_year: e.startYear,
    end_year: e.endYear,
    start_age: e.startAge,
    end_age: e.endAge,
    tense: e.tense,
  }));
}
