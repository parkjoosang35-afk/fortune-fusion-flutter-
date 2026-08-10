// 공개(비인증) 궁합 요청 생성 API — Flutter CompatibilityRepository.requestCompatibility() 대응.
//
// [Mock→실API 연동, 1차] compatibility_requests/compatibility_results(04A 도메인F)에 실제로
// 기록을 남긴다. 점수(score)는 compatibility_factor_weights(saju/mbti/interest/value/
// activity_pattern) 가중치를 반영한 결정론적 규칙 기반 산출을 그대로 유지한다(관리자
// 정책이 점수에 실제로 영향을 주는 구조는 이미 정상 동작하므로 변경하지 않는다).
//
// [Phase - AI프롬프트 실연동 2차] "토픽별 해석 텍스트"만 saju/name 라우트와 동일한 패턴으로
// ai_prompt_templates(domain=compatibility)의 활성 템플릿 + completeText()를 통해
// 실제 LLM 생성 텍스트로 교체한다. 템플릿이 없거나 LLM 호출이 실패하면 기존
// TOPIC_POOL 하드코딩 텍스트로 폴백한다(가용성 우선).
//
// [무료 광고형 구조 재정비 §3단계] 복주머니는 소원게시판/소원성에서만 쓰는
// 유일한 재화로 고정한다. 궁합 보기는 더 이상 복주머니를 차감하지 않는다
// (과거 point_policies.ai_compatibility_request 기반 과금 로직은 폐기).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const TOPIC_POOL: Record<string, string[]> = {
  애정: [
    "서로에 대한 호감과 관심이 자연스럽게 이어지는 좋은 궁합입니다.",
    "처음엔 조심스럽지만 시간이 지날수록 깊어지는 인연입니다.",
  ],
  성격: [
    "서로 다른 성향이 오히려 균형을 이루며 좋은 시너지를 만듭니다.",
    "비슷한 가치관을 공유하여 편안한 관계를 유지할 수 있습니다.",
  ],
  미래: [
    "함께 성장하며 장기적으로 안정적인 관계를 이어갈 가능성이 높습니다.",
    "서로의 부족한 부분을 채워주며 좋은 파트너가 될 수 있습니다.",
  ],
};

const TYPE_LABEL: Record<string, string> = {
  love: "연인/짝사랑",
  friend: "친구",
  business: "동업/사업 파트너",
  family: "가족",
};

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    type?: string;
    nameA?: string;
    nameB?: string;
    birthDateA?: string;
    birthDateB?: string;
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
  const type = body.type ?? "love"; // love/friend/business/family
  const birthDateA = body.birthDateA ?? "";
  const birthDateB = body.birthDateB ?? "";

  if (!birthDateA || !birthDateB) {
    return NextResponse.json(
      { success: false, error: "birthDateA, birthDateB가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const nameA = body.nameA ?? "나";
    const nameB = body.nameB ?? "상대방";
    const seed = hashSeed(`${birthDateA}:${birthDateB}:${type}`);

    // 1) 가중치 조회(읽기 전용, 트랜잭션 밖) + 결정론적 점수 산출.
    //    [범위 결정] 점수 계산은 관리자 가중치 정책이 실제로 반영되는 기존
    //    로직이므로 그대로 유지한다(이번 변경은 해석 텍스트 생성 방식만 다룬다).
    const weights = await prisma.compatibilityFactorWeight.findMany({
      where: { isActive: true, deletedAt: null },
    });
    const weightMap = new Map(weights.map((w) => [w.factorType, w.weight]));

    const factorScores: Record<string, number> = {
      saju: 50 + ((seed * 7) % 45),
      mbti: 50 + ((seed * 3) % 45),
      interest: 50 + ((seed * 11) % 45),
      value: 50 + ((seed * 5) % 45),
      activity_pattern: 50 + ((seed * 13) % 45),
    };
    let weightedSum = 0;
    let weightTotal = 0;
    for (const [factor, val] of Object.entries(factorScores)) {
      const w = weightMap.get(factor) ?? 0.2;
      weightedSum += val * w;
      weightTotal += w;
    }
    const score = Math.round(weightTotal > 0 ? weightedSum / weightTotal : 70);

    // 2) compatibility 도메인 활성 프롬프트 템플릿으로 토픽별 해석 텍스트 생성
    //    (DB 트랜잭션 밖에서 LLM 호출, saju/name 라우트와 동일한 패턴).
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "compatibility", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    // [성능 개선 - 병렬화] face/palm 라우트와 동일한 이유로, 토픽 3개(애정/성격/미래)를
    // 순차 호출하면 최악의 경우 응답시간이 최대 90s까지 늘어날 수 있다.
    // Promise.allSettled()로 동시에 호출해 전체 응답시간을 "가장 느린 1건의 시간"으로
    // 단축한다(개별 토픽 실패는 서로 영향 없이 격리되어 해당 토픽만 폴백 처리).
    const topicResults: Record<string, string> = {};
    let usedAi = false;
    const topicEntries = Object.entries(TOPIC_POOL);

    if (!template) {
      for (const [topic, options] of topicEntries) {
        topicResults[topic] = options[seed % options.length];
      }
    } else {
      const settled = await Promise.allSettled(
        topicEntries.map(([topic]) => {
          const userPrompt = [
            `궁합 유형: ${TYPE_LABEL[type] ?? type}`,
            `사람A: ${nameA}(생년월일 ${birthDateA})`,
            `사람B: ${nameB}(생년월일 ${birthDateB})`,
            `종합 궁합 점수: ${score}점(100점 만점)`,
            `요청 주제: ${topic}`,
            "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 두 사람의 궁합을 주제에 맞춰 해석해주세요.",
          ].join("\n");
          return completeText({ systemPrompt: template.templateBody, userPrompt });
        })
      );
      settled.forEach((result, index) => {
        const [topic, options] = topicEntries[index];
        if (result.status === "fulfilled") {
          topicResults[topic] = result.value;
          usedAi = true;
        } else {
          console.error(
            `[POST /api/public/compatibility/request] LLM 호출 실패(topic=${topic}):`,
            result.reason
          );
          topicResults[topic] = options[seed % options.length];
        }
      });
    }

    const summaryFallback =
      score >= 80
        ? "천생연분에 가까운 궁합입니다. 서로를 향한 신뢰와 애정이 관계를 더욱 단단하게 만들어줄 것입니다."
        : score >= 65
          ? "전반적으로 좋은 궁합입니다. 서로 조금씩 배려한다면 더욱 좋은 관계로 발전할 수 있습니다."
          : "노력이 필요한 궁합이지만, 서로를 이해하려는 마음이 있다면 충분히 좋은 관계를 만들 수 있습니다.";
    const summary = Object.values(topicResults)[0] ?? summaryFallback;

    // 3) 짧은 DB 트랜잭션: compatibility_requests/results 기록(포인트 차감 없음)
    const outcome = await prisma.$transaction(async (tx) => {
      // [무료 광고형 구조 재정비 §3단계] 궁합 보기는 완전 무료 — 복주머니
      // 차감 로직 없음. balanceAfter는 응답 스키마 하위호환을 위해
      // 항상 null로 유지한다.
      const balanceAfter: number | null = null;

      const compatRequest = await tx.compatibilityRequest.create({
        data: {
          requesterUserId: userId,
          type,
          targetInput: JSON.stringify({ nameA, nameB, birthDateA, birthDateB }),
        },
      });

      const compatResult = await tx.compatibilityResult.create({
        data: {
          requestId: compatRequest.id,
          score,
          detail: JSON.stringify({ factorScores, topicResults, summary }),
        },
      });

      await tx.aiRequestLog.create({
        data: {
          domain: "compatibility",
          requestRefId: compatRequest.id,
          aiModel: usedAi ? "claude-haiku-4-5" : "rule-based-v1",
          status: "success",
        },
      });

      return { compatRequest, compatResult, balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `compat_${outcome.compatRequest.id}`,
          nameA,
          nameB,
          type,
          score: outcome.compatResult.score,
          topicResults,
          summary,
          createdAt: outcome.compatRequest.createdAt.toISOString(),
          balanceAfter: outcome.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof LlmClientError) {
      console.error("[POST /api/public/compatibility/request] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/compatibility/request] 실패:", e);
    return NextResponse.json(
      { success: false, error: "궁합 요청 처리 중 오류가 발생했습니다." },
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
