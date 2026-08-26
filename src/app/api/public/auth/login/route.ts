// 공개 이메일 로그인 API — AuthRepository.emailLogin() 대응.
// 성공/실패 모두 user_login_logs(Append-only)에 기록한다(02번§1.1 "로그인 이력 기록").
// 유저 미존재/비밀번호 불일치는 동일한 401 메시지로 응답(계정 존재 여부 노출 방지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { verifyPassword, signUserToken, toUserDto, clientIp } from "@/lib/user-auth";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";

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

    // [복주머니 정책표 §3 "첫 로그인/첫 진입 보상: 10개, 1회"]
    // "첫 로그인"의 유일한 서버측 판별 근거는 User.lastLoginAt이 지금까지 null이었는지 여부다.
    // (가입 시점에는 lastLoginAt을 채우지 않으므로, 가입 후 최초 로그인이 이 조건에 해당한다.)
    // 이 update 이전에 값을 읽어 판별해야 하므로, 반드시 아래 update보다 먼저 캡처한다.
    const isFirstLogin = user.lastLoginAt == null;

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

    let firstLoginReward: { amount: number; balanceAfter: number | null } | null = null;
    if (isFirstLogin) {
      const policy = await prisma.pointPolicy.findUnique({
        where: { sourceType: "first_login_reward" },
      });
      const amount = policy?.isActive === false ? 0 : policy?.amount ?? 10;
      if (amount > 0) {
        const result = await prisma.$transaction(async (tx) => {
          return earnLuckPouch(tx, {
            userId: user.id,
            amount,
            sourceType: "first_login_reward",
            memo: `첫 로그인 보상 +${amount} 복주머니`,
          });
        });
        firstLoginReward = { amount, balanceAfter: result.balanceAfter };
      }
    }

    const token = await signUserToken({ userId: user.id, nickname: user.nickname });

    return NextResponse.json(
      { success: true, data: { user: toUserDto(user), token, firstLoginReward } },
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
