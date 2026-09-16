// 아이디(이메일) 찾기 API — 로그인 화면 "아이디 찾기" 버튼 대응.
//
// [설계 결정 - 외부 이메일/SMS 발송 인프라 부재] 이 환경에는 SMTP/SMS 발송
// 서비스(nodemailer/SES/알리고 등)가 전혀 설치·구성되어 있지 않다(.env에
// 관련 키 없음). 따라서 "메일로 링크 발송" 방식은 이 환경에서 실제로 동작할
// 수 없다. 대신 서버가 이미 보유한 데이터(닉네임 + 생년월일)로 본인확인을
// 수행한 뒤, 확인된 본인에게 즉시 마스킹된 이메일을 반환하는 "정공법"으로
// 구현한다(가짜 성공 토스트 금지 원칙 준수 — user-auth.ts 402 라인 계열
// 정직성 원칙과 동일).
//
// [본인확인 근거] nickname은 UNIQUE, birth_date는 UserProfile(1:1)에 저장된
// 값이다. 두 값이 모두 일치해야만 매치로 간주한다(닉네임만으로는 계정 특정이
// 가능하지만 본인확인이 아니므로 반드시 생년월일도 함께 검증).
//
// [요청] {nickname: string, birthDate: "YYYY-MM-DD"}
// [응답] {maskedEmail: "ab***@example.com"}
// [에러] NOT_FOUND(404) - 일치하는 계정 없음 / NO_EMAIL(404) - 소셜가입이라 이메일 없음
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** "abcdef@example.com" -> "ab****@example.com" (개인정보 노출 최소화). */
function maskEmail(email: string): string {
  const [local, domain] = email.split("@");
  if (!domain) return email;
  if (local.length <= 2) return `${local[0] ?? ""}*@${domain}`;
  return `${local.slice(0, 2)}${"*".repeat(Math.max(local.length - 2, 2))}@${domain}`;
}

export async function POST(request: NextRequest) {
  let body: { nickname?: string; birthDate?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const nickname = body.nickname?.trim();
  const birthDate = body.birthDate?.trim();

  if (!nickname || !birthDate) {
    return NextResponse.json(
      { success: false, error: "닉네임과 생년월일을 모두 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { nickname },
      include: { profile: true },
    });

    // [계정 존재 여부 비노출 원칙 - login/route.ts와 동일] 닉네임이 없거나
    // 생년월일이 불일치하면 동일한 NOT_FOUND로 응답해 "닉네임은 맞는데
    // 생년월일이 틀렸다"는 정보를 노출하지 않는다.
    if (
      !user ||
      user.deletedAt != null ||
      !user.profile ||
      user.profile.birthDate !== birthDate
    ) {
      return NextResponse.json(
        {
          success: false,
          error: "입력하신 정보와 일치하는 계정을 찾을 수 없어요.",
          code: "NOT_FOUND",
        },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    if (!user.email) {
      return NextResponse.json(
        {
          success: false,
          error: "소셜 로그인으로 가입된 계정이라 이메일이 없어요. 카카오/구글로 로그인해 주세요.",
          code: "NO_EMAIL",
        },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      { success: true, data: { maskedEmail: maskEmail(user.email) } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/auth/find-email] 실패:", e);
    return NextResponse.json(
      { success: false, error: "처리 중 오류가 발생했습니다." },
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
