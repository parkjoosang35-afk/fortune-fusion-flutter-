// 소셜 로그인(카카오/구글) API — AuthRepository.socialLogin() 대응. [로드맵⑤]
//
// [처리 흐름]
// 1) Flutter가 보낸 accessToken을 카카오/구글의 "공식 서버"에 다시 제시해 진짜인지
//    확인한다(social-auth-verify.ts). 여기서 실패하면 절대 로그인을 성립시키지 않는다.
// 2) 검증으로 얻은 고유 ID(kakaoId/googleId)로 기존 회원을 찾는다.
//    - 있으면: 그 회원으로 로그인 처리.
//    - 없으면: 신규 회원 가입 처리(닉네임 중복 시 뒤에 랜덤 숫자를 붙여 자동 보정).
// 3) 로그인/가입 성공/실패 모두 user_login_logs에 기록한다(이메일 로그인과 동일 원칙).
// 4) 신규가입 시에는 회원가입 보상(signup_reward)을, 기존 회원의 "첫 로그인"이었던
//    경우엔 첫 로그인 보상(first_login_reward)을 지급한다(email 가입 경로와 동일 정책).
import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db";
import { signUserToken, toUserDto, clientIp } from "@/lib/user-auth";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  verifySocialToken,
  SocialVerifyError,
  type VerifiedSocialUser,
} from "@/lib/social-auth-verify";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** 소셜 제공 닉네임 힌트를 기반으로, users.nickname UNIQUE 제약을 지키는 닉네임을 만든다. */
async function buildUniqueNickname(hint: string | null, provider: string): Promise<string> {
  const base = (hint?.trim() || (provider === "kakao" ? "카카오유저" : "구글유저")).slice(0, 16);
  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = attempt === 0 ? base : `${base}${Math.floor(1000 + Math.random() * 9000)}`;
    const exists = await prisma.user.findUnique({ where: { nickname: candidate } });
    if (!exists) return candidate;
  }
  // 5회 모두 충돌한 극히 드문 경우: 타임스탬프를 붙여 확정적으로 유일하게 만든다.
  return `${base}${Date.now() % 100000}`;
}

export async function POST(request: NextRequest) {
  let body: {
    provider?: string;
    accessToken?: string;
    // [웹 소셜로그인 활성화] 구글은 플랫폼별로 다른 종류의 토큰을 보낸다:
    // Android(APK) = idToken, Web = accessToken(GIS SDK 정책상 웹에서는
    // idToken을 안정적으로 받을 수 없다 — social-auth-verify.ts 참고).
    // 필드가 없으면 기존 동작(id_token)과 100% 동일하게 유지된다.
    tokenType?: "id_token" | "access_token";
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const provider = body.provider;
  const accessToken = body.accessToken;
  const tokenType: "id_token" | "access_token" =
    body.tokenType === "access_token" ? "access_token" : "id_token";
  if (provider !== "kakao" && provider !== "google") {
    return NextResponse.json(
      { success: false, error: "지원하지 않는 로그인 방식입니다.", code: "UNSUPPORTED_PROVIDER" },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!accessToken) {
    return NextResponse.json(
      { success: false, error: "인증 토큰이 전달되지 않았습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const ipAddress = clientIp(request);

  // [1] 카카오/구글 공식 서버에 토큰을 다시 제시해 검증 — 여기서 실패하면 즉시 종료.
  let verified: VerifiedSocialUser;
  try {
    verified = await verifySocialToken(provider, accessToken, tokenType);
  } catch (e) {
    const message = e instanceof SocialVerifyError ? e.message : `${provider} 인증 확인 중 오류가 발생했습니다.`;
    await prisma.userLoginLog.create({
      data: {
        userId: null,
        loginType: provider,
        ipAddress,
        successFlag: false,
        failReason: message,
      },
    });
    return NextResponse.json(
      { success: false, error: message, code: "SOCIAL_VERIFY_FAILED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  try {
    const existing = await prisma.user.findUnique({
      where:
        provider === "kakao"
          ? { kakaoId: verified.socialId }
          : { googleId: verified.socialId },
      include: { grade: true, profile: true },
    });

    if (existing) {
      // ── 기존 회원: 로그인 처리 ─────────────────────────────────────────
      if (existing.status !== "active") {
        await prisma.userLoginLog.create({
          data: {
            userId: existing.id,
            loginType: provider,
            ipAddress,
            successFlag: false,
            failReason: `계정 상태: ${existing.status}`,
          },
        });
        const error =
          existing.status === "withdrawn" ? "탈퇴 처리된 계정입니다." : "이용이 제한된 계정입니다.";
        return NextResponse.json(
          { success: false, error, code: "ACCOUNT_" + existing.status.toUpperCase() },
          { status: 403, headers: CORS_HEADERS }
        );
      }

      // [복주머니 정책표 §3] "첫 로그인" 판별은 email 로그인과 동일하게 lastLoginAt이
      // 지금까지 null이었는지로 판단한다(가입 시점엔 채우지 않으므로 최초 로그인에 해당).
      const isFirstLogin = existing.lastLoginAt == null;

      await prisma.user.update({
        where: { id: existing.id },
        data: { lastLoginAt: new Date() },
      });
      await prisma.userLoginLog.create({
        data: { userId: existing.id, loginType: provider, ipAddress, successFlag: true },
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
              userId: existing.id,
              amount,
              sourceType: "first_login_reward",
              memo: `첫 로그인 보상 +${amount} 복주머니`,
            });
          });
          firstLoginReward = { amount, balanceAfter: result.balanceAfter };
        }
      }

      const token = await signUserToken({ userId: existing.id, nickname: existing.nickname });
      return NextResponse.json(
        { success: true, data: { user: toUserDto(existing), token, firstLoginReward } },
        { headers: CORS_HEADERS }
      );
    }

    // ── 신규 회원: 가입 처리 ───────────────────────────────────────────
    const nickname = await buildUniqueNickname(verified.nicknameHint, provider);
    const bronzeGrade = await prisma.userGrade.findUnique({ where: { code: "bronze" } });

    const signupRewardPolicy = await prisma.pointPolicy.findUnique({
      where: { sourceType: "signup_reward" },
    });
    const signupRewardAmount =
      signupRewardPolicy?.isActive === false ? 0 : signupRewardPolicy?.amount ?? 20;

    const { created, walletBalanceAfter } = await prisma.$transaction(async (tx) => {
      const now = new Date();
      const user = await tx.user.create({
        data: {
          email: verified.email,
          nickname,
          ...(provider === "kakao"
            ? { kakaoId: verified.socialId }
            : { googleId: verified.socialId }),
          signupChannel: provider,
          gradeId: bronzeGrade?.id ?? null,
          termsAgreedAt: now,
          privacyAgreedAt: now,
          lastLoginAt: now,
        },
        include: { grade: true, profile: true },
      });

      await tx.userLoginLog.create({
        data: { userId: user.id, loginType: provider, ipAddress, successFlag: true },
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
      // 동시 요청 등으로 kakaoId/googleId unique 제약에 걸린 극히 드문 경쟁 상태.
      return NextResponse.json(
        { success: false, error: "이미 가입된 계정입니다. 다시 로그인해 주세요.", code: "DUPLICATE" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error(`[POST /api/public/auth/social-login] (${provider}) 실패:`, e);
    return NextResponse.json(
      { success: false, error: "소셜 로그인 중 오류가 발생했습니다." },
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
