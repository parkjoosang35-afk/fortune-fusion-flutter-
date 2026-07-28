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
// 사용한다(tarot_yesno는 Flutter에 전용 UI가 아직 없어 이번 범위에서 제외).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

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

function isRefundEligibleSourceType(sourceType: string): boolean {
  return sourceType.startsWith("ai_") || sourceType.startsWith("fortune_");
}

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
  const spreadType = body.spreadType === "three_card" ? "three_card" : "one_card";
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

  try {
    // 1) 카드 뽑기(결정론적, LLM 연동 대상 아님)
    const cardCount = spreadType === "three_card" ? 3 : 1;
    const drawn = drawCards(question, cardCount);
    const labels = spreadType === "three_card" ? ["과거", "현재", "미래"] : ["오늘의 카드"];
    const positions = drawn.map((card, i) => ({
      label: labels[i],
      card,
      interpretation: card.meaning,
    }));

    // 2) 총평(summary)만 LLM으로 생성
    const domain = LOVE_TOPICS.has(topic) ? "tarot_love" : "tarot";
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: domain, isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    let summary = FALLBACK_SUMMARY;
    if (template) {
      const cardsDesc = positions
        .map((p) => `${p.label}: ${p.card.nameKr}${p.card.isReversed ? "(역방향)" : "(정방향)"} - ${p.card.meaning}`)
        .join("\n");
      const userPrompt = [
        `사용자 질문: ${question}`,
        `타로 스프레드: ${spreadType === "three_card" ? "3장(과거-현재-미래)" : "1장"}`,
        `뽑힌 카드:\n${cardsDesc}`,
        "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 스프레드에 대한 총평을 작성해주세요.",
      ].join("\n");

      try {
        summary = await completeText({ systemPrompt: template.templateBody, userPrompt });
      } catch (e) {
        console.error("[POST /api/public/fortune/tarot] LLM 호출 실패:", e);
      }
    }

    // 3) DB 트랜잭션: 잔액 확인 → 차감 → 환급 → 기록
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "ai_tarot_request" } });
      const cost = policy?.isActive ? policy.amount : 80;

      if (wallet.balance < cost) throw new Error("INSUFFICIENT_BALANCE");

      let balance = wallet.balance - cost;
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance, balanceSyncedAt: new Date() },
      });
      await tx.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId,
          amount: -cost,
          type: "spend",
          sourceType: "ai_tarot_request",
          balanceAfter: balance,
          memo: `타로 리딩(${spreadType})`,
        },
      });

      let refundAmount = 0;
      if (isRefundEligibleSourceType("ai_tarot_request")) {
        const config = await tx.economyConfig.findUnique({ where: { key: "refund_rate" } });
        const refundRate = config?.value ?? 0.5;
        refundAmount = Math.floor(cost * refundRate);
        if (refundAmount > 0) {
          balance += refundAmount;
          await tx.wallet.update({
            where: { id: wallet.id },
            data: { balance, balanceSyncedAt: new Date() },
          });
          await tx.pointHistory.create({
            data: {
              walletId: wallet.id,
              userId,
              amount: refundAmount,
              type: "earn",
              sourceType: "refund",
              balanceAfter: balance,
              memo: `타로 리딩 환급 (${Math.round(refundRate * 100)}%)`,
            },
          });
        }
      }

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
            resultMeta: JSON.stringify({ positions }),
            aiModel: "claude-haiku-4-5",
            promptTemplateId: template.id,
            promptVersion: template.version,
            status: "active",
          },
        });
      }

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, balance, refundAmount, cost, fortuneResult };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `tarot_${outcome.requestId}`,
          question,
          spreadType,
          topic,
          positions,
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
    if (message === "INSUFFICIENT_BALANCE") {
      return NextResponse.json(
        { success: false, error: "포인트가 부족합니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
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
