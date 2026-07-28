// 공개(비인증) 폴리모픽 공용 신고 API — 06§4.12 `POST /{targetType}/:id/report` 대응.
// CommunityPostRepository.report() / WishPostRepository.report() 양쪽 모두 이 단일
// 엔드포인트를 호출한다(Flutter ReportTargetType enum: wish/communityPost/comment).
//
// [id 포맷 매핑] Flutter 쪽 targetId는 각 도메인의 접두사 문자열(cp_/wp_/cc_/wc_)을
// 그대로 사용하므로, 여기서 파싱해 admin_web reports.target_type(post/wish/comment)
// 화이트리스트 값과 숫자 PK로 변환한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// Flutter ReportTargetType.name -> admin_web reports.target_type 화이트리스트 값
const TARGET_TYPE_MAP: Record<string, string> = {
  wish: "wish",
  communityPost: "post",
  comment: "comment",
};

function parseTargetId(targetType: string, targetId: string): number | null {
  // cp_12 / wp_12 / cc_12 / wc_12 형태 모두 허용, 순수 숫자도 허용
  const match = /^[a-z]+_(\d+)$/.exec(targetId);
  if (match) return Number(match[1]);
  const n = Number(targetId);
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
  const feTargetType = body.targetType ?? "";
  const reason = (body.reason ?? "").trim();

  const dbTargetType = TARGET_TYPE_MAP[feTargetType];
  if (!dbTargetType) {
    return NextResponse.json(
      { success: false, error: "targetType이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const targetId = body.targetId ? parseTargetId(feTargetType, body.targetId) : null;
  if (targetId === null) {
    return NextResponse.json(
      { success: false, error: "targetId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!reason) {
    return NextResponse.json(
      { success: false, error: "신고 사유를 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    await prisma.report.create({
      data: { targetType: dbTargetType, targetId, reporterId: userId, reason },
    });
    return NextResponse.json({ success: true, data: null }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/reports] 실패:", e);
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
