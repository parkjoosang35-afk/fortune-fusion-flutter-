// 공개(비인증) "이름 운세(성명학)" 생성 API — 신규 카테고리.
//
// [운세 카테고리 확장] 사주(saju)/타로(tarot) 라우트와 동일한 패턴을 재사용한다:
// (1) LLM 호출로 해석 텍스트 생성(DB 트랜잭션 밖) → (2) 짧은 트랜잭션에서
// fortune_requests·results 기록.
// name 도메인은 이미지/생년월일 등 결정론적 계산이 필요 없는 단일 텍스트
// 생성형 카테고리라 사주보다 더 단순하다(주제 분기 없음, summary 1건만 생성).
//
// [무료 광고형 구조 재정비 §신규발견] 이름 운세(성명학) 열람은 복주머니(포인트)를
// 소비하지 않는다. 과거 point_policies(ai_name_request) 기반 차감→즉시환급 로직은
// "복주머니는 소원게시판/소원성에서만 쓰는 유일한 재화" 원칙과 충돌하는 레거시
// 구조였다. 프리패스 상태와도 무관하게 항상 무료로 열람 가능하다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const FALLBACK_TEXT =
  "이름에 담긴 기운은 안정과 조화를 함께 갖추고 있습니다. 주어진 강점을 잘 살리고, 부족한 부분은 주변과의 협력으로 채워간다면 이름의 기운을 온전히 활용할 수 있습니다. 스스로를 믿고 나아가는 태도가 앞으로의 흐름에 큰 도움이 됩니다.";

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

    // 2) 짧은 DB 트랜잭션: fortune_requests·results 기록(포인트 차감 없음)
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      // [무료 광고형 구조 재정비 §신규발견] 이름 운세는 완전 무료 — 차감/환급 없음.
      const balance = wallet.balance;
      const cost = 0;
      const refundAmount = 0;

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
