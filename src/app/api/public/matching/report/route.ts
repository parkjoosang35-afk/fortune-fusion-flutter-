// 공개(비인증) 매칭 신고 API — MatchingRepository.report() 대응.
//
// [설계결정] Flutter MatchingReportTargetType은 candidate/pair/chatMessage 3종이지만,
// 실제 UI(matching_pairs_screen.dart)에서는 pair만 사용한다. reports.target_type
// 화이트리스트(post/comment/wish/user/fortune_result)에는 매칭 전용 타입이 없으므로,
// pair 신고는 "상대 유저(user) 신고"로 변환해 기존 공용 reports 테이블에 적재한다
// (targetId를 pair의 상대방 userId로 resolve).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parsePairId(idParam: string): number | null {
  const match = /^pair_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; targetType?: string; targetId?: string; reason?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const targetType = body.targetType ?? "";
  const reason = (body.reason ?? "").trim();
  if (!reason) {
    return NextResponse.json(
      { success: false, error: "신고 사유를 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    let reportedUserId: number | null = null;

    if (targetType === "pair") {
      const pairId = body.targetId ? parsePairId(body.targetId) : null;
      if (pairId === null) {
        return NextResponse.json(
          { success: false, error: "targetId가 올바르지 않습니다." },
          { status: 400, headers: CORS_HEADERS }
        );
      }
      const pair = await prisma.matchingPair.findUnique({ where: { id: pairId } });
      if (!pair) {
        return NextResponse.json(
          { success: false, error: "매칭을 찾을 수 없습니다." },
          { status: 404, headers: CORS_HEADERS }
        );
      }
      reportedUserId = pair.userAId === userId ? pair.userBId : pair.userAId;
    } else if (targetType === "candidate") {
      reportedUserId = Number(body.targetId);
    } else {
      // chatMessage 등 기타 타입은 이번 1차 범위에서 미지원
      return NextResponse.json(
        { success: false, error: "지원하지 않는 신고 대상입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    if (!reportedUserId || !Number.isInteger(reportedUserId)) {
      return NextResponse.json(
        { success: false, error: "신고 대상을 확인할 수 없습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    await prisma.report.create({
      data: { targetType: "user", targetId: reportedUserId, reporterId: userId, reason },
    });
    return NextResponse.json({ success: true, data: null }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/matching/report] 실패:", e);
    return NextResponse.json(
      { success: false, error: "신고 접수에 실패했습니다." },
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
