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
//
// [결함-A07-01 수정 — 2026-09-18] 지시서 스펙(회원가입 완료 즉시 "프리패스 1시간 +
// 복주머니 100개" 지급)과 실제 동작이 두 가지 지점에서 불일치했다:
//   ① point_policies(signup_reward).amount=20 vs IntroConfig.signupRewardAmount=100
//      (관리자 화면에는 "100개 지급"이라고 표시되면서 실제로는 20개만 지급되던 문제)
//   ② 프리패스 1시간 지급 로직이 이 파일에 전혀 없었음(UserPass 생성 코드 0건)
// ①은 DB 값 정정(point_policies.signup_reward.amount: 20→100)으로, ②는 아래
// PassPolicy(passType="event", durationMin=60) 조회 + UserPass 발급 로직 신설로
// 해결한다. sourceType="signup"으로 기록해 광고(ad)/파트너(partner) 등 다른 발급
// 경로와 구분되도록 한다(claim-ad/route.ts의 UserPass 생성 패턴을 그대로 재사용).
// 복주머니와 마찬가지로 User row 생성 자체가 "최초 1회"를 구조적으로 보장하므로
// 별도의 중복 지급 방지 플래그는 두지 않는다.
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
  let body: {
    email?: string;
    password?: string;
    nickname?: string;
    termsAgreed?: boolean;
    privacyAgreed?: boolean;
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
  const password = body.password;
  const nickname = body.nickname?.trim();
  // [6-7-4-B-4] 이용약관/개인정보처리방침 동의는 회원가입의 필수 요건이다
  // (Google Play 정책 및 개인정보보호법상 고지·동의 원칙 준수).
  const termsAgreed = body.termsAgreed === true;
  const privacyAgreed = body.privacyAgreed === true;

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
  if (!termsAgreed || !privacyAgreed) {
    return NextResponse.json(
      {
        success: false,
        error: "이용약관 및 개인정보처리방침에 동의해야 가입할 수 있습니다.",
        code: "TERMS_NOT_AGREED",
      },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const passwordHash = await hashPassword(password);
    const bronzeGrade = await prisma.userGrade.findUnique({ where: { code: "bronze" } });

    // [복주머니 정책표 재정리 - 2026] 회원가입 보상 지급액은 point_policies에서 조회한다
    // (관리자가 /cms/intro-config에서 바꾸면 즉시 반영, 코드 재배포 불필요).
    // 정책이 없거나 비활성화된 경우에도 회원가입 자체는 막지 않고 정책표 기준값(20개)으로 폴백한다.
    const signupRewardPolicy = await prisma.pointPolicy.findUnique({
      where: { sourceType: "signup_reward" },
    });
    const signupRewardAmount =
      signupRewardPolicy?.isActive === false ? 0 : signupRewardPolicy?.amount ?? 20;

    // [결함-A07-01 수정] 회원가입 프리패스(1시간) 지급 대상 정책 조회.
    // passType="event" + durationMin=60인 활성 정책 중 첫 번째를 사용한다(기존
    // "프리패스 1시간(복주머니 구매)" 정책과 동일 효과를 공유 — 이용자 입장에서는
    // 발급 경로만 다를 뿐 "1시간 동안 전체 운세 콘텐츠 이용 가능"이라는 동일한
    // 혜택이므로 별도 전용 정책을 새로 만들지 않고 재사용한다).
    const signupPassPolicy = await prisma.passPolicy.findFirst({
      where: { passType: "event", durationMin: 60, isActive: true, deletedAt: null },
      orderBy: { id: "asc" },
    });

    const { created, walletBalanceAfter, passExpiresAt } = await prisma.$transaction(async (tx) => {
      const now = new Date();
      const user = await tx.user.create({
        data: {
          email,
          nickname,
          passwordHash,
          signupChannel: "app",
          gradeId: bronzeGrade?.id ?? null,
          termsAgreedAt: now,
          privacyAgreedAt: now,
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
          memo: `회원가입 보상 +${signupRewardAmount} 복주머니`,
        });
        balanceAfter = rewardResult.balanceAfter;
      }

      // [결함-A07-01 수정] 프리패스 1시간 지급. claim-ad/route.ts와 동일한
      // UserPass 생성 패턴(activatedAt=now, expiresAt=now+durationMin분).
      let expiresAt: Date | null = null;
      if (signupPassPolicy) {
        expiresAt = new Date(now.getTime() + signupPassPolicy.durationMin * 60 * 1000);
        const userPass = await tx.userPass.create({
          data: {
            userId: user.id,
            policyId: signupPassPolicy.id,
            activatedAt: now,
            expiresAt,
            sourceType: "signup",
          },
        });
        await tx.operationLog.create({
          data: {
            actorType: "user",
            actorId: user.id,
            action: "signup_reward_pass",
            targetType: "user_pass",
            targetId: userPass.id,
            before: null,
            after: JSON.stringify({ policyId: signupPassPolicy.id, expiresAt: expiresAt.toISOString() }),
          },
        });
      }

      return { created: user, walletBalanceAfter: balanceAfter, passExpiresAt: expiresAt };
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
          signupPass: passExpiresAt
            ? { policyId: signupPassPolicy?.id, expiresAt: passExpiresAt.toISOString() }
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
