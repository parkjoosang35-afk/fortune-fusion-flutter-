// 이메일 중복확인 API — [신통방통 회원가입·본인 사주정보 통합 흐름 전면
// 검수 지시서 §4] "이메일 blur 시 중복 확인 → 상태 문구: 확인하고
// 있어요… / 사용할 수 있는 이메일이에요 / 이미 가입된 이메일이에요.
// 로그인해 주세요. / 이메일 형식을 확인해 주세요"에 대응.
//
// 기존에는 이 사전 확인 API가 없어, 중복 여부가 실제 가입 시도(POST
// /api/public/auth/signup) 실패(P2002, "이미 가입된 이메일입니다.")로만
// 드러났다. 디자인 스펙은 "이메일 입력란 blur 시점"에 미리 알려주는
// UX를 요구하므로 별도 GET 엔드포인트로 분리한다.
//
// [보안] 이메일 존재 여부 자체가 민감정보는 아니나(비밀번호 재설정/찾기
// 플로우에서 이미 유사한 정보가 노출되는 서비스가 일반적), 무차별 대입
// 스캔을 늦추기 위해 요청 바디에 비밀번호 등 다른 필드는 받지 않고
// 단순 조회만 수행한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { isValidEmail, INVALID_EMAIL_MESSAGE } from "@/lib/email-validator";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const email = request.nextUrl.searchParams.get("email")?.trim() ?? "";

  if (!email) {
    return NextResponse.json(
      { success: false, error: "이메일을 입력해 주세요.", code: "EMAIL_REQUIRED" },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  if (!isValidEmail(email)) {
    return NextResponse.json(
      { success: false, error: INVALID_EMAIL_MESSAGE, code: "INVALID_EMAIL" },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const existing = await prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });

    return NextResponse.json(
      { success: true, data: { available: !existing } },
      { headers: CORS_HEADERS }
    );
  } catch (e: unknown) {
    console.error("[GET /api/public/auth/email-check] 실패:", e);
    return NextResponse.json(
      { success: false, error: "이메일 확인 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
