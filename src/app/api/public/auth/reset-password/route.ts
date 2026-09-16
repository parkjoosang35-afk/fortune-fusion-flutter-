// 비밀번호 재설정 API — 로그인 화면 "비밀번호 찾기" 버튼 대응.
//
// [설계 결정 - find-email/route.ts와 동일 배경] 이메일 발송 인프라가 없어
// "재설정 링크 메일 발송" 방식은 불가능하다. 대신 본인확인(이메일 + 닉네임 +
// 생년월일 3개 모두 일치)을 통과하면 그 자리에서 즉시 새 비밀번호를 설정하는
// 방식으로 구현한다 — 서버가 실제로 비밀번호를 변경하는 정공법이며, find-email과
// 마찬가지로 가짜 성공 안내가 아니다.
//
// [보안 고려] 3개 필드(이메일+닉네임+생년월일) 동시 일치를 요구해 무작위
// 대입 성공 확률을 낮춘다. 소셜 로그인 전용 계정(passwordHash null)은
// 재설정 대상에서 제외한다(비밀번호 로그인 자체를 쓰지 않는 계정이므로).
//
// [요청] {email, nickname, birthDate: "YYYY-MM-DD", newPassword}
// [응답] {success: true}
// [에러] NOT_FOUND(404) - 3개 필드 불일치 / NO_PASSWORD_LOGIN(400) - 소셜전용 계정
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { hashPassword } from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: {
    email?: string;
    nickname?: string;
    birthDate?: string;
    newPassword?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const email = body.email?.trim();
  const nickname = body.nickname?.trim();
  const birthDate = body.birthDate?.trim();
  const newPassword = body.newPassword;

  if (!email || !nickname || !birthDate || !newPassword) {
    return NextResponse.json(
      { success: false, error: "모든 항목을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (newPassword.length < 8) {
    return NextResponse.json(
      { success: false, error: "비밀번호는 8자 이상이어야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { email },
      include: { profile: true },
    });

    // [계정 존재 여부 비노출 원칙] 이메일/닉네임/생년월일 중 무엇이 틀렸는지
    // 구분하지 않고 동일한 NOT_FOUND로 응답한다.
    if (
      !user ||
      user.deletedAt != null ||
      user.nickname !== nickname ||
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

    if (!user.passwordHash) {
      return NextResponse.json(
        {
          success: false,
          error: "소셜 로그인 전용 계정은 비밀번호 재설정이 필요 없어요. 카카오/구글로 로그인해 주세요.",
          code: "NO_PASSWORD_LOGIN",
        },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    const passwordHash = await hashPassword(newPassword);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });

    return NextResponse.json({ success: true, data: { success: true } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/auth/reset-password] 실패:", e);
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
