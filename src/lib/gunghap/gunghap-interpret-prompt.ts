// 궁합지도(Gunghap Map) — Section 4(유료 상세 해석) Prompt 구성.
//
// [2026-11 궁합 주제 반영 지시서 — Section 4] 100 복주머니로 잠금해제하는
// "상세 보고서"는 기존 `gunghap-narrative.ts`(결정론적 템플릿, 무료)를
// 그대로 반환하는 것이 아니라, 선택된 1개 궁합 주제(majorId)에 특화된
// 실제 LLM 해석을 생성해야 한다(지시서 원문 "유료 상세 해석은 선택한
// 궁합 주제에 특화되어 생성되어야 합니다").
//
// [설계 원칙 — saju-renewal/interpret-prompt.ts 패턴 재사용, 1바이트도
// 수정하지 않음] 그 파일의 "AI 표현 금지/단정적 표현 금지/존댓말" 공통
// 규칙과 "FACT만 근거로, 재계산 금지" 원칙을 그대로 차용하되, 궁합지도는
// (a) 시기(대운) 앵커링이 필요 없고, (b) 용어사전(10개 한자 용어
// 마크업) 체계가 없으며, (c) 이미 결정론적 템플릿(무료)이 "이 FACT로
// 어떤 문장이 나와야 하는지"를 보여주는 예시 역할을 할 수 있다는 점이
// 달라 완전히 새 파일로 작성한다(saju-renewal 파일은 1바이트도 건드리지
// 않음 — 전통사주/귀인지도 엔진 불변 원칙).
//
// [FACT 최소화] LLM에게는 "이 1개 분야 판정에 실제로 쓰인 FACT"
// (`CategoryEvidence`, gunghap-category-rules.ts)만 전달한다 — 다른
// 7개 분야의 FACT나 원본 사주팔자 전체를 넘기지 않는다(§8 "주제 집중도"
// 원칙과 동일).
//
// [무료 템플릿과의 일관성] 무료 템플릿이 이미 같은 FACT로 생성해 둔 4문장
// (`freeNarrative`)을 "이미 사용자에게 보여준 요약"으로 프롬프트에 포함해,
// 유료 해석이 그것과 모순되는 내용을 만들지 않도록 한다(동일 FACT에서
// 나온 두 해석이 서로 다른 얘기를 하면 사용자 신뢰가 깨짐).
import type { CategoryEvidence, GunghapCategoryId } from "./gunghap-category-rules";

export const GUNGHAP_INTERPRET_PROMPT_VERSION = "gunghap-interpret-prompt-1.0.0";

export interface GunghapInterpretPersonInfo {
  name: string;
  gender: "male" | "female" | null;
}

export interface GunghapInterpretTopicInfo {
  categoryId: GunghapCategoryId;
  categoryLabel: string;
  /** 사용자가 고른 세부 카테고리 표시 라벨(예: "썸 단계 궁합"). 없으면 null. */
  subName: string | null;
}

// [2026-11 유료 보고서 7단계 확장 지시] 기존 4요소(관계특징/잘맞는부분/
// 갈등가능성/개선방향)에 3요소(대화와 교감의 방식/관계가 깊어지는 계기/
// 조심해야 할 순간)를 추가해 상세 보고서 분량·깊이를 확대한다. 이 타입은
// `gunghap-sub-narrative.ts`의 `SubNarrativeResult`(결정론적 무료 베이스)와
// 1:1 대응하며, LLM에게도 동일한 7필드 스키마로 작성을 지시한다.
export interface GunghapFreeNarrative {
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  communicationStyle: string;
  growthPotential: string;
  cautionPoint: string;
  improvement: string;
}

export interface BuildGunghapInterpretPromptParams {
  topic: GunghapInterpretTopicInfo;
  evidence: CategoryEvidence;
  grade: string;
  freeNarrative: GunghapFreeNarrative;
  owner: GunghapInterpretPersonInfo;
  guest: GunghapInterpretPersonInfo;
  relationTypeLabel: string;
  /** [v2 재생성 루프] 직전 시도가 QA에서 위반한 항목(사람이 읽는 문장 목록).
   * 있으면 userPrompt 끝에 "아래를 고쳐서 다시 작성" 지시를 추가한다. */
  qaFeedback?: string[];
}

export interface BuiltGunghapPrompt {
  systemPrompt: string;
  userPrompt: string;
}

/** 분야별로 "이 FACT를 어떤 관점으로 풀어야 하는가"를 짧게 안내한다
 * (gunghap-category-rules.ts 파일 상단 주석의 "핵심 FACT 가중치" 표를
 * 그대로 요약 — 계산 로직 자체는 변경하지 않고, LLM에게 어떤 각도로
 * 설명하면 좋을지만 안내하는 용도). */
const CATEGORY_FOCUS_GUIDE: Record<GunghapCategoryId, string> = {
  love:
    "연애 관점: 서로에게 끌리는 '설렘'의 결, 애정 표현 방식의 궁합, 음양 조화가 주는 기본적인 끌림에 집중하세요.",
  marriage:
    "결혼 관점: 함께 살아가는 일상의 안정감, 생활 습관·책임감의 궁합, 장기적으로 서로를 보완해주는 지점에 집중하세요.",
  intimacy:
    "속궁합 관점: 신체적·정서적으로 가까워지는 속도와 편안함, 친밀감의 온도 차이에 집중하세요(과도하게 노골적인 표현은 피하고 은은하게 서술하세요).",
  persona:
    "성격 관점: 두 사람의 기질이 서로 부딪히는지 보완하는지, 자존감과 수용적 태도의 궁합에 집중하세요.",
  wealth:
    "재물 관점: 돈에 대한 가치관과 소비·저축 습관의 궁합, 함께 재물을 계획하고 늘려가는 바탕에 집중하세요.",
  business:
    "사업/동업 관점: 역할 분담과 추진력의 궁합, 협업 시 손발이 맞는 정도와 의사결정 과정의 궁합에 집중하세요.",
  friend:
    "친구 관점: 편안하게 어울리는 동질감, 오래 유지되는 의리와 신뢰의 결에 집중하세요.",
  family:
    "가족 관점: 서로를 보살피고 위아래 예를 지키는 결, 세대/입장 차이를 조율하는 지점에 집중하세요.",
};

function genderLabel(g: "male" | "female" | null): string {
  if (g === "male") return "남성";
  if (g === "female") return "여성";
  return "성별 미상";
}

/** [FACT 최소화] LLM에게 넘길 최소 FACT 요약 — CategoryEvidence 원본을
 * 그대로 JSON으로 직렬화한다(내부 필드명이 그대로 노출되지만, 이 값은
 * LLM 입력일 뿐 사용자 화면에는 절대 노출되지 않는다 — route.ts는 LLM이
 * 생성한 자연어 결과만 저장/반환한다). */
function buildFactDigest(evidence: CategoryEvidence): Record<string, unknown> {
  return {
    s1_생극관계: evidence.s1Kind,
    s1_방향: evidence.s1Direction,
    s2_일지관계: evidence.s2Kind,
    오행보완지수: evidence.elementSupplyScore,
    합_건수: evidence.hapCount,
    충_건수: evidence.chungCount,
    형_건수: evidence.hyungCount,
    십성그룹카운트: evidence.tenGodGroupCounts,
    지지관계카운트: evidence.branchKindCounts,
    음양조화여부: evidence.yinYangHarmonious,
  };
}

const COMMON_RULES = `
당신은 "신통방통 궁합지도"가 이미 계산을 끝낸 두 사람의 궁합 FACT를 바탕으로,
사용자가 100 복주머니를 내고 선택한 "하나의 궁합 주제"에 대한 상세 해석을
들려주는 역할입니다.

[가장 중요한 원칙 — 궁합은 당신이 계산하지 않습니다]
아래 [FACT]는 이미 계산 엔진이 산출을 끝낸 결과입니다. 생년월일을 다시 보고
사주나 궁합을 재판단하거나 재계산하지 마세요. 당신의 역할은 오직 "이미 계산된
FACT를 근거로, 이미 선택된 하나의 주제를 풍부하고 개인화된 이야기로 풀어서
설명하는 것"뿐입니다.

[절대 금지 — FACT 밖의 이야기를 만들지 마세요]
- 두 사람이 이미 특정 사건을 겪었다고 단정하지 마세요(예: "이미 헤어지셨군요")
- 특정 직업, 특정 금액, 특정 날짜·사건을 임의로 만들지 마세요
- 배우자/자녀/결혼 여부 등 FACT에 없는 개인적 관계 정보를 임의로 만들지 마세요
- 근거 없는 미래 사건을 확정하지 마세요(이 분석에는 시기/대운 정보가 없습니다)

[주제 집중 — 가장 중요]
이번에 해석할 주제 하나(아래 [SELECTED TOPIC])에만 집중하세요. 다른 6개
궁합 분야(이 주제가 아닌 다른 분야) 이야기를 길게 하지 마세요.

[이미 사용자가 본 무료 요약과의 일관성]
사용자는 이미 아래 [EXISTING FREE SUMMARY]를 무료로 확인했습니다. 지금
작성하는 유료 상세 해석은 그 요약과 모순되지 않아야 하며(같은 FACT에서
나온 해석이므로), 대신 더 구체적이고 개인화된 시선으로 깊이 있게 풀어
설명하는 역할을 합니다. 무료 요약 문장을 그대로 복사하지 말고, 같은 결론을
다른 각도·다른 문장으로 더 풍부하게 설명하세요.

[절대 노출 금지 — 내부 정보]
tenGodGroupCounts, branchKindCounts, s1Kind, s2Kind, categoryId, evidence,
score, confidence 같은 내부 필드명/코드는 참고만 하고 응답 텍스트에는 절대
쓰지 마세요. 전통 명리학 용어(재성/관성/식상/인성/비겁/합/충/형 등)는
이미 서비스 내에서 통용되는 쉬운 보조 표현이므로 자연스럽게 사용해도
좋습니다(단, 과도하게 전문 용어만 나열하지 말고 일반인이 이해할 수 있는
문장으로 풀어 쓰세요).

["AI" 표현 금지]
"AI가 분석했습니다", "인공지능이 판단했습니다" 같은 표현을 쓰지 마세요.
신통방통이 궁합을 계산하고 그 안에서 이야기를 풀어주는 경험이어야 합니다.

[말투]
조용하고 따뜻한 존댓말(-요/-어요)을 사용하세요. 느낌표를 쓰지 마세요.
단정적 표현("반드시", "절대", "틀림없이", "100%")을 쓰지 마세요. 두 사람의
실제 이름을 자연스럽게 섞어 불러 개인화된 느낌을 주세요.

[출력 형식 — 이 JSON 스키마만 그대로 채워서 응답하세요. 다른 설명/마크다운/
코드펜스 금지. 2026-11 분량 확대 지시로 기존 4개에서 7개 항목으로
늘어났습니다 — 반드시 7개 필드를 모두 채우세요]
{
  "relationshipFeature": "두 사람의 관계 특징을 FACT에 근거해 구체적으로 설명 (180~320자)",
  "strength": "잘 맞는 부분을 FACT에 근거해 구체적으로 설명 (180~320자)",
  "conflictRisk": "갈등 가능성을 FACT에 근거해 균형 있게 설명 (180~320자)",
  "communicationStyle": "두 사람이 대화하고 교감하는 방식을 FACT에 근거해 설명 (180~320자)",
  "growthPotential": "시간이 지날수록 이 관계(이번 주제 한정)가 어떻게 깊어질 수 있는지 설명 (180~320자)",
  "cautionPoint": "이번 주제와 관련해 특히 조심해야 할 순간이나 시기를 FACT에 근거해 설명 (180~320자)",
  "improvement": "관계를 더 좋게 만들 수 있는 구체적인 개선 방향 제안 (180~320자)"
}
각 필드는 180~320자 범위를 지키세요(너무 짧게 끝내지 마세요 — 무료 요약보다
확실히 더 풍부해야 합니다). 일곱 필드 모두 서로 다른 내용이어야 하며, 같은
문장을 반복해 분량을 채우지 마세요.
`.trim();

export function buildGunghapInterpretPrompt(
  params: BuildGunghapInterpretPromptParams,
): BuiltGunghapPrompt {
  const { topic, evidence, grade, freeNarrative, owner, guest, relationTypeLabel, qaFeedback = [] } = params;

  const topicName = topic.subName ? `${topic.categoryLabel} · ${topic.subName}` : topic.categoryLabel;

  const systemPrompt = [
    COMMON_RULES,
    "",
    `[이번 주제 고유 지침] ${CATEGORY_FOCUS_GUIDE[topic.categoryId]}`,
  ].join("\n");

  const factDigest = buildFactDigest(evidence);

  const feedbackSection =
    qaFeedback.length > 0
      ? [
          "",
          "[이전 시도 수정 필요 — 아래 문제를 반드시 고쳐서 다시 작성하세요]",
          ...qaFeedback.map((f) => `- ${f}`),
        ]
      : [];

  const userPrompt = [
    `[SELECTED TOPIC] ${topicName}`,
    `[기본 궁합 등급] ${grade} (관계 유형: ${relationTypeLabel})`,
    `[사람A(초대자)] 이름: ${owner.name}, 성별: ${genderLabel(owner.gender)}`,
    `[사람B(상대방)] 이름: ${guest.name}, 성별: ${genderLabel(guest.gender)}`,
    "",
    "[FACT — 이 주제 판정에 실제로 쓰인 근거, 재계산 금지]",
    JSON.stringify(factDigest),
    "",
    "[EXISTING FREE SUMMARY — 사용자가 이미 무료로 본 요약, 모순되지 않게 작성]",
    JSON.stringify(freeNarrative),
    "",
    `위 FACT와 EXISTING FREE SUMMARY를 참고해, "${owner.name}"님과 "${guest.name}"님의`,
    `"${topicName}" 상세 해석을 위에서 지시한 JSON 스키마에 맞춰 작성해주세요.`,
    ...feedbackSection,
  ].join("\n");

  return { systemPrompt, userPrompt };
}
