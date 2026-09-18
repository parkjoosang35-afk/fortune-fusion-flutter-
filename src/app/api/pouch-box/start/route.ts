// 공개(비인증) 행운상자 시청 시작 API — Flutter "광고보고 상자 열기" CTA를
// 탭한 시점에 호출한다. [행운상자 - 복주머니 탭 신규 기능] 자격(하루 5회
// 한도)을 확인한 뒤 PouchBoxOpenLog를 PENDING 상태로 생성해 세션을 발급한다.
// 실제 지급은 이 시점에 이뤄지지 않으며, 클라이언트가 5초 광고 시청을 끝까지
// 마치고 /complete를 호출해야 지급된다(중간에 종료하면 PENDING인 채로 남아
// 보상이 지급되지 않고, 하루 5회 한도에도 차감되지 않는다).
import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { prisma } from "@/lib/db";
import { checkPouchBoxEligibility, POUCH_BOX_REASON_LABELS } from "@/lib/pouch-box-service";
import { requireUser, unauthorizedResponse } from "@/app/api/public/wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  // [Stage2 결함수정 — 결함-A04-01] 이 API는 지급 세션을 발급하는 지점이므로
  // body.userId 위조 시 타인 명의로 하루 5회 한도를 대신 소진시키거나, 이어지는
  // /complete 호출과 결합해 타인 계정으로 보상을 가로챌 위험이 있다. JWT
  // Authorization 헤더로만 신원을 판별한다(body의 userId는 더 이상 신뢰하지 않음).
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;

  try {
    const eligibility = await checkPouchBoxEligibility(userId);
    if (!eligibility.eligible) {
      return NextResponse.json(
        {
          success: false,
          error: eligibility.reason ? POUCH_BOX_REASON_LABELS[eligibility.reason] : "지금은 열 수 없습니다.",
          reason: eligibility.reason,
          dailyLeft: eligibility.dailyLeft,
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    const sessionId = randomUUID();
    const log = await prisma.pouchBoxOpenLog.create({
      data: {
        userId,
        sessionId,
        rewardStatus: "PENDING",
      },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          sessionId: log.sessionId,
          openLogId: log.id,
          dailyLeft: eligibility.dailyLeft,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/pouch-box/start] 실패:", e);
    return NextResponse.json(
      { success: false, error: "시작 처리 중 오류가 발생했습니다." },
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
