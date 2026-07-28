// 소셜 로그인(카카오/구글) API — [설계결정] 실제 OAuth SDK 연동(앱키/리다이렉트 설정 등)은
// 이번 로드맵 범위 밖이다(과거 PG결제 시뮬레이션과 동일 원칙). 가짜 성공 처리를 절대 하지
// 않고, 501(Not Implemented)로 정직하게 미지원을 응답한다. Flutter 쪽은 이 응답을 받아
// "추후 지원 예정" 안내를 사용자에게 표시한다(login_screen.dart _socialLogin 참고).
import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let provider = "unknown";
  try {
    const body = await request.json();
    provider = body?.provider ?? "unknown";
  } catch {
    // ignore
  }

  return NextResponse.json(
    {
      success: false,
      error: `${provider} 소셜 로그인은 추후 지원 예정입니다.`,
      code: "NOT_IMPLEMENTED",
    },
    { status: 501, headers: CORS_HEADERS }
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
