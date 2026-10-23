// 신당 U12 — 공유 payload 서명 발급. ResultScreen/공유 기능이 외부로 내보낼
// 링크/이미지 메타에 서명을 함께 실어, 위조된 공유를 verify-share로 걸러낸다.
import { NextRequest, NextResponse } from "next/server";
import { sign, requireUser, unauthorizedResponse, CORS_HEADERS } from "../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { payload?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const payload = body.payload?.trim();
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "payload가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  return NextResponse.json(
    { success: true, data: { sig: sign(payload) } },
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
