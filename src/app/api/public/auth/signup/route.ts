// 공개 이메일 회원가입 API — AuthRepository.emailSignup() 대응.
// 02번§1.1 "이메일 가입"(로그인과 분리된 절차). users.email/nickname UNIQUE 제약을
// Prisma P2002로 감지해 중복 에러를 구분한다. 신규 유저는 gradeId=1(bronze) 고정 배정,
// user_profiles는 이 시점에는 생성하지 않는다(로그인 후 ProfileCheckScreen에서 1회 입력).
import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db";
import {
  hashPassword,
  signUserToken,
  toUserDto,
  clientIp,
  extractUniqueConstraintFields,
} from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { email?: string; password?: string; nickname?: string };
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
  const nickname = body.nickname?.trim();

  if (!email || !password || !nickname) {
    return NextResponse.json(
      { success: false, error: "필수 정보를 모두 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (password.length < 8) {
    return NextResponse.json(
      { success: false, error: "비밀번호는 8자 이상이어야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const passwordHash = await hashPassword(password);
    const bronzeGrade = await prisma.userGrade.findUnique({ where: { code: "bronze" } });

    const created = await prisma.user.create({
      data: {
        email,
        nickname,
        passwordHash,
        signupChannel: "app",
        gradeId: bronzeGrade?.id ?? null,
      },
      include: { grade: true, profile: true },
    });

    await prisma.userLoginLog.create({
      data: {
        userId: created.id,
        loginType: "email",
        ipAddress: clientIp(request),
        successFlag: true,
      },
    });

    const token = await signUserToken({ userId: created.id, nickname: created.nickname });

    return NextResponse.json(
      { success: true, data: { user: toUserDto(created), token } },
      { headers: CORS_HEADERS }
    );
  } catch (e: unknown) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      const fields = extractUniqueConstraintFields(e);
      const error = fields.includes("email")
        ? "이미 가입된 이메일입니다."
        : fields.includes("nickname")
        ? "이미 사용 중인 닉네임입니다."
        : "이미 가입된 정보입니다.";
      return NextResponse.json(
        { success: false, error, code: "DUPLICATE" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/auth/signup] 실패:", e);
    return NextResponse.json(
      { success: false, error: "회원가입 중 오류가 발생했습니다." },
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
