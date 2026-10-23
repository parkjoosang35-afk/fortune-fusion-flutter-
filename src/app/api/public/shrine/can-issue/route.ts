// 신당 U12 — 발급 가능 여부 사전 확인. Flutter MeaningScreen이 "월화에게
// 부적을 부탁하기" 버튼을 누르기 전/후 모두 이 API로 서버 재검증한다.
import { NextRequest, NextResponse } from "next/server";
import { canIssue, requireUser, unauthorizedResponse, CORS_HEADERS } from "../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { sajuFp?: string | null; storyId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const storyId = body.storyId?.trim();
  if (!storyId) {
    return NextResponse.json(
      { success: false, error: "storyId가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const result = await canIssue({
    userId: auth.userId,
    sajuFp: body.sajuFp ?? null,
    storyId,
  });

  return NextResponse.json(
    { success: true, data: result },
    { headers: CORS_HEADERS }
  );
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
