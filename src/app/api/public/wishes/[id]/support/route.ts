// 소원 응원 API — WishWallRepository.support() 대응.
//
// [STEP04] 기존 Like 폴리모픽 모델(targetType/targetId/userId, @@unique 제약)을
// targetType='wish'로 재사용해 "같은 사용자 + 같은 소원 = 중복 응원 불가"를
// 서버가 최종 판단한다(새 테이블/필드 추가 없음). 커뮤니티 게시글 좋아요
// (community/posts/[id]/like/route.ts)와 달리 이 응원(support)은 토글이 아니라
// "일회성(create-only, idempotent)" 액션이다 — 이미 응원했으면 취소하지 않고
// alreadySupported:true만 반환한다(응원 취소 기능은 이번 STEP 범위 밖).
//
// 처리 순서: (1)사용자 확인 (2)소원 확인 (3)중복 응원 여부 확인
// (4)응원 기록 저장 (5)supportCount 증가 (6)트랜잭션 (7)결과 반환.
//
// [보상 없음] 응원 자체에는 이번 STEP에서 복주머니를 지급하지 않는다
// (새 PointPolicy 추가 금지 원칙).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  parseWishDbId,
  requireUser,
  toWishDto,
  unauthorizedResponse,
  type WishRow,
} from "../../_shared";

export const dynamic = "force-dynamic";

const SUPPORT_TARGET_TYPE = "wish";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { id } = await params;
  const dbId = parseWishDbId(id);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "wishId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // (2) 소원 확인
      const existing = await tx.wish.findUnique({ where: { id: dbId } });
      if (!existing || existing.deletedAt != null) {
        throw new Error("WISH_NOT_FOUND");
      }
      if (existing.status !== "visible" && existing.status !== "gratitude") {
        throw new Error("WISH_NOT_SUPPORTABLE");
      }

      // (3) 중복 응원 여부 확인 — Like 테이블의 @@unique(targetType, targetId, userId)
      // 제약을 그대로 조회 조건에 사용한다(서버가 최종 판단, 클라이언트 로컬
      // 플래그는 신뢰하지 않는다).
      const existingLike = await tx.like.findUnique({
        where: {
          targetType_targetId_userId: {
            targetType: SUPPORT_TARGET_TYPE,
            targetId: dbId,
            userId: auth.userId,
          },
        },
      });

      if (existingLike) {
        // 이미 응원한 경우: 기록/카운트 변경 없이 현재 상태만 반환한다.
        const withUser = await tx.wish.findUnique({
          where: { id: dbId },
          include: { user: { select: { nickname: true } } },
        });
        return { wish: withUser!, alreadySupported: true };
      }

      // (4) 응원 기록 저장 (5) supportCount 증가 — 같은 트랜잭션 안에서 원자 처리.
      await tx.like.create({
        data: {
          targetType: SUPPORT_TARGET_TYPE,
          targetId: dbId,
          userId: auth.userId,
        },
      });
      const updated = await tx.wish.update({
        where: { id: dbId },
        data: { supportCount: { increment: 1 } },
        include: { user: { select: { nickname: true } } },
      });

      return { wish: updated, alreadySupported: false };
    });

    const dto = toWishDto(
      result.wish as unknown as WishRow,
      auth.userId,
      true // 이 응답을 받는 시점에는 항상 "내가 응원한 상태"이다(신규/기존 응원 모두).
    );
    return NextResponse.json(
      {
        success: true,
        alreadySupported: result.alreadySupported,
        data: dto,
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WISH_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "WISH_NOT_SUPPORTABLE") {
      return NextResponse.json(
        { success: false, error: "응원할 수 없는 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes/:id/support] 실패:", e);
    return NextResponse.json(
      { success: false, error: "응원 처리에 실패했습니다." },
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
