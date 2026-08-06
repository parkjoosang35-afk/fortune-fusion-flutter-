// 공개(비인증) 궁합 요청 생성 API — Flutter CompatibilityRepository.requestCompatibility() 대응.
//
// [Mock→실API 연동] compatibility_requests/compatibility_results(04A 도메인F)에 실제로
// 기록을 남긴다. AI 실연동 인프라가 없으므로(fortune/daily와 동일하게) 결정론적
// 규칙 기반으로 점수/토픽결과를 생성한다(ai_model="rule-based-v1").
// compatibility_factor_weights(saju/mbti/interest/value/activity_pattern)를 조회해
// 가중치를 실제로 점수 산출에 반영한다(관리자 정책이 실제로 결과에 영향을 주도록).
// [무료 광고형 구조 재정비 §3단계] 복주머니는 소원게시판/소원성에서만 쓰는
// 유일한 재화로 고정한다. 궁합 보기는 더 이상 복주머니를 차감하지 않는다
// (과거 point_policies.ai_compatibility_request 기반 과금 로직은 폐기).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

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
    const outcome = await prisma.$transaction(async (tx) => {
      // [무료 광고형 구조 재정비 §3단계] 궁합 보기는 완전 무료 — 복주머니
      // 차감 로직 없음. balanceAfter는 응답 스키마 하위호환을 위해
      // 항상 null로 유지한다.
      const balanceAfter: number | null = null;

      // 1) 요청 레코드 생성
      const compatRequest = await tx.compatibilityRequest.create({
        data: {
          requesterUserId: userId,
          type,
          targetInput: JSON.stringify({
            nameA: body.nameA ?? "나",
            nameB: body.nameB ?? "상대방",
            birthDateA,
            birthDateB,
          }),
        },
      });

      // 2) 가중치 조회 + 결정론적 점수/토픽 산출
      const weights = await tx.compatibilityFactorWeight.findMany({
        where: { isActive: true, deletedAt: null },
      });
      const weightMap = new Map(weights.map((w) => [w.factorType, w.weight]));
      const seed = hashSeed(`${birthDateA}:${birthDateB}:${type}`);

      const factorScores: Record<string, number> = {
        saju: 50 + (seed * 7) % 45,
        mbti: 50 + (seed * 3) % 45,
        interest: 50 + (seed * 11) % 45,
        value: 50 + (seed * 5) % 45,
        activity_pattern: 50 + (seed * 13) % 45,
      };
      let weightedSum = 0;
      let weightTotal = 0;
      for (const [factor, val] of Object.entries(factorScores)) {
        const w = weightMap.get(factor) ?? 0.2;
        weightedSum += val * w;
        weightTotal += w;
      }
      const score = Math.round(weightTotal > 0 ? weightedSum / weightTotal : 70);

      const topicResults: Record<string, string> = {};
      for (const [topic, options] of Object.entries(TOPIC_POOL)) {
        topicResults[topic] = options[seed % options.length];
      }
      const summary =
        score >= 80
          ? "천생연분에 가까운 궁합입니다. 서로를 향한 신뢰와 애정이 관계를 더욱 단단하게 만들어줄 것입니다."
          : score >= 65
            ? "전반적으로 좋은 궁합입니다. 서로 조금씩 배려한다면 더욱 좋은 관계로 발전할 수 있습니다."
            : "노력이 필요한 궁합이지만, 서로를 이해하려는 마음이 있다면 충분히 좋은 관계를 만들 수 있습니다.";

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
          aiModel: "rule-based-v1",
          status: "success",
        },
      });

      return { compatRequest, compatResult, topicResults, summary, balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `compat_${outcome.compatRequest.id}`,
          nameA: body.nameA ?? "나",
          nameB: body.nameB ?? "상대방",
          type,
          score: outcome.compatResult.score,
          topicResults: outcome.topicResults,
          summary: outcome.summary,
          createdAt: outcome.compatRequest.createdAt.toISOString(),
          balanceAfter: outcome.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
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
