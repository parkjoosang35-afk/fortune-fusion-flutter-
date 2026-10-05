// [정통사주 리뉴얼 v1.0 — STEP 4] FACT 기반 Fallback — 2025 진행 승인 지시 STEP4 §15
// + 개발자 재수정 지시(#3·#4·#5) 반영.
//
// [원칙 — §15 "fallback도 FACT 기반이어야 합니다. LLM 실패를 이유로 랜덤한 사주
// 문구를 보여주면 안 됩니다"] 이 파일은 LLM을 호출하지 않고, validateTopicForInterpret()
// 가 이미 산출한 evidenceNotes(topic-evidence.ts 평가자가 FACT를 직접 읽어 만든 서술형
// 근거)만을 재료로 고정 문장 틀에 끼워 넣는다. 완전히 LLM이 없어도 "이 사람의 FACT를
// 실제로 반영한" 결과가 나오게 하는 것이 목적이다.
//
// [재수정 #3 "fallback도 1,500~2,500자를 만족해야 함"] fallback은 interpret-service.ts
// 에서 LLM과 동일한 checkInterpretDetail()로 QA를 다시 받는다(이 파일은 QA를 직접
// 수행하지 않는다 — 중복 QA 금지, 재수정 #15). 따라서 이 파일의 책임은 "QA를 통과할
// 수 있을 만큼 충분히 길고 자연스러운 템플릿을 만드는 것"이다.
//
// [재수정 #4 "단순히 문장만 늘리는 방식 금지, 각 블록이 서로 다른 역할을 해야 함"]
// 5블록(①핵심특징 ②왜 ③실제생활 ④시기 ⑤포인트)마다 서로 다른 문장을 쓴다. 같은
// 문장을 복사해 분량만 채우지 않는다 — checkRepetition()이 정확히 이런 패턴을 잡아내므로
// (QA 재검증 대상이 됨) 구조적으로도 반복이 있으면 안 된다.
//
// [재수정 #5 "fallback에도 FACT 검증 적용" — 내부코드 노출 방지]
// topic-evidence.ts의 note 필드에는 "(A10 근거)", "(B01/B10 근거)", "(특이 조건)" 같은
// 내부 감사용 괄호 주석이 섞여 있다(예: "대운 전환점(A10 근거)"). 이를 그대로 문장에
// 끼워 넣으면 QA의 INTERNAL_LEAK_PATTERNS(`/\bA0?\d{1,2}\b/` 등)에 실제로 걸린다 —
// sanitizeEvidenceNote()가 모든 괄호 주석을 제거한 뒤에만 템플릿에 삽입한다.
import type { InterpretDetailResult, InterpretSummaryResult } from "./interpret-qa-check";

export interface FallbackTemplateJson {
  title: string;
  /** {{evidence_0}}, {{evidence_1}} 등의 플레이스홀더를 포함하는 2~3문장 틀. */
  summaryTemplate: string;
  evidenceTextTemplate: string;
  /** n=1,2,3,5(및 isTiming이면 4) 블록 본문 틀. */
  detailBlockTemplates: Record<string, string>;
}

/** [재수정 #5] topic-evidence.ts의 note는 내부 감사용 괄호 주석을 포함할 수 있다
 * (예: "대운 전환점(A10 근거)" → "대운 전환점", "일지 오행=용신/희신(특이 조건, 미충족시
 * 완전 미노출)" → "일지 오행=용신/희신"). 괄호와 그 내용을 전부 제거해 사용자 노출
 * 문장에 내부 코드/분류명이 섞여 들어가지 않게 한다. */
function sanitizeEvidenceNote(note: string): string {
  return note
    .replace(/[（(][^）)]*[）)]/g, "") // 전각/반각 괄호 주석 전부 제거
    .replace(/\s{2,}/g, " ")
    .trim();
}

/** [기본 틀 — DB에 fallbackJson이 없거나 파싱 실패했을 때만 쓰는 최후 방어선]
 * STEP6 29종×2 전체 시딩 전까지, 또는 특정 Topic의 fallbackJson이 손상된 경우에도
 * 이 템플릿 하나로 모든 Topic의 fallback을 감당해야 한다. 따라서 "이 Topic이 정확히
 * 무엇인지"는 모른 채로도 자연스럽게 읽히는 범용 문장이어야 하며, 동시에 분량(1,500~
 * 2,500자, 목표 1,800~2,200자) 기준도 만족해야 한다(재수정 #3). 5블록은 각각 다른
 * 역할의 문장으로 구성한다(재수정 #4 — 반복 금지). */
function defaultFallbackTemplate(topicName: string): FallbackTemplateJson {
  return {
    title: topicName,
    summaryTemplate:
      "사주 전체의 흐름을 보면 {{evidence_0}} 쪽의 기운이 눈에 띄게 자리 잡고 있어요. " +
      "이 흐름이 지금 이 이야기의 바탕이 되고 있으며, {{evidence_1}} 부분도 함께 참고할 만한 흐름이에요.",
    evidenceTextTemplate: "{{evidence_0}}의 흐름이 사주 전체에서 비교적 뚜렷하게 확인됩니다.",
    detailBlockTemplates: {
      "1":
        "사주 전체의 기운을 살펴보면, {{evidence_0}}와 관련된 흐름이 비교적 뚜렷하게 자리 잡고 있어요. " +
        "이런 흐름은 타고난 사주 배치에서 비롯된 것으로, 평소 어떤 상황에서 자연스러움이나 편안함을 느끼는지와도 " +
        "이어지는 경우가 많아요. 사주 하나로 사람의 전부를 설명할 수는 없지만, 이런 경향이 있다는 것을 미리 " +
        "알아두면 스스로를 이해하는 데 작은 도움이 될 수 있어요. 지금부터 이 흐름이 왜 나타나는지, 또 실제로는 " +
        "어떤 방식으로 드러나는지 차근차근 짚어볼게요. 사람마다 타고난 기운의 배치가 다르기 때문에, 같은 상황을 " +
        "마주하더라도 반응하는 방식이나 끌리는 선택이 저마다 다르게 나타나요. 지금 확인된 이 흐름도 당신만의 " +
        "고유한 특징 중 하나로 봐주시면 좋겠어요. 이 특징은 하루아침에 생긴 것이 아니라 태어날 때부터 가지고 " +
        "있던 기운의 배치에서 비롯된 것이라, 의식적으로 애쓰지 않아도 평소 생활 전반에 걸쳐 자연스럽게 묻어나는 " +
        "편이에요.",
      "2":
        "{{evidence_1}}이 이런 특징이 나타나는 바탕 중 하나로 보여요. 사주는 여러 기운이 서로 얽혀 균형을 " +
        "이루는 구조라서, 하나의 기운만 따로 떼어 보기보다는 주변 기운과의 관계 속에서 해석하는 것이 더 " +
        "정확해요. 지금 확인된 흐름도 단독으로 생긴 것이 아니라, 사주 전체의 배치가 서로 영향을 주고받으며 " +
        "만들어진 결과라고 볼 수 있어요. 이 점을 알고 나면 왜 이런 성향이나 흐름이 자연스럽게 느껴지는지 조금 더 " +
        "납득이 될 수 있어요. 기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고, 때로는 서로를 조절해주는 " +
        "관계가 되기도 하는데, 지금 이 흐름은 그 상호작용의 결과로 자연스럽게 자리 잡은 모습이에요. 그래서 " +
        "이 특징을 이해할 때는 한 가지 기운만 떼어서 보기보다, 사주 전체의 그림 안에서 바라보는 것이 더 입체적인 " +
        "이해로 이어질 수 있어요.",
      "3":
        "이런 기운은 보통 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많아요. " +
        "예를 들어 어떤 상황에서 더 편안함을 느끼는지, 반대로 어떤 상황에서 유독 신경이 쓰이는지를 돌아보면 " +
        "이 흐름이 실제로 삶 속에서 어떻게 작동하고 있는지 체감하기 쉬워져요. {{evidence_0}} 역시 이런 일상의 " +
        "맥락 속에서 조금씩 반복적으로 나타나는 편이에요. 특별한 사건이 없더라도 평소의 습관이나 선택 속에서 " +
        "이 기운이 은근히 작용하고 있다고 보면 돼요. 큰 결심이나 극적인 전환점보다는, 매일 반복되는 작은 " +
        "순간들 속에서 이 흐름을 알아차리는 연습을 해보시면 스스로를 더 잘 이해하는 데 도움이 될 수 있어요. " +
        "주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많으니, 평소 대화나 선택의 " +
        "패턴을 가볍게 돌아보는 것도 좋은 참고가 될 수 있어요.",
      "4":
        "{{evidence_timing}}은 이 흐름이 조금 더 또렷해질 수 있는 시기로 참고할 만해요. 다만 특정 날짜나 " +
        "사건을 단정하기보다는, 이 시기를 전후로 관련된 변화나 기회가 자연스럽게 이어질 수 있다는 정도로 " +
        "받아들이는 것이 좋아요. 변화가 찾아왔을 때 당황하지 않으려면, 이런 흐름이 있다는 것을 미리 알아두고 " +
        "마음의 여유를 가지는 것만으로도 충분히 도움이 돼요. 시기를 기다리기보다는 지금의 흐름을 차분히 " +
        "이어가는 태도가 더 중요해요. 시기는 어디까지나 흐름이 조금 더 두드러지는 구간을 가리킬 뿐이므로, " +
        "그 전후의 평소 흐름도 함께 꾸준히 살펴보는 것이 균형 잡힌 이해에 도움이 됩니다.",
      "5":
        "지금까지 살펴본 흐름을 종합하면, {{evidence_1}}이 당신의 사주에서 이번 이야기의 핵심 축이라고 " +
        "정리할 수 있어요. 이 기운을 억지로 거스르기보다는, 자신에게 맞는 속도와 방식으로 받아들이는 편이 " +
        "장기적으로 더 안정적인 결과로 이어지는 경우가 많아요. 남과 비교하기보다 스스로의 흐름을 존중하는 " +
        "태도가 중요하며, 오늘 확인한 이 이야기를 하나의 참고로 삼아 당신만의 방식으로 풀어가 보세요. 사주는 " +
        "정해진 운명을 통보하는 것이 아니라, 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가까워요. 이 " +
        "거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있을 거예요. " +
        "오늘 이 이야기가 스스로를 조금 더 이해하는 작은 계기가 되었으면 해요.",
    },
  };
}

function fillTemplate(template: string, evidenceNotesRaw: string[], timingNoteRaw?: string): string {
  const evidenceNotes = evidenceNotesRaw.map(sanitizeEvidenceNote).filter((n) => n.length > 0);
  const timingNote = timingNoteRaw ? sanitizeEvidenceNote(timingNoteRaw) : undefined;
  let out = template;
  evidenceNotes.forEach((note, i) => {
    out = out.replaceAll(`{{evidence_${i}}}`, note);
  });
  // 남은 evidence_N 플레이스홀더는 마지막 근거로 채우거나(근거가 1개뿐일 때), 그래도
  // 없으면 "사주 전체의 흐름"이라는 중립 표현으로 치환한다(절대 새로운 사실을 만들지 않음).
  out = out.replace(/\{\{evidence_\d+\}\}/g, evidenceNotes[0] ?? "사주 전체의 흐름");
  out = out.replace(/\{\{evidence_timing\}\}/g, timingNote ?? evidenceNotes[0] ?? "지금 이어지는 흐름");
  return out.trim();
}

export function parseFallbackTemplateJson(raw: string | null | undefined, topicName: string): FallbackTemplateJson {
  if (!raw) return defaultFallbackTemplate(topicName);
  try {
    const parsed = JSON.parse(raw) as Partial<FallbackTemplateJson>;
    if (
      typeof parsed.summaryTemplate === "string" &&
      typeof parsed.evidenceTextTemplate === "string" &&
      parsed.detailBlockTemplates &&
      typeof parsed.detailBlockTemplates === "object"
    ) {
      return {
        title: parsed.title ?? topicName,
        summaryTemplate: parsed.summaryTemplate,
        evidenceTextTemplate: parsed.evidenceTextTemplate,
        detailBlockTemplates: parsed.detailBlockTemplates as Record<string, string>,
      };
    }
  } catch {
    // fallthrough — 기본 틀 사용
  }
  return defaultFallbackTemplate(topicName);
}

export function buildFallbackSummary(params: {
  topicId: string;
  topicName: string;
  evidenceNotes: string[];
  fallbackJson: string | null | undefined;
}): InterpretSummaryResult {
  const tpl = parseFallbackTemplateJson(params.fallbackJson, params.topicName);
  return {
    topic_id: params.topicId,
    title: tpl.title,
    summary: fillTemplate(tpl.summaryTemplate, params.evidenceNotes),
    evidence: { type: "grid", text: fillTemplate(tpl.evidenceTextTemplate, params.evidenceNotes) },
    source: "template",
  };
}

export function buildFallbackDetail(params: {
  topicId: string;
  topicName: string;
  evidenceNotes: string[];
  isTiming: boolean;
  fallbackJson: string | null | undefined;
}): InterpretDetailResult {
  const tpl = parseFallbackTemplateJson(params.fallbackJson, params.topicName);
  const ns: Array<1 | 2 | 3 | 4 | 5> = params.isTiming ? [1, 2, 3, 4, 5] : [1, 2, 3, 5];
  const blocks = ns.map((n) => {
    const bodyTemplate = tpl.detailBlockTemplates[String(n)] ?? "{{evidence_0}}";
    const body = fillTemplate(bodyTemplate, params.evidenceNotes);
    if (n === 2) {
      return { n, body, evidence: { type: "grid" as const, text: fillTemplate(tpl.evidenceTextTemplate, params.evidenceNotes) } };
    }
    if (n === 4) {
      return { n, body, timing: { luck_index: 0 } };
    }
    return { n, body };
  });
  return {
    topic_id: params.topicId,
    title: tpl.title,
    blocks,
    source: "template",
  };
}
