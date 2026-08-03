// 공개(비인증) "이름 운세(성명학)" 생성 API — 신규 카테고리.
//
// [운세 카테고리 확장] 사주(saju)/타로(tarot) 라우트와 동일한 패턴을 그대로
// 재사용한다: (1) LLM 호출로 해석 텍스트 생성(DB 트랜잭션 밖) → (2) 짧은
// 트랜잭션에서 잔액 재확인/차감/환급/fortune_requests·results 기록.
// name 도메인은 이미지/생년월일 등 결정론적 계산이 필요 없는 단일 텍스트
// 생성형 카테고리라 사주보다 더 단순하다(주제 분기 없음, summary 1건만 생성).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const FALLBACK_TEXT =
  "이름에 담긴 기운은 안정과 조화를 함께 갖추고 있습니다. 주어진 강점을 잘 살리고, 부족한 부분은 주변과의 협력으로 채워간다면 이름의 기운을 온전히 활용할 수 있습니다. 스스로를 믿고 나아가는 태도가 앞으로의 흐름에 큰 도움이 됩니다.";

function isRefundEligibleSourceType(sourceType: string): boolean {
  return sourceType.startsWith("ai_") || sourceType.startsWith("fortune_");
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    name?: string;
    birthDate?: string;
    gender?: string;
    hanja?: string;
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
  const name = body.name?.trim();
  const birthDate = body.birthDate ?? null;
  const gender = body.gender ?? null;
  const hanja = body.hanja?.trim() || null;

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!name) {
    return NextResponse.json(
      { success: false, error: "name이 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 1) name 도메인 활성 프롬프트 템플릿으로 해석 텍스트 생성(DB 트랜잭션 밖)
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "name", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    let resultText = FALLBACK_TEXT;
    if (template) {
      const userPrompt = [
        `분석 대상 이름: ${name}${hanja ? ` (한자: ${hanja})` : ""}`,
        birthDate ? `생년월일: ${birthDate}` : "생년월일: 미상",
        gender ? `성별: ${gender}` : "성별: 미상",
        "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이름의 기운(성명학)을 해석해주세요.",
      ].join("\n");

      try {
        resultText = await completeText({ systemPrompt: template.templateBody, userPrompt });
      } catch (e) {
        console.error("[POST /api/public/fortune/name] LLM 호출 실패:", e);
      }
    }

    // 2) 짧은 DB 트랜잭션: 잔액 재확인 → 차감 → 환급 → 기록
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "ai_name_request" } });
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
          sourceType: "ai_name_request",
          balanceAfter: balance,
          memo: `이름 운세(성명학) 조회(${name})`,
        },
      });

      let refundAmount = 0;
      if (isRefundEligibleSourceType("ai_name_request")) {
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
              memo: `이름 운세 조회 환급 (${Math.round(refundRate * 100)}%)`,
            },
          });
        }
      }

      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "name",
          inputPayload: JSON.stringify({ name, hanja, birthDate, gender }),
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
            resultText,
            resultMeta: JSON.stringify({ name, hanja }),
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
          id: `name_${outcome.requestId}`,
          name,
          hanja,
          birthDate,
          gender,
          resultText,
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
      console.error("[POST /api/public/fortune/name] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/fortune/name] 실패:", e);
    return NextResponse.json(
      { success: false, error: "이름 운세 분석 중 오류가 발생했습니다." },
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
