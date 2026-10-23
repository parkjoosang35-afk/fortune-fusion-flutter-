// 신당 U12 — 실제 발급 기록. ReceiveScreen "부적 간직하기" 버튼에서 호출.
// [서버 재검증] canIssue()를 이 라우트 내부에서 다시 호출해, 클라이언트가
// can-issue 응답을 변조해 보내더라도 최종 발급 전에 한 번 더 막는다.
import { NextRequest, NextResponse } from "next/server";
import { canIssue, recordIssue, requireUser, unauthorizedResponse, CORS_HEADERS } from "../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { sajuFp?: string; storyId?: string; composeKey?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const storyId = body.storyId?.trim();
  const composeKey = body.composeKey?.trim();
  const sajuFp = body.sajuFp?.trim();
  if (!storyId || !composeKey || !sajuFp) {
    return NextResponse.json(
      { success: false, error: "storyId/composeKey/sajuFp가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const check = await canIssue({ userId: auth.userId, sajuFp, storyId });
  if (!check.ok) {
    return NextResponse.json(
      { success: false, error: check.reason, code: check.code },
      { status: 409, headers: CORS_HEADERS }
    );
  }

  try {
    const { serial } = await recordIssue({
      userId: auth.userId,
      sajuFp,
      storyId,
      composeKey,
    });
    return NextResponse.json(
      { success: true, data: { serial } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    // unique([userId, storyId]) 경쟁 상태 충돌 — 거의 동시에 두 번 눌린 경우.
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message.includes("Unique constraint")) {
      return NextResponse.json(
        { success: false, error: "이미 이 이야기로 받은 부적이 있습니다.", code: "ALREADY_ISSUED" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/shrine/record-issue] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 발급 기록에 실패했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
