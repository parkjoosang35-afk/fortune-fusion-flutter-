// 신당 U12 — 공유 링크/payload 서명 검증. 공유 받은 제3자가 링크를 여는
// 시점에 호출되므로(받는 사람은 신당 회원이 아닐 수 있음) 인증을 요구하지
// 않는다 — 위조 여부만 판정한다(로그인 게이트는 별도 관심사).
import { NextRequest, NextResponse } from "next/server";
import { verifyShare, CORS_HEADERS } from "../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  let body: { payload?: string; sig?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const payload = body.payload?.trim();
  const sig = body.sig?.trim();
  if (!payload || !sig) {
    return NextResponse.json(
      { success: false, error: "payload/sig가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const valid = verifyShare(payload, sig);
  return NextResponse.json(
    { success: true, data: { valid } },
    { headers: CORS_HEADERS }
  );
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
