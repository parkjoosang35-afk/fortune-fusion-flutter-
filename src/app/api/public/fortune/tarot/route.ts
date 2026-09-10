// 공개(비인증) "타로 운세" 생성 API — Flutter TarotRepository.drawOneCard()/
// drawThreeCards()/drawYesNo() 및 5카드(five_card) 대응.
//
// [Phase6 - AI운세 실LLM 연동, 1차: 사주/타로 텍스트 전용] 카드 뽑기 자체(어떤
// 카드가 정/역방향으로 나오는지)는 여전히 결정론적 규칙(질문 해시 시드)으로
// 처리한다(Mock 시절과 동일 — 이 부분은 "운세 콘텐츠 생성"이 아니라 확률 게임
// 로직이라 LLM 연동 대상이 아니다). 이번 연동의 핵심은 "총평(summary)" 텍스트를
// rule-based 조합형 텍스트 대신 실제 LLM 응답으로 교체하는 것이다.
//
// [신통방통 타로 65종 주제 연동 - 서버 엔진 분리] 대표님 지시서에 따라 이 파일을
// 두 축으로 완전히 분리한다:
//   1) Card Draw Engine  — 78장 tarot_cards 기준 결정론적 추첨, 리딩 내 카드
//      중복 금지, 카드가 확정되면 절대 불변(어뷰징 방지 원칙).
//   2) AI Narrative Engine — topic/spread/position 메타데이터를 포함한 전체
//      페이로드를 프롬프트에 담아 LLM에 전달한다. AI는 카드를 임의로 바꾸지
//      못하고 오직 "이미 확정된 카드"에 대한 해석 텍스트만 생성한다.
//
// [신규 vs 레거시 분기] `tarot_topics.topic_key`에 매칭되는 행이 있으면(현재
// 1차 파일럿 5개: love_flow_of_crush/love_inner_truth/love_reunion_chance/
// career_job_change/wealth_fortune) 신규 엔진 경로(78장 풀덱 + DB 포지션
// 메타데이터)를 사용한다. 매칭되지 않으면(나머지 60개 주제 + general 등
// 기존 20개 topicKey) 기존 레거시 로직(15장 DECK + 하드코딩 라벨)을 100%
// 그대로 유지한다 — 화면/네비게이션 흐름 무변경 원칙, 미검증 60개 주제를
// 건드리지 않기 위함이다.
//
// [프롬프트 도메인 매핑] ai_prompt_templates에는 tarot(종합)/tarot_love(감정
// 관계운)/tarot_yesno(YES-NO) 3개 도메인이 있다. 레거시 경로는 topic이
// 연애 계열(love/reunion/crush/marriage)이면 tarot_love를, 그 외에는 tarot를
// 사용한다. 신규 경로는 tarot_topics.prompt_domain 컬럼을 그대로 사용한다.
//
// [운세 카테고리 확장] spreadType === "yes_no"이면 무조건 tarot_yesno 도메인을
// 사용하고(topic 무관, 레거시 경로 한정 — 신규 경로는 prompt_domain 사용),
// 카드 1장의 정/역방향으로 answer(YES/NO)를 결정론적으로 계산해 응답에
// 포함한다. 기존 one_card/three_card 흐름은 완전히 그대로 유지된다.
//
// [무료 광고형 구조 재정비 §신규발견] 타로 리딩은 복주머니(포인트)를 소비하지 않는다.
// 과거 point_policies(ai_tarot_request) 기반 차감→즉시환급 로직은 "복주머니는
// 소원게시판/소원성에서만 쓰는 유일한 재화" 원칙과 충돌하는 레거시 구조였다.
// 프리패스 상태와도 무관하게 항상 무료로 이용 가능하다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";
import { checkCategoryUsage, checkDailyAbsoluteLimit, consumeCategoryUsage } from "@/lib/open-pass-service";
import { drawFromFullDeck } from "@/lib/tarot/card-draw-engine";
import { getTopicWithPositions, buildTopicSummaryPrompt } from "@/lib/tarot/narrative-engine";
import { matchTopicFromQuestion } from "@/lib/tarot/topic-matcher";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// ══════════════════════════════════════════════════════════════════
// [레거시 경로] 기존 15장 DECK + 결정론적 추첨. tarot_topics에 매칭되지
// 않는 주제(60개 미검증 주제 + general 등)는 이 경로를 그대로 사용한다.
// ══════════════════════════════════════════════════════════════════
const DECK: { name: string; nameKr: string; up: string; down: string }[] = [
  { name: "The Fool", nameKr: "바보", up: "새로운 시작과 자유로운 도전", down: "무모한 행동이나 준비 부족 주의" },
  { name: "The Magician", nameKr: "마법사", up: "스스로의 능력과 의지로 원하는 것을 이루는 힘", down: "재능을 낭비하거나 자만하는 태도 주의" },
  { name: "The High Priestess", nameKr: "여사제", up: "직관을 믿고 내면의 목소리에 귀 기울여야 할 때", down: "직관을 무시하거나 혼란스러운 판단" },
  { name: "The Empress", nameKr: "여황제", up: "풍요와 안정, 따뜻한 결실", down: "과잉보호나 나태함으로 인한 정체" },
  { name: "The Emperor", nameKr: "황제", up: "체계와 안정을 바탕으로 목표를 향해 나아감", down: "고집이나 지나친 통제로 인한 갈등" },
  { name: "The Lovers", nameKr: "연인", up: "관계에서의 조화와 선택의 순간", down: "관계의 불균형이나 우유부단한 선택" },
  { name: "The Chariot", nameKr: "전차", up: "강한 의지로 장애물을 극복하고 나아갈 힘", down: "방향을 잃거나 통제력을 상실할 위험" },
  { name: "Strength", nameKr: "힘", up: "부드러움 속의 강인함으로 어려움을 이겨냄", down: "자신감 부족이나 감정 조절의 어려움" },
  { name: "The Hermit", nameKr: "은둔자", up: "잠시 멈추고 스스로를 돌아보는 시간", down: "고립감이나 지나친 회피 성향 주의" },
  { name: "Wheel of Fortune", nameKr: "운명의 수레바퀴", up: "변화의 흐름이 유리하게 작용", down: "뜻하지 않은 변수나 불운한 타이밍" },
  { name: "Justice", nameKr: "정의", up: "공정한 판단과 균형", down: "불공정함이나 왜곡된 판단 경계" },
  { name: "The Star", nameKr: "별", up: "희망과 치유, 밝은 미래에 대한 기대", down: "자신감 상실이나 막막함" },
  { name: "The Sun", nameKr: "태양", up: "성공과 활력, 밝은 에너지", down: "지나친 낙관이나 과시욕 주의" },
  { name: "The Moon", nameKr: "달", up: "불확실함 속에서도 직관을 믿어야 할 때", down: "불안과 혼란, 숨겨진 진실 경계" },
  { name: "The World", nameKr: "세계", up: "완성과 성취, 여정의 마무리", down: "마무리가 지연되거나 미완성으로 남는 아쉬움" },
];

const LOVE_TOPICS = new Set(["love", "reunion", "crush", "marriage"]);

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

function drawLegacyCards(question: string, count: number) {
  const seed = hashSeed(question);
  const indices: number[] = [];
  let cursor = seed;
  while (indices.length < count) {
    cursor = (cursor * 1103515245 + 12345) & 0x7fffffff;
    const idx = cursor % DECK.length;
    if (!indices.includes(idx) || count > DECK.length) indices.push(idx);
    if (indices.length >= DECK.length && count > DECK.length) break;
  }
  return indices.map((idx, i) => {
    const meta = DECK[idx];
    const reversed = (seed + idx + i) % 3 === 0;
    return {
      id: `card_${idx}_${i}`,
      name: meta.name,
      nameKr: meta.nameKr,
      isReversed: reversed,
      meaning: reversed ? meta.down : meta.up,
    };
  });
}

const FALLBACK_SUMMARY =
  "카드가 전하는 흐름을 천천히 따라가 보면, 지금의 선택이 앞으로의 방향을 결정짓게 됩니다. 조급해하지 말고 마음의 소리에 귀 기울여 보세요.";

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    question?: string;
    spreadType?: string;
    topic?: string;
    // [65종 타로 리딩엔진 §계획4 A/B 양자택일] choice_ab 스프레드 전용 —
    // 사용자가 비교하려는 두 선택지의 실제 텍스트. daily_direction_of_choice
    // 주제에서만 사용되며, 다른 스프레드에서는 무시된다.
    optionA?: string;
    optionB?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const question = body.question?.trim();
  const rawSpreadType = body.spreadType ?? "one_card";
  const requestedTopic = body.topic ?? "general";
  const optionA = body.optionA?.trim();
  const optionB = body.optionB?.trim();

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!question) {
    return NextResponse.json(
      { success: false, error: "question이 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // ── [신통방통 타로 65종 주제 연동 §계획2 자유질문 자동매칭] ──
  // 카테고리 상세화면을 거쳐 명시적으로 topic이 지정된 경우(레거시
  // general/love가 아닌 값)는 사용자의 의도를 그대로 존중해 자동매칭을
  // 건드리지 않는다. topic이 레거시 기본값(general/love)일 때만 —
  // 즉 "자유질문" 입력 화면에서 주제를 별도로 고르지 않은 경우에만 —
  // 질문 문장을 분석해 65개 주제 중 하나로 자동 라우팅을 시도한다.
  // choice_ab 전용 daily_direction_of_choice는 topic-keywords.ts에서
  // 의도적으로 제외되어 있어 자동매칭으로는 절대 선택되지 않는다
  // (optionA/optionB 필수 파라미터 누락으로 오류가 나는 것을 방지).
  const isLegacyDefaultTopic = requestedTopic === "general" || requestedTopic === "love";
  const autoMatchedTopic = isLegacyDefaultTopic ? matchTopicFromQuestion(question) : null;
  const topic = autoMatchedTopic ?? requestedTopic;

  // ── [어뷰징 방지 개편 §신규 ①] 유저별 절대 일일 AI 호출 상한(5회) 검사 ──
  // 프리패스 카테고리별 제한(아래)과 완전히 독립적인 2중 방어선. 프리패스를 재발급받아도
  // 이 상한은 우회되지 않는다(하루 전체 fortuneRequest 성공 건수 기준).
  const dailyLimitCheck = await checkDailyAbsoluteLimit(userId);
  if (!dailyLimitCheck.allowed) {
    return NextResponse.json(
      {
        success: false,
        error: `하루 이용 가능한 AI 운세 횟수(${dailyLimitCheck.maxUsage}회)를 모두 사용했습니다. 내일 다시 이용해주세요.`,
        reason: "DAILY_ABSOLUTE_LIMIT_REACHED",
        usageCount: dailyLimitCheck.usageCount,
        maxUsage: dailyLimitCheck.maxUsage,
      },
      { status: 403, headers: CORS_HEADERS }
    );
  }

  // ── [신통방통 타로 65종 주제 연동] 신규 vs 레거시 경로 분기 판정 ──
  // topic(Flutter가 보내는 값)이 tarot_topics.topic_key와 매칭되면 신규
  // 엔진 경로. 매칭 실패하면 완전히 기존 레거시 경로로 처리한다.
  const pilotTopic = await getTopicWithPositions(topic);

  // ── [STEP8 - 프리패스 카테고리별 이용횟수 검증] ──
  // fortune_categories에는 tarot/tarot_yesno/tarot_love 3개 category_key가 별도로
  // 존재하므로, 아래 domain 산출과 동일한 규칙으로 categoryKey를 미리 결정해
  // 카테고리별로 독립적으로 카운트한다(예: 종합 타로 2회 소진해도 YES/NO는 별도 2회 이용 가능).
  // [신규 경로] pilotTopic이 있으면 promptDomain을 그대로 categoryKey로 사용해
  // 기존 3개 카테고리 체계에 자연스럽게 편입시킨다(신규 categoryKey를 만들지
  // 않음 — fortune_categories에 새 행을 추가하지 않고도 어뷰징 방지가 그대로 적용됨).
  const spreadType = pilotTopic
    ? rawSpreadType
    : rawSpreadType === "three_card"
      ? "three_card"
      : rawSpreadType === "five_card"
        ? "five_card"
        : rawSpreadType === "yes_no"
          ? "yes_no"
          : "one_card";

  const categoryKey = pilotTopic
    ? pilotTopic.promptDomain === "tarot_yesno" || spreadType === "yes_no"
      ? "tarot_yesno"
      : pilotTopic.promptDomain === "tarot_love"
        ? "tarot_love"
        : "tarot"
    : spreadType === "yes_no"
      ? "tarot_yesno"
      : LOVE_TOPICS.has(topic)
        ? "tarot_love"
        : "tarot";

  const usageCheck = await checkCategoryUsage(userId, categoryKey);
  if (!usageCheck.allowed) {
    return NextResponse.json(
      {
        success: false,
        error:
          usageCheck.reason === "CATEGORY_LIMIT_REACHED"
            ? `오늘 이 프리패스로 이용할 수 있는 횟수(${usageCheck.maxUsage}회)를 모두 사용했습니다.`
            : "유효한 프리패스가 없습니다. 광고 시청, 파트너 방문 또는 구독으로 프리패스를 받아보세요.",
        reason: usageCheck.reason,
        usageCount: usageCheck.usageCount,
        maxUsage: usageCheck.maxUsage,
      },
      { status: 403, headers: CORS_HEADERS }
    );
  }

  try {
    let positions: { label: string; card: { id: string; name: string; nameKr: string; isReversed: boolean; meaning?: string }; interpretation: string }[];
    let answer: string | undefined;
    let summary = FALLBACK_SUMMARY;
    let template: { id: number; version: number; templateBody: string } | null = null;

    if (pilotTopic) {
      // ══════════════════════════════════════════════════════════════
      // [신규 엔진 경로] Card Draw Engine(78장, 중복없음, 확정 후 불변)
      // → AI Narrative Engine(topic/position 메타데이터 포함 프롬프트)
      // ══════════════════════════════════════════════════════════════
      if (
        spreadType !== "one_card" &&
        spreadType !== "three_card" &&
        spreadType !== "five_card" &&
        spreadType !== "yes_no" &&
        spreadType !== "choice_ab"
      ) {
        return NextResponse.json(
          { success: false, error: "지원하지 않는 스프레드입니다." },
          { status: 400, headers: CORS_HEADERS }
        );
      }
      if (!pilotTopic.allowedSpreads.includes(spreadType)) {
        return NextResponse.json(
          { success: false, error: "이 주제에서 지원하지 않는 스프레드입니다." },
          { status: 400, headers: CORS_HEADERS }
        );
      }
      if (spreadType === "yes_no" && !pilotTopic.yesNoEnabled) {
        return NextResponse.json(
          { success: false, error: "이 주제에서는 YES/NO 스프레드를 지원하지 않습니다." },
          { status: 400, headers: CORS_HEADERS }
        );
      }
      // [65종 타로 리딩엔진 §계획4 A/B 양자택일] choice_ab는 isChoiceAb=true인
      // 주제에서만 허용하고, 비교할 두 선택지 텍스트가 반드시 필요하다.
      if (spreadType === "choice_ab") {
        if (!pilotTopic.isChoiceAb) {
          return NextResponse.json(
            { success: false, error: "이 주제에서는 A/B 양자택일 스프레드를 지원하지 않습니다." },
            { status: 400, headers: CORS_HEADERS }
          );
        }
        if (!optionA || !optionB) {
          return NextResponse.json(
            { success: false, error: "비교할 두 선택지(optionA, optionB)를 모두 입력해주세요." },
            { status: 400, headers: CORS_HEADERS }
          );
        }
      }

      const positionMetas = pilotTopic.positionsBySpread[spreadType];
      if (!positionMetas || positionMetas.length === 0) {
        return NextResponse.json(
          { success: false, error: "이 주제의 포지션 구성을 찾을 수 없습니다." },
          { status: 500, headers: CORS_HEADERS }
        );
      }

      // 1) Card Draw Engine — 78장 기준, 리딩 내 카드 중복 금지, 결정론적(시드) 추첨.
      // [choice_ab] 선택지 텍스트가 바뀌면 카드도 달라져야 하므로(같은 질문이라도
      // "이직한다"/"그대로 있는다"를 서로 다른 선택지로 바꿔 다시 물으면 새 리딩이
      // 되어야 한다), 시드에 optionA/optionB를 포함시킨다. 5개 포지션(A현재/A결과/
      // B현재/B결과/최종조언)을 여전히 78장 중 중복없이 한 번에 추첨한다.
      const drawSeed =
        spreadType === "choice_ab" ? `${question}::${optionA}::${optionB}` : question;
      const drawn = await drawFromFullDeck(drawSeed, positionMetas.length);

      positions = drawn.map((card, i) => ({
        label: positionMetas[i].positionName,
        card: {
          id: card.id,
          name: card.name,
          nameKr: card.nameKr,
          isReversed: card.isReversed,
        },
        interpretation: card.meaning,
      }));

      answer =
        spreadType === "yes_no" ? (drawn[0].isReversed ? "NO" : "YES") : undefined;

      // 2) AI Narrative Engine — topic/position 전체 메타데이터를 프롬프트에 담아 전달.
      // AI는 이미 확정된 카드에 대한 해석 텍스트만 생성하며, 카드 자체를 바꿀 수 없다.
      template = await prisma.aiPromptTemplate.findFirst({
        where: { fortuneTypeOrDomain: pilotTopic.promptDomain, isActive: true },
        select: { id: true, version: true, templateBody: true },
      });

      if (template) {
        const userPrompt = buildTopicSummaryPrompt({
          topic: pilotTopic,
          spreadType,
          question,
          drawnCards: drawn,
          positionMetas,
          answer,
          optionA: spreadType === "choice_ab" ? optionA : undefined,
          optionB: spreadType === "choice_ab" ? optionB : undefined,
        });
        try {
          summary = await completeText({ systemPrompt: template.templateBody, userPrompt });
        } catch (e) {
          console.error("[POST /api/public/fortune/tarot] (신규경로) LLM 호출 실패:", e);
        }
      }
    } else {
      // ══════════════════════════════════════════════════════════════
      // [레거시 경로] 기존 15장 DECK + 하드코딩 라벨 유지.
      // [버그수정 §five_card] 기존에는 여기서 five_card가 처리되지 않아
      // 무조건 one_card(1장)로 강제 변환되는 버그가 있었다(사용자 리포트:
      // "5장/3장을 뽑았는데 1장만 나온다"). three_card/yes_no와 동일한
      // 패턴으로 five_card 분기를 명시적으로 추가해 5장이 정상 반환되도록
      // 수정. DECK.length(15) > 5이므로 drawLegacyCards의 중복방지 로직이
      // 문제없이 5장을 뽑는다.
      // ══════════════════════════════════════════════════════════════
      const cardCount =
        spreadType === "five_card" ? 5 : spreadType === "three_card" ? 3 : 1;
      const drawn = drawLegacyCards(question, cardCount);
      const labels =
        spreadType === "five_card"
          ? ["현재 상황", "숨겨진 영향", "장애물", "조언", "결과"]
          : spreadType === "three_card"
            ? ["과거", "현재", "미래"]
            : spreadType === "yes_no"
              ? ["답변"]
              : ["오늘의 카드"];
      positions = drawn.map((card, i) => ({
        label: labels[i],
        card,
        interpretation: card.meaning,
      }));

      // [YES/NO] 카드 정/역방향으로 결정론적 answer 산출(정방향=YES, 역방향=NO).
      answer =
        spreadType === "yes_no" ? (drawn[0].isReversed ? "NO" : "YES") : undefined;

      const domain =
        spreadType === "yes_no"
          ? "tarot_yesno"
          : LOVE_TOPICS.has(topic)
            ? "tarot_love"
            : "tarot";
      template = await prisma.aiPromptTemplate.findFirst({
        where: { fortuneTypeOrDomain: domain, isActive: true },
        select: { id: true, version: true, templateBody: true },
      });

      if (template) {
        const cardsDesc = positions
          .map((p) => `${p.label}: ${p.card.nameKr}${p.card.isReversed ? "(역방향)" : "(정방향)"} - ${p.card.meaning}`)
          .join("\n");
        const spreadDesc =
          spreadType === "five_card"
            ? "5장(현재 상황-숨겨진 영향-장애물-조언-결과)"
            : spreadType === "three_card"
              ? "3장(과거-현재-미래)"
              : spreadType === "yes_no"
                ? "YES/NO 1장"
                : "1장";
        const userPromptLines = [
          `사용자 질문: ${question}`,
          `타로 스프레드: ${spreadDesc}`,
          `뽑힌 카드:\n${cardsDesc}`,
        ];
        if (answer) {
          userPromptLines.push(
            `카드가 가리키는 방향: ${answer}`,
            "답변은 반드시 YES 또는 NO 방향을 먼저 명확히 밝히고, 그 이유와 행동 힌트를 함께 제시하세요. YES/NO만 단답으로 끝내지 마세요."
          );
        }
        userPromptLines.push("위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 스프레드에 대한 총평을 작성해주세요.");
        const userPrompt = userPromptLines.join("\n");

        try {
          summary = await completeText({ systemPrompt: template.templateBody, userPrompt });
        } catch (e) {
          console.error("[POST /api/public/fortune/tarot] LLM 호출 실패:", e);
        }
      }
    }

    // 3) DB 트랜잭션: fortune_requests/results 기록(포인트 차감 없음)
    // [어뷰징 방지] reading_id는 fortuneRequest.id 생성 시점에 고유하게 확정되고,
    // positions(확정된 카드)는 resultMeta에 그대로 스냅샷 저장되어 이후 절대
    // 변경되지 않는다. "재뽑기"는 이 트랜잭션과 무관한 별도의 새 POST 요청
    // (= 별도 리딩)으로만 가능하다.
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      // [무료 광고형 구조 재정비 §신규발견] 타로 리딩은 완전 무료 — 차감/환급 없음.
      const balance = wallet.balance;
      const cost = 0;
      const refundAmount = 0;

      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "tarot",
          inputPayload: JSON.stringify({ question, spreadType, topic, optionA, optionB }),
          sourceType: "ai_generated",
          pointSpent: cost,
          status: "success",
        },
      });

      let fortuneResult = null;
      if (template) {
        fortuneResult = await tx.fortuneResult.create({
          data: {
            requestId: fortuneRequest.id,
            resultText: summary,
            resultMeta: JSON.stringify({ positions, answer }),
            aiModel: "claude-haiku-4-5",
            promptTemplateId: template.id,
            promptVersion: template.version,
            status: "active",
          },
        });
      }

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, balance, refundAmount, cost, fortuneResult };
    });

    // ── [STEP8] 실제 분석 성공 후에만 카테고리 이용횟수 +1 ──
    if (usageCheck.userPassId != null) {
      await consumeCategoryUsage(usageCheck.userPassId, userId, categoryKey);
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `tarot_${outcome.requestId}`,
          question,
          spreadType,
          topic,
          // [§계획2 자유질문 자동매칭] 자동매칭이 실제로 일어났을 때만
          // true + 주제 이름을 함께 내려줘 Flutter가 "이 질문은 'OO' 주제로
          // 자동 매칭되었어요" 같은 안내를 표시할 수 있게 한다. 매칭이 없던
          // 경우(레거시 경로 그대로)는 undefined -> 필드 생략, 기존 응답과
          // 100% 동일하게 유지된다.
          autoMatchedTopic: autoMatchedTopic ? topic : undefined,
          autoMatchedTopicName: autoMatchedTopic ? pilotTopic?.topicName : undefined,
          positions,
          answer,
          // [65종 타로 리딩엔진 §계획4 A/B 양자택일] choice_ab가 아닐 때는
          // undefined -> JSON에서 필드 자체가 생략되어 기존 응답과 100% 동일.
          optionA: spreadType === "choice_ab" ? optionA : undefined,
          optionB: spreadType === "choice_ab" ? optionB : undefined,
          summary,
          createdAt: outcome.createdAt.toISOString(),
          balance: outcome.balance,
          refundAmount: outcome.refundAmount,
          pointSpent: outcome.cost,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WALLET_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "지갑을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (e instanceof LlmClientError) {
      console.error("[POST /api/public/fortune/tarot] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/fortune/tarot] 실패:", e);
    return NextResponse.json(
      { success: false, error: "타로 리딩 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
