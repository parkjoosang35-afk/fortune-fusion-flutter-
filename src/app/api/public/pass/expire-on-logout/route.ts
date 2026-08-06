// 공개(비인증) 로그아웃 시 프리패스 강제 만료 API — Flutter PassProvider.resetOnLogout() 대응.
// [재화 구조 정리 - 로그아웃 시 프리패스 서버측 만료] 사용자가 로그아웃하면(이유 불문)
// 현재 활성 상태인 UserPass를 서버 DB에서 즉시, 영구적으로 만료시킨다.
// 클라이언트 상태만 지우는 것으로는 재로그인 시 서버가 여전히 유효하다고 판단해
// 잔여시간이 복원되는 문제가 있었음(버그 리포트 반영) — 이 API는 expiresAt을
// 현재 시각으로 앞당기고 status를 revoked로 전환해, 이후 어떤 조회
// (/pass/status, /pass/consume, /pass/claim-ad의 idempotent 체크 등)에서도
// 더 이상 유효한 패스로 인식되지 않도록 한다(기존 라우트들의 조회 조건은
// `expiresAt: { gt: now }` 이므로 expiresAt 자체를 당기는 것으로 모든 기존
// 조회 경로에 즉시, 일관되게 반영된다).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const now = new Date();

    // 현재 유효한(만료되지 않은) 모든 UserPass를 조회한다(정상적으로는 1건이지만
    // 방어적으로 all-match 처리 — 과거 동시발급 등 예외 상황 대비).
    const activePasses = await prisma.userPass.findMany({
      where: { userId, expiresAt: { gt: now } },
    });

    if (activePasses.length === 0) {
      return NextResponse.json(
        { success: true, data: { expiredCount: 0 } },
        { headers: CORS_HEADERS }
      );
    }

    await prisma.$transaction(async (tx) => {
      for (const pass of activePasses) {
        await tx.userPass.update({
          where: { id: pass.id },
          data: {
            expiresAt: now,
            status: "revoked",
            revokedAt: now,
          },
        });

        await tx.operationLog.create({
          data: {
            actorType: "user",
            actorId: userId,
            action: "expire_pass_on_logout",
            targetType: "user_pass",
            targetId: pass.id,
            before: JSON.stringify({ expiresAt: pass.expiresAt.toISOString(), status: pass.status }),
            after: JSON.stringify({ expiresAt: now.toISOString(), status: "revoked" }),
          },
        });
      }
    });

    return NextResponse.json(
      { success: true, data: { expiredCount: activePasses.length } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/expire-on-logout] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프리패스 만료 처리 중 오류가 발생했습니다." },
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
