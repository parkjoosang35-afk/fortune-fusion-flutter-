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
// 수행하고, 이후 짧은 DB 트랜잭션에서 fortune_requests/results 기록을 처리한다.
//
// [무료 광고형 구조 재정비 §신규발견] 사주 운세 열람은 복주머니(포인트)를 소비하지
// 않는다. 과거 point_policies(ai_saju_request) 기반 차감→즉시환급 로직은 "복주머니는
// 소원게시판/소원성에서만 쓰는 유일한 재화" 원칙과 충돌하는 레거시 구조였다.
// 프리패스 상태와도 무관하게 항상 무료로 열람 가능하다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";
import { checkCategoryUsage, consumeCategoryUsage } from "@/lib/open-pass-service";

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

  // ── [STEP8 - 프리패스 카테고리별 이용횟수 검증] ──
  // 사주는 fortune_categories.requires_pass=true(프리패스 필수 카테고리)이므로,
  // 클라이언트 진입 게이트(navigateWithPassGate/CategoryGate)를 우회한 직접 호출도
  // 서버에서 동일하게 차단해야 한다(§8 "기존 API 앞단에 인증→프리패스 검증→
  // 이용횟수 검증만 추가" 원칙). 실제 usageCount 증가는 아래 트랜잭션 성공 후에만 한다.
  const usageCheck = await checkCategoryUsage(userId, "saju");
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
    // 1) 명식/오행은 여전히 결정론적 규칙으로 계산(범위 밖)
    const { pillars, fiveElements } = computeChart(birthDate, !!birthTime);

    // 2) 주제별 활성 프롬프트 템플릿을 조회하고 LLM을 호출
    //    [성능 개선 - 병렬화] saju는 주제마다 서로 다른 도메인(saju/saju_wealth/...)의
    //    템플릿을 조회해야 하므로, 먼저 템플릿을 모두 병렬로 조회한 뒤(1단계),
    //    템플릿이 있는 주제에 대해서만 completeText() 호출을 동시에 발사한다(2단계).
    //    face/palm/compatibility와 동일하게, 순차 호출 시 주제 개수만큼(최대 5개,
    //    최악 150s) 응답시간이 늘어나는 문제를 "가장 느린 1건의 시간"으로 단축한다.
    const uniqueTopics = Array.from(new Set(topics));

    const templateEntries = await Promise.all(
      uniqueTopics.map(async (topic) => {
        const domain = TOPIC_DOMAIN[topic] ?? "saju";
        const template = await prisma.aiPromptTemplate.findFirst({
          where: { fortuneTypeOrDomain: domain, isActive: true },
          select: { id: true, version: true, templateBody: true },
        });
        return { topic, template };
      })
    );

    let primaryTemplate: { id: number; version: number } | null = null;
    for (const { topic, template } of templateEntries) {
      if (template && (!primaryTemplate || topic === "종합")) {
        primaryTemplate = { id: template.id, version: template.version };
      }
    }

    const topicResults: Record<string, string> = {};
    for (const { topic, template } of templateEntries) {
      if (!template) {
        topicResults[topic] = FALLBACK_TEXT_BY_TOPIC[topic] ?? FALLBACK_TEXT_BY_TOPIC["종합"];
      }
    }

    const withTemplate = templateEntries.filter(
      (e): e is { topic: string; template: NonNullable<(typeof templateEntries)[number]["template"]> } =>
        e.template !== null
    );
    const settled = await Promise.allSettled(
      withTemplate.map(({ topic, template }) => {
        const userPrompt = [
          `사용자 정보: 생년월일 ${birthDate}(${isLunar ? "음력" : "양력"})`,
          birthTime ? `태어난 시간: ${birthTime}` : "태어난 시간: 미상",
          `요청 주제: ${topic}`,
          "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 사람의 운세를 작성해주세요.",
        ].join("\n");
        return completeText({ systemPrompt: template.templateBody, userPrompt });
      })
    );
    settled.forEach((result, index) => {
      const topic = withTemplate[index].topic;
      if (result.status === "fulfilled") {
        topicResults[topic] = result.value;
      } else {
        console.error(`[POST /api/public/fortune/saju] LLM 호출 실패(topic=${topic}):`, result.reason);
        topicResults[topic] = FALLBACK_TEXT_BY_TOPIC[topic] ?? FALLBACK_TEXT_BY_TOPIC["종합"];
      }
    });

    const summary = topicResults["종합"] ?? Object.values(topicResults)[0] ?? "";

    // 3) 짧은 DB 트랜잭션: fortune_requests/results 기록(포인트 차감 없음)
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      // [무료 광고형 구조 재정비 §신규발견] 사주 운세는 완전 무료 — 차감/환급 없음.
      const balance = wallet.balance;
      const cost = 0;
      const refundAmount = 0;

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

    // ── [STEP8] 실제 분석 성공 후에만 카테고리 이용횟수 +1 ──
    if (usageCheck.userPassId != null) {
      await consumeCategoryUsage(usageCheck.userPassId, userId, "saju");
    }

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
