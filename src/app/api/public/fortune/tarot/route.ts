// 공개(비인증) "타로 운세" 생성 API — Flutter TarotRepository.drawOneCard()/
// drawThreeCards() 대응.
//
// [Phase6 - AI운세 실LLM 연동, 1차: 사주/타로 텍스트 전용] 카드 뽑기 자체(어떤
// 카드가 정/역방향으로 나오는지)는 여전히 결정론적 규칙(질문 해시 시드)으로
// 처리한다(Mock 시절과 동일 — 이 부분은 "운세 콘텐츠 생성"이 아니라 확률 게임
// 로직이라 LLM 연동 대상이 아니다). 이번 연동의 핵심은 "총평(summary)" 텍스트를
// rule-based 조합형 텍스트 대신 실제 LLM 응답으로 교체하는 것이다.
//
// [프롬프트 도메인 매핑] ai_prompt_templates에는 tarot(종합)/tarot_love(감정
// 관계운)/tarot_yesno(YES-NO) 3개 도메인이 있다. Flutter가 보내는 topic이
// 연애 계열(love/reunion/crush/marriage)이면 tarot_love를, 그 외에는 tarot를
// 사용한다.
//
// [운세 카테고리 확장] spreadType === "yes_no"이면 무조건 tarot_yesno 도메인을
// 사용하고(topic 무관), 카드 1장의 정/역방향으로 answer(YES/NO)를 결정론적으로
// 계산해 응답에 포함한다. 기존 one_card/three_card 흐름은 완전히 그대로 유지된다.
//
// [무료 광고형 구조 재정비 §신규발견] 타로 리딩은 복주머니(포인트)를 소비하지 않는다.
// 과거 point_policies(ai_tarot_request) 기반 차감→즉시환급 로직은 "복주머니는
// 소원게시판/소원성에서만 쓰는 유일한 재화" 원칙과 충돌하는 레거시 구조였다.
// 프리패스 상태와도 무관하게 항상 무료로 이용 가능하다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";
import { checkCategoryUsage, consumeCategoryUsage } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

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

function drawCards(question: string, count: number) {
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
  const spreadType =
    body.spreadType === "three_card"
      ? "three_card"
      : body.spreadType === "yes_no"
        ? "yes_no"
        : "one_card";
  const topic = body.topic ?? "general";

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

  // ── [STEP8 - 프리패스 카테고리별 이용횟수 검증] ──
  // fortune_categories에는 tarot/tarot_yesno/tarot_love 3개 category_key가 별도로
  // 존재하므로, 아래 domain 산출과 동일한 규칙으로 categoryKey를 미리 결정해
  // 카테고리별로 독립적으로 카운트한다(예: 종합 타로 2회 소진해도 YES/NO는 별도 2회 이용 가능).
  const categoryKey =
    spreadType === "yes_no" ? "tarot_yesno" : LOVE_TOPICS.has(topic) ? "tarot_love" : "tarot";
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
    // 1) 카드 뽑기(결정론적, LLM 연동 대상 아님)
    const cardCount = spreadType === "three_card" ? 3 : 1;
    const drawn = drawCards(question, cardCount);
    const labels =
      spreadType === "three_card"
        ? ["과거", "현재", "미래"]
        : spreadType === "yes_no"
          ? ["답변"]
          : ["오늘의 카드"];
    const positions = drawn.map((card, i) => ({
      label: labels[i],
      card,
      interpretation: card.meaning,
    }));

    // [YES/NO] 카드 정/역방향으로 결정론적 answer 산출(정방향=YES, 역방향=NO).
    // YES/NO 스프레드가 아니면 undefined(응답 JSON에서 생략)로 기존 흐름과 동일하게 유지.
    const answer =
      spreadType === "yes_no" ? (drawn[0].isReversed ? "NO" : "YES") : undefined;

    // 2) 총평(summary)만 LLM으로 생성
    // YES/NO는 topic과 무관하게 항상 tarot_yesno 도메인을 사용한다.
    const domain =
      spreadType === "yes_no"
        ? "tarot_yesno"
        : LOVE_TOPICS.has(topic)
          ? "tarot_love"
          : "tarot";
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: domain, isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    let summary = FALLBACK_SUMMARY;
    if (template) {
      const cardsDesc = positions
        .map((p) => `${p.label}: ${p.card.nameKr}${p.card.isReversed ? "(역방향)" : "(정방향)"} - ${p.card.meaning}`)
        .join("\n");
      const spreadDesc =
        spreadType === "three_card"
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

    // 3) DB 트랜잭션: fortune_requests/results 기록(포인트 차감 없음)
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
          inputPayload: JSON.stringify({ question, spreadType, topic }),
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
          positions,
          answer,
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
