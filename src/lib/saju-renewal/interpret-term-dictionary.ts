// [정통사주 리뉴얼 v1.0 — STEP 4] 용어 사전(termKey) — docs/06_카피덱.md §3 원문 그대로.
//
// [설계 원칙] "클라이언트 사전과 서버 프롬프트의 termKey 목록이 반드시 일치해야 한다"
// (docs/06 §3). 이 파일이 서버 측 단일 소스다 — interpret-prompt.ts(시스템 프롬프트에
// 이 목록을 그대로 포함해 LLM에게 "이 키만 쓸 수 있다"고 알림)와
// interpret-qa-check.ts(LLM 응답에 미등록 키가 쓰였는지 검증)가 공유한다.
export interface TermDictionaryEntry {
  termKey: string;
  /** 1차 표현 — 본문에 직접 노출 가능한 쉬운 말(사주 용어 원어 아님). */
  plainText: string;
  /** 시트 제목 — 탭했을 때 보여줄 한자 병기 용어. */
  sheetTitle: string;
  /** 보조설명 1줄. */
  note: string;
}

export const TERM_DICTIONARY: TermDictionaryEntry[] = [
  { termKey: "jaesung", plainText: "재물을 움직이는 기운", sheetTitle: "재성 (財星)", note: "사주에서 돈의 방식을 나타내는 기운. 쌓는형(정재)과 흐르는형(편재)이 있습니다." },
  { termKey: "yongshin", plainText: "당신 사주가 필요로 하는 기운", sheetTitle: "용신 (用神)", note: "부족해 채워야 하는 오행. 이야기의 방향을 결정합니다." },
  { termKey: "ilji", plainText: "가장 가까운 사람이 머무는 자리", sheetTitle: "일지 (日支)", note: "태어난 날의 지지. 배우자·친밀한 관계의 자리입니다." },
  { termKey: "daewoon", plainText: "10년마다 바뀌는 바람", sheetTitle: "대운 (大運)", note: "10년 단위로 흐름이 바뀌는 사주의 계절입니다." },
  { termKey: "hap", plainText: "기운이 만나는 자리", sheetTitle: "합 (合)", note: "합은 결합, 충은 긴장 — 어느 쪽이 나쁜지가 아니라 어디에 에너지가 모이는지의 문제입니다." },
  { termKey: "chung", plainText: "기운이 부딪히는 자리", sheetTitle: "충 (沖)", note: "(hap과 동일)" },
  { termKey: "strength", plainText: "(게이지 자체)", sheetTitle: "강약", note: "기운의 세기를 다섯 단계로 보여 줍니다. 강하다고 좋고 약하다고 나쁜 것이 아니라, 쓰는 방식이 달라질 뿐입니다." },
  { termKey: "gwan", plainText: "나를 다듬고 세우는 기운", sheetTitle: "관성 (官星)", note: "나를 다듬고 세우는 기운. 일·책임·명예가 머무는 자리입니다." },
  { termKey: "inseong", plainText: "나를 돕고 채워 주는 기운", sheetTitle: "인성 (印星)", note: "나를 돕고 채워 주는 기운. 배움과 귀인이 들어오는 통로입니다." },
  { termKey: "bigyeon", plainText: "같은 단단한 기운 / 나와 같은 기운", sheetTitle: "비견 (比肩)", note: "나와 같은 기운. 스스로 서는 힘, 자기 기준의 뿌리입니다." },
];

export const KNOWN_TERM_KEYS: string[] = TERM_DICTIONARY.map((t) => t.termKey);

/** 시스템 프롬프트에 그대로 삽입할 수 있는 "사용 가능한 termKey 목록" 텍스트 블록. */
export function renderTermDictionaryForPrompt(): string {
  return TERM_DICTIONARY.map(
    (t) => `- ${t.termKey}: "${t.plainText}" (예: [[${t.termKey}|${t.plainText}]])`
  ).join("\n");
}
