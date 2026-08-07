// 공개 이메일 회원가입 API — AuthRepository.emailSignup() 대응.
// 02번§1.1 "이메일 가입"(로그인과 분리된 절차). users.email/nickname UNIQUE 제약을
// Prisma P2002로 감지해 중복 에러를 구분한다. 신규 유저는 gradeId=1(bronze) 고정 배정,
// user_profiles는 이 시점에는 생성하지 않는다(로그인 후 ProfileCheckScreen에서 1회 입력).
//
// [인트로 전면 개편 — 회원가입 보상] 가입 완료 시점에 복주머니를 1회 지급한다.
// 지급 수량은 point_policies(sourceType="signup_reward").amount가 단일 소스이며,
// 관리자가 /cms/intro-config에서 수정하면 이 값도 함께 갱신된다(정합성 보장).
// 회원가입은 User 테이블에 새 row가 생성되는 순간 자체가 "최초 1회"를 의미하므로
// (동일 이메일 재가입 불가 = UNIQUE 제약), 별도 중복 지급 방지 플래그 없이도
// "가입당 정확히 1회"가 구조적으로 보장된다. 재로그인은 이 API를 다시 타지 않으므로
// 재지급 위험도 없다.
import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
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

    // [인트로 전면 개편] 회원가입 보상 지급액은 point_policies에서 조회한다
    // (관리자가 /cms/intro-config에서 바꾸면 즉시 반영, 코드 재배포 불필요).
    // 정책이 없거나 비활성화된 경우에도 회원가입 자체는 막지 않고 100개로 폴백한다.
    const signupRewardPolicy = await prisma.pointPolicy.findUnique({
      where: { sourceType: "signup_reward" },
    });
    const signupRewardAmount =
      signupRewardPolicy?.isActive === false ? 0 : signupRewardPolicy?.amount ?? 100;

    const { created, walletBalanceAfter } = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email,
          nickname,
          passwordHash,
          signupChannel: "app",
          gradeId: bronzeGrade?.id ?? null,
        },
        include: { grade: true, profile: true },
      });

      await tx.userLoginLog.create({
        data: {
          userId: user.id,
          loginType: "email",
          ipAddress: clientIp(request),
          successFlag: true,
        },
      });

      let balanceAfter: number | null = null;
      if (signupRewardAmount > 0) {
        const rewardResult = await earnLuckPouch(tx, {
          userId: user.id,
          amount: signupRewardAmount,
          sourceType: "signup_reward",
          memo: "회원가입 보상 +100 복주머니".replace("100", String(signupRewardAmount)),
        });
        balanceAfter = rewardResult.balanceAfter;
      }

      return { created: user, walletBalanceAfter: balanceAfter };
    });

    const token = await signUserToken({ userId: created.id, nickname: created.nickname });

    return NextResponse.json(
      {
        success: true,
        data: {
          user: toUserDto(created),
          token,
          signupReward:
            signupRewardAmount > 0
              ? { amount: signupRewardAmount, balanceAfter: walletBalanceAfter }
              : null,
        },
      },
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
