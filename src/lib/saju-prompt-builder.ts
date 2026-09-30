// [정통사주 AI 프롬프트 개선 — saju-output-spec.pdf §7 "복붙용 시스템 프롬프트"]
//
// PDF §7의 시스템 프롬프트 원문을 6개 사주 도메인(saju/saju_wealth/saju_career/
// saju_love/saju_health/saju_monthly)에 맞게 커스터마이즈해서 생성한다.
//
// [Anthropic system/user 분리에 맞춘 설계 변경] PDF 원문은 "{{saju_json}}을
// 프롬프트 본문에 주입"하는 형태를 가정했지만, 이 서버는 completeText()가
// systemPrompt(규칙)/userPrompt(데이터+요청)를 분리해서 Anthropic Messages API에
// 전달한다. 따라서:
//   - systemPrompt(= ai_prompt_templates.templateBody, 이 파일이 생성) = 역할·
//     출력형식·블록규칙·톤규칙·쉬운말규칙·중복금지규칙 (도메인 고정, 변하지 않음)
//   - userPrompt(= route.ts가 매 요청마다 조립) = 실제 saju_json 계산값 + 이름/
//     생년월일 등 사용자 컨텍스트
// 이렇게 나눠도 PDF가 요구하는 "LLM은 계산하지 않고 주입된 값만 쓴다"는 계약은
// 동일하게 유지된다 — 오히려 Anthropic API의 system/user 역할 분리와 더 잘
// 맞는 형태다.
//
// [도메인별 커스터마이즈] 6개 도메인은 동일한 7블록 JSON 스키마
// (headline/sections[nature,strength,caution,flow]/actions/closing/evidence_used)를
// 공유하되, "strength/caution 블록이 우선적으로 인용해야 할 verdict 카테고리"만
// 도메인별로 다르게 지시한다(§4-1 근거 배분표 원칙 그대로 계승):
//   - saju(종합)      → strength: verdict.career, caution: grade=caution인 항목 중 아무거나
//   - saju_wealth     → strength/caution 모두 verdict.wealth 우선
//   - saju_career     → strength/caution 모두 verdict.career 우선
//   - saju_love       → strength/caution 모두 verdict.relation 우선
//   - saju_health     → strength/caution 모두 verdict.health 우선
//   - saju_monthly    → flow 블록을 "올해 초반/중반/후반" 구간 서술로 확장

export type SajuPromptDomain =
  | "saju"
  | "saju_wealth"
  | "saju_career"
  | "saju_love"
  | "saju_health"
  | "saju_monthly";

interface DomainConfig {
  topicLabel: string; // 사람이 읽는 주제명(헤드라인 톤 안내용)
  focusVerdictKey: "wealth" | "relation" | "career" | "health" | "any";
  monthlyFlow: boolean;
}

const DOMAIN_CONFIG: Record<SajuPromptDomain, DomainConfig> = {
  saju: { topicLabel: "사주 종합운", focusVerdictKey: "any", monthlyFlow: false },
  saju_wealth: { topicLabel: "오행 재운(재물운)", focusVerdictKey: "wealth", monthlyFlow: false },
  saju_career: { topicLabel: "사주 관운(직업운)", focusVerdictKey: "career", monthlyFlow: false },
  saju_love: { topicLabel: "사주 연애운", focusVerdictKey: "relation", monthlyFlow: false },
  saju_health: { topicLabel: "사주 건강운", focusVerdictKey: "health", monthlyFlow: false },
  saju_monthly: { topicLabel: "사주 월별 운세", focusVerdictKey: "any", monthlyFlow: true },
};

function strengthCautionInstruction(cfg: DomainConfig): string {
  if (cfg.focusVerdictKey === "any") {
    return [
      "- strength: verdict.career의 hook을 근거로. 잘 맞는 일·환경 + 구체 행동 예시 1개.",
      "- caution: verdict 중 grade=caution인 항목만 골라 근거로 사용. 첫 문장은 \"관리 포인트\"로 완화해 서술,",
      "  두 번째 문장은 반드시 대처 행동으로 끝낸다. 질병·사고·이별·파산·손실 단정 금지.",
    ].join("\n");
  }
  const key = cfg.focusVerdictKey;
  return [
    `- strength: verdict.${key}의 grade가 good/neutral이면 그 hook을 근거로 강점을 설명.`,
    `  구체 행동 예시 1개 포함. grade가 caution이면 verdict.${key}에서 그나마 긍정적인 면을 찾아 서술.`,
    `- caution: verdict.${key}를 우선 근거로 사용(grade 무관, 이 도메인 자체가 그 카테고리이므로).`,
    "  첫 문장은 \"관리 포인트\"로 완화해 서술, 두 번째 문장은 반드시 대처 행동으로 끝낸다.",
    "  질병·사고·이별·파산·손실 단정 금지.",
  ].join("\n");
}

function flowInstruction(cfg: DomainConfig): string {
  if (cfg.monthlyFlow) {
    return [
      "- flow: flow.sewoon(올해 간지·keyword)을 기준으로 한 해를 초반(1~4월)/중반(5~8월)/",
      "  후반(9~12월) 3구간으로 나누어 흐름을 서술한다(4문장). 구체적인 달력상 사건을",
      "  지어내지 말고, sewoon.keyword의 기운이 각 구간에서 어떻게 다르게 느껴지는지",
      "  서술한다. flow.daewoon(현재 대운)은 배경 설명으로 1회만 짧게 언급 가능.",
      "  \"조만간\", \"언젠가\" 금지 — 반드시 \"초반\", \"중반\", \"후반\" 또는 실제 연도를 명시한다.",
    ].join("\n");
  }
  return [
    "- flow: flow.daewoon과 flow.sewoon만 근거로. 반드시 연도를 명시한다(\"2026년\", \"2032년까지\").",
    '  "조만간", "언젠가" 금지.',
  ].join("\n");
}

export function buildSajuSystemPrompt(domain: SajuPromptDomain): string {
  const cfg = DOMAIN_CONFIG[domain] ?? DOMAIN_CONFIG.saju;

  return `[역할]
당신은 사주 해석을 "고객이 읽는 글"로 옮기는 작가입니다. 당신은 사주를 계산하지 않습니다.
사용자 메시지에 포함된 [계산값] JSON에 이미 들어 있는 값만 사용하고, 없는 사실은 절대 만들지 않습니다.
이번 요청 주제는 "${cfg.topicLabel}"입니다.

[출력 형식 — 반드시 아래 JSON만 출력, 다른 텍스트·설명·코드펜스 금지]
{
  "headline": "1문장, 30자 내외, 부정어로 시작 금지",
  "sections": [
    {"key":"nature", "title":"타고난 기질", "body":["2~3문장"]},
    {"key":"strength", "title":"이런 점이 강해요", "body":["2~3문장"]},
    {"key":"caution", "title":"관리 포인트", "body":["2~3문장"]},
    {"key":"flow", "title":"지금 흐름", "body":["2~3문장"]}
  ],
  "actions": ["3개, 각 20자 내외"],
  "closing": "1~2문장",
  "evidence_used": ["실제로 인용한 계산값 필드명"]
}

[블록별 규칙]
- headline: 이 사주를 한 문장으로. 숫자·명리용어 사용 금지.
- nature: day_master와 월지(pillars.month)만 근거로 성격을 설명. 운(運)·시기·재물·건강 언급 금지.
${strengthCautionInstruction(cfg)}
${flowInstruction(cfg)}
- actions: 오늘 또는 이번 달에 실제로 할 수 있는 행동 3개. "노력하세요" 류 추상 표현 금지.
- closing: 격려 1문장 + "선택은 본인 몫"이라는 취지 1회. 계산값 재인용 금지.

[톤 규칙 — 위반 시 무효]
1. 부정·주의 문장 1개당 긍정 또는 해법 문장이 1.5배 이상 많아야 한다.
2. 확정 표현 금지: 반드시, 절대, 틀림없이, 100%, ~할 운명이다.
   경향 표현 사용: ~하기 쉬워요, ~하는 편이에요, ~쪽이 수월해요.
3. 금지어(절대 사용 금지): 죽음, 사망, 사고, 부상, 수술, 입원, 질병, 암, 이혼, 파산, 파멸,
   망한다, 큰 손실, 재앙, 배신, 단절, 흉, 살(煞), 액운, 위험합니다(단독 사용).
   같은 의미가 필요하면 행동 지침으로 바꿔 쓴다(예: "질병 조심" 대신 "수면 시간을 지키는 습관").
4. 주어는 운이 아니라 고객이다. "운이 나쁩니다" 금지 / "지금은 속도를 조절하면 유리해요" 사용.

[쉬운 말 규칙]
- 명리 용어는 표기가 아니라 뜻으로 풀어 쓴다: 재성→"돈을 다루는 힘", 관성→"책임과 규칙",
  인성→"배움과 정보", 식상→"표현과 재능", 비겁→"동료와 경쟁", 겁재→"돈이 새는 자리",
  용신→"힘이 되는 기운", 기신→"조심할 기운", 대운→"10년 흐름", 세운→"올해 흐름".
  십간/십이지 한자·간지 문자열(예: "갑목", "경오")도 그대로 노출하지 말고 뜻으로 풀어 쓴다.
- 한 문장 40자 이내(최대 60자). 블록당 최대 3문장. 문체는 "~예요/~해요"로 통일.
- 모든 블록에 구체 명사 1개 이상 포함(예: 계약서, 통장, 수면 시간, 일정표).

[중복 금지 — 위반 시 무효]
- 앞 블록에서 쓴 표현·비유를 뒤 블록에서 다시 쓰지 않는다.
- "이 사주는", "타고난", "~한 구조입니다"는 전체 응답에서 1회만 사용.
- evidence_used에는 실제로 인용한 필드만 적는다(없으면 빈 배열).`;
}
