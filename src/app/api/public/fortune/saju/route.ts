// 공개(비인증) "사주 운세" 생성 API — Flutter SajuRepository.requestSaju() 대응.
//
// [Phase6 - AI운세 실LLM 연동, 1차: 사주/타로 텍스트 전용] 지금까지 Flutter는
// 완전히 로컬 Mock(시드 기반 하드코딩 텍스트풀)으로만 사주 결과를 생성했다.
// 이 라우트를 신설하여 ai_prompt_templates(도메인: saju/saju_wealth/saju_career/
// saju_love/saju_health)에 등록된 실제 프롬프트를 LLM(GSK_TOKEN 기반 Proxy)에
// 전달해 진짜 AI 생성 텍스트를 받아온다.
//
// [범위 결정] 사주 명식(십간십이지 4주)과 오행 점수는 실제 역학 계산이 아니라
// 여전히 결정론적 규칙(생년월일 해시) 기반으로 생성한다(Mock 시절과 동일).
// 이번 연동의 핵심은 "주제별 해석 텍스트"를 rule-based 텍스트풀 대신 실제
// LLM 응답으로 교체하는 것이다(사용자에게 이미 안내한 1차 범위와 일치).
//
// [트랜잭션 설계] LLM 호출은 네트워크 왕복이 필요해 DB 트랜잭션 밖에서 먼저
// 수행하고(포인트 차감 전에 콘텐츠를 확보), 이후 짧은 DB 트랜잭션에서
// 잔액을 다시 확인하며 차감→환급→fortune_requests/results 기록을 원자적으로 처리한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const STEMS = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const BRANCHES = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];

const TOPIC_DOMAIN: Record<string, string> = {
  종합: "saju",
  재물: "saju_wealth",
  애정: "saju_love",
  직업: "saju_career",
  건강: "saju_health",
  // [운세 카테고리 확장] 사주 월별 운세(saju_monthly) — 기존 다중 토픽 선택 방식을
  // 그대로 재사용해 신규 도메인만 추가 연결한다(입력화면/결과화면 변경 없음).
  월별: "saju_monthly",
};

const FALLBACK_TEXT_BY_TOPIC: Record<string, string> = {
  종합: "전반적으로 안정과 성장이 조화를 이루는 시기입니다. 스스로의 페이스를 지키며 꾸준히 나아간다면 좋은 결실을 맺을 수 있습니다.",
  재물: "안정적인 재물운이 이어지는 흐름입니다. 무리한 투자보다는 계획적인 소비와 저축이 유리합니다.",
  애정: "인간관계에서 따뜻한 기운이 감돌고 있습니다. 서로에 대한 신뢰를 쌓아가는 시기입니다.",
  직업: "주변의 인정을 받으며 성장할 수 있는 흐름입니다. 신중하게 기회를 살펴보세요.",
  건강: "전반적으로 무난하나 과로에 주의가 필요합니다. 규칙적인 생활 패턴을 유지하세요.",
  월별: "이번 달은 준비와 정리가 함께 필요한 시기입니다. 초반에는 신중하게 상황을 살피고, 중반 이후 서서히 기회가 열리니 무리한 결정은 뒤로 미루는 것이 좋습니다.",
};

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

function computeChart(birthDate: string, hasBirthTime: boolean) {
  const seed = hashSeed(birthDate);
  const pillar = (offset: number) =>
    `${STEMS[(seed + offset) % 10]}${BRANCHES[(seed + offset * 3) % 12]}`;

  const pillars = {
    year: pillar(1),
    month: pillar(2),
    day: pillar(3),
    hour: hasBirthTime ? pillar(4) : null,
  };
  const fiveElements = {
    목: 10 + (seed % 20),
    화: 10 + ((seed >> 1) % 20),
    토: 10 + ((seed >> 2) % 20),
    금: 10 + ((seed >> 3) % 20),
    수: 10 + ((seed >> 4) % 20),
  };
  return { pillars, fiveElements, seed };
}

function isRefundEligibleSourceType(sourceType: string): boolean {
  return sourceType.startsWith("ai_") || sourceType.startsWith("fortune_");
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    birthDate?: string;
    birthTime?: string;
    isLunar?: boolean;
    topics?: string[];
    profileId?: string;
    profileName?: string;
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
  const birthDate = body.birthDate;
  const birthTime = body.birthTime ?? null;
  const isLunar = Boolean(body.isLunar);
  const topics = body.topics && body.topics.length > 0 ? body.topics : ["종합"];
  const profileId = body.profileId ?? null;
  const profileName = body.profileName ?? null;

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!birthDate || typeof birthDate !== "string") {
    return NextResponse.json(
      { success: false, error: "birthDate가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 1) 명식/오행은 여전히 결정론적 규칙으로 계산(범위 밖)
    const { pillars, fiveElements } = computeChart(birthDate, !!birthTime);

    // 2) 주제별 활성 프롬프트 템플릿을 조회하고 LLM을 호출(DB 트랜잭션 밖에서 먼저 수행)
    const uniqueTopics = Array.from(new Set(topics));
    const topicResults: Record<string, string> = {};
    let primaryTemplate: { id: number; version: number } | null = null;

    for (const topic of uniqueTopics) {
      const domain = TOPIC_DOMAIN[topic] ?? "saju";
      const template = await prisma.aiPromptTemplate.findFirst({
        where: { fortuneTypeOrDomain: domain, isActive: true },
        select: { id: true, version: true, templateBody: true },
      });

      if (!primaryTemplate || topic === "종합") {
        if (template) primaryTemplate = { id: template.id, version: template.version };
      }

      if (!template) {
        topicResults[topic] = FALLBACK_TEXT_BY_TOPIC[topic] ?? FALLBACK_TEXT_BY_TOPIC["종합"];
        continue;
      }

      const userPrompt = [
        `사용자 정보: 생년월일 ${birthDate}(${isLunar ? "음력" : "양력"})`,
        birthTime ? `태어난 시간: ${birthTime}` : "태어난 시간: 미상",
        `요청 주제: ${topic}`,
        "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 사람의 운세를 작성해주세요.",
      ].join("\n");

      try {
        const text = await completeText({
          systemPrompt: template.templateBody,
          userPrompt,
        });
        topicResults[topic] = text;
      } catch (e) {
        console.error(`[POST /api/public/fortune/saju] LLM 호출 실패(topic=${topic}):`, e);
        topicResults[topic] = FALLBACK_TEXT_BY_TOPIC[topic] ?? FALLBACK_TEXT_BY_TOPIC["종합"];
      }
    }

    const summary = topicResults["종합"] ?? Object.values(topicResults)[0] ?? "";

    // 3) 짧은 DB 트랜잭션: 잔액 재확인 → 차감 → 환급 → 기록
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      const policy = await tx.pointPolicy.findUnique({
        where: { sourceType: "ai_saju_request" },
      });
      const cost = policy?.isActive ? policy.amount : 100;

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
          sourceType: "ai_saju_request",
          balanceAfter: balance,
          memo: `사주 운세 조회(${uniqueTopics.join(",")})`,
        },
      });

      let refundAmount = 0;
      if (isRefundEligibleSourceType("ai_saju_request")) {
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
              memo: `사주 운세 조회 환급 (${Math.round(refundRate * 100)}%)`,
            },
          });
        }
      }

      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "saju",
          inputPayload: JSON.stringify({ birthDate, birthTime, isLunar, topics: uniqueTopics, profileId, profileName }),
          sourceType: "ai_generated",
          pointSpent: cost,
          status: "success",
        },
      });

      let fortuneResult = null;
      if (primaryTemplate) {
        fortuneResult = await tx.fortuneResult.create({
          data: {
            requestId: fortuneRequest.id,
            resultText: summary,
            resultMeta: JSON.stringify({ pillars, fiveElements, topicResults }),
            aiModel: "claude-haiku-4-5",
            promptTemplateId: primaryTemplate.id,
            promptVersion: primaryTemplate.version,
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
          id: `saju_${outcome.requestId}`,
          pillars,
          fiveElements,
          topicResults,
          summary,
          createdAt: outcome.createdAt.toISOString(),
          profileId,
          profileName,
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
      console.error("[POST /api/public/fortune/saju] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/fortune/saju] 실패:", e);
    return NextResponse.json(
      { success: false, error: "사주 분석 중 오류가 발생했습니다." },
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
