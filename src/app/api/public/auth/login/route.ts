// 공개 이메일 로그인 API — AuthRepository.emailLogin() 대응.
// 성공/실패 모두 user_login_logs(Append-only)에 기록한다(02번§1.1 "로그인 이력 기록").
// 유저 미존재/비밀번호 불일치는 동일한 401 메시지로 응답(계정 존재 여부 노출 방지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { verifyPassword, signUserToken, toUserDto, clientIp } from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { email?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const email = body.email?.trim();
  const password = body.password;

  if (!email || !password) {
    return NextResponse.json(
      { success: false, error: "이메일과 비밀번호를 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const ipAddress = clientIp(request);

  try {
    const user = await prisma.user.findUnique({
      where: { email },
      include: { grade: true, profile: true },
    });

    if (!user || !user.passwordHash) {
      await prisma.userLoginLog.create({
        data: {
          userId: user?.id ?? null,
          loginType: "email",
          ipAddress,
          successFlag: false,
          failReason: "존재하지 않는 계정",
        },
      });
      return NextResponse.json(
        { success: false, error: "이메일 또는 비밀번호가 올바르지 않습니다." },
        { status: 401, headers: CORS_HEADERS }
      );
    }

    const passwordOk = await verifyPassword(password, user.passwordHash);
    if (!passwordOk) {
      await prisma.userLoginLog.create({
        data: {
          userId: user.id,
          loginType: "email",
          ipAddress,
          successFlag: false,
          failReason: "비밀번호 불일치",
        },
      });
      return NextResponse.json(
        { success: false, error: "이메일 또는 비밀번호가 올바르지 않습니다." },
        { status: 401, headers: CORS_HEADERS }
      );
    }

    if (user.status !== "active") {
      await prisma.userLoginLog.create({
        data: {
          userId: user.id,
          loginType: "email",
          ipAddress,
          successFlag: false,
          failReason: `계정 상태: ${user.status}`,
        },
      });
      const error =
        user.status === "withdrawn"
          ? "탈퇴 처리된 계정입니다."
          : "이용이 제한된 계정입니다.";
      return NextResponse.json(
        { success: false, error, code: "ACCOUNT_" + user.status.toUpperCase() },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    await prisma.userLoginLog.create({
      data: {
        userId: user.id,
        loginType: "email",
        ipAddress,
        successFlag: true,
      },
    });

    const token = await signUserToken({ userId: user.id, nickname: user.nickname });

    return NextResponse.json(
      { success: true, data: { user: toUserDto(user), token } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/auth/login] 실패:", e);
    return NextResponse.json(
      { success: false, error: "로그인 중 오류가 발생했습니다." },
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
