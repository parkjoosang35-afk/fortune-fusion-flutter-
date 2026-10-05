// [STEP 6] TopicPromptTemplate 28종(29종 - scene 미확정 PERSONALITY_001) × 2모드
// 전체 시딩 — 2025 진행 승인 지시 STEP6 + 개발자 재지시(2026-10-05) 반영.
//
// [PERSONALITY_001 제외 이유] topic-contract-adapter.ts의 SCENE_UNRESOLVED_TOPIC_IDS에
// 등록된 유일한 topic_id. interpret/route.ts는 validateTopicForInterpret() 통과 여부와
// 무관하게 scene 검증 단계에서 PERSONALITY_001을 항상 TOPIC_SCENE_UNRESOLVED(404)로
// 거부하므로, 이 topic_id는 Prompt Template 조회 단계 자체에 절대 도달하지 않는다
// (디자인팀이 scene을 확정하기 전까지 임시값으로 시딩하지 않는다 — 개발자 지시 원문
// "PERSONALITY_001처럼 Scene 미확정 Topic은 임의로 시딩하지 말 것").
//
// [MONEY_006/LOVE_006 포함 이유] releasePhase=2(2차 릴리즈 예정)라 1차 릴리즈 기간
// 동안은 TOPIC_NOT_RELEASED(404)로 거부되어 역시 도달하지 않지만, 이 둘은 scene이
// 이미 확정(money/love)되어 있고 evidence 평가자도 구현되어 있어 PERSONALITY_001과
// 성격이 다르다(단지 "아직 공개 안 함"일 뿐 "정의 자체가 미완성"이 아님) — 향후
// releasePhase가 1로 전환되는 순간 바로 쓸 수 있도록 미리 시딩해 둔다.
//
// [내용 원칙 — 재지시 "29개 Topic 각각에 대해 실제 테스트 가능한 최소 1개 정상 Fact
// 시나리오를 확보"] 각 fallback 블록은 topic-evidence.ts가 실제로 산출하는 note를
// {{evidence_N}} 플레이스홀더로만 참조하고, 그 외의 새로운 사실(금액/날짜/사건)을
// 절대 만들지 않는다. 각 Topic의 5블록(①핵심특징 ②왜 ③실제생활 ④시기(시기형만)
// ⑤포인트)은 서로 다른 역할의 문장으로 작성해(interpret-qa-check.ts의
// checkRepetition이 동일 문장 2회 반복을 실패 처리함) 분량(1,500~2,500자, 목표
// 1,800~2,200자)을 "복붙"이 아닌 실제 서술 확장으로 채운다.
import { prisma } from "../src/lib/db";

export interface TemplateSeedItem {
  topicId: string;
  mode: "summary" | "detail";
  systemPrompt: string;
  fallbackJson: string;
}

export const TEMPLATES: TemplateSeedItem[] = [];

export async function seedAll(items: TemplateSeedItem[]) {
  let created = 0;
  let updated = 0;
  for (const t of items) {
    const existing = await prisma.topicPromptTemplate.findUnique({
      where: { topicId_mode_version: { topicId: t.topicId, mode: t.mode, version: 1 } },
    });
    await prisma.topicPromptTemplate.upsert({
      where: { topicId_mode_version: { topicId: t.topicId, mode: t.mode, version: 1 } },
      create: { topicId: t.topicId, mode: t.mode, systemPrompt: t.systemPrompt, fallbackJson: t.fallbackJson, version: 1, status: "active" },
      update: { systemPrompt: t.systemPrompt, fallbackJson: t.fallbackJson, status: "active" },
    });
    if (existing) updated++;
    else created++;
  }
  console.log(`[seed-topic-prompt-templates-full] created=${created} updated=${updated} total=${items.length}`);
}

// [실행 로직 — STEP6 "실제 Topic별 해석 테스트" 선행 조건] 5개 카테고리(topic-prompt-content/*.ts)
// 콘텐츠 작성이 전부 완료되어(MONEY 10 + TALENT 10 + RELATION 10 + LOVE 12 + LIFE 12
// = 56개) 분량(1,800~2,200자 목표/1,500~2,500자 허용) + QA(checkRepetition 등) 전부
// PASS된 상태이므로, 이제 DB(TopicPromptTemplate)에 실제로 upsert한다. 이 시딩이
// 완료되어야 비로소 interpret route.ts가 "TEMPLATE_NOT_FOUND → 즉시 fallback"이
// 아니라 실제 systemPrompt로 LLM을 호출하는 정식 경로를 탈 수 있다(단, LLM 호출
// 성공/실패와 무관하게 fallback도 동일 QA를 통과하므로 두 경로 모두 테스트 가능).
if (require.main === module) {
  void (async () => {
    const { MONEY_TEMPLATES } = await import("./topic-prompt-content/money");
    const { TALENT_TEMPLATES } = await import("./topic-prompt-content/talent");
    const { RELATION_TEMPLATES } = await import("./topic-prompt-content/relation");
    const { LOVE_TEMPLATES } = await import("./topic-prompt-content/love");
    const { LIFE_TEMPLATES } = await import("./topic-prompt-content/life");
    const all: TemplateSeedItem[] = [
      ...MONEY_TEMPLATES,
      ...TALENT_TEMPLATES,
      ...RELATION_TEMPLATES,
      ...LOVE_TEMPLATES,
      ...LIFE_TEMPLATES,
    ];
    console.log(`[seed-topic-prompt-templates-full] 총 ${all.length}개 템플릿 시딩 시작...`);
    await seedAll(all);
    await prisma.$disconnect();
  })();
}
