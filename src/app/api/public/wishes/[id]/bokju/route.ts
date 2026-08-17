// 복주머니 보내기 API — WishWallRepository.incrementPouch() 대응.
//
// [사용자 확정 원칙 - 가장 중요] Wallet 차감 + WishBokju 기록 + Wish.bokjuCount
// 증가를 반드시 하나의 Prisma $transaction으로 처리한다. 하나라도 실패하면
// 전체가 롤백되어야 한다.
//
// 트랜잭션 순서(6-1 지시사항 그대로):
//   1) authenticateRequest()로 로그인 사용자 확인
//   2) Wish 존재/공개상태 확인
//   3~4) spendLuckPouch()가 Wallet 잔액 확인 + 차감 + PointHistory 기록을
//        원자적으로 수행(luck-pouch-engine.ts, 기존 헬퍼 재사용 — 신규 로직 작성 없음)
//   5) WishBokju 기록
//   6) Wish.bokjuCount 증가
//   7) 성공 결과 반환
//
// [주의] Wallet/PointHistory 핵심 로직은 수정하지 않는다. spendLuckPouch()를
// 그대로 호출만 한다. sourceType='send_pouch'는 PointPolicy에 등록되어 있지
// 않으므로 checkPolicyEligibility 판정 없이 자유롭게 사용 가능(무제한 허용).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import {
  CORS_HEADERS,
  parseWishDbId,
  requireUser,
  toWishDto,
  unauthorizedResponse,
  type WishRow,
} from "../../_shared";

export const dynamic = "force-dynamic";

// [6-1-F 최종 승인 반영] Flutter UI(blessing_bag_bottom_sheet.dart)의
// perSendMax=5 스테퍼와 서버 허용금액이 불일치하는 문제가 있었으나, 이는
// 별도의 소원방 경제정책 확정 사안이며 이번 6-1 범위에서 임의로 서버 정책
// (WishBokju.amount 화이트리스트)을 확장해서는 안 된다는 결정에 따라 원래
// 값으로 되돌린다. schema.prisma 설계상 amount는 1/5/10/50/100 고정값이다.
// UI의 2/3/4 전송 가능 상태는 별도 정책 확정 전까지 그대로 두되(6-1-H에서
// 화면 동작 확인), 서버는 반드시 이 5개 값만 허용한다.
const ALLOWED_AMOUNTS = [1, 5, 10, 50, 100];

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

  let body: { amount?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const amount = Number(body.amount);
  if (!ALLOWED_AMOUNTS.includes(amount)) {
    return NextResponse.json(
      {
        success: false,
        error: "amount는 1/5/10/50/100 중 하나여야 합니다.",
      },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 2) Wish 존재/공개상태 확인
      const wish = await tx.wish.findUnique({ where: { id: dbId } });
      if (!wish || wish.deletedAt != null) {
        throw new Error("WISH_NOT_FOUND");
      }
      if (wish.status !== "visible" && wish.status !== "gratitude") {
        throw new Error("WISH_NOT_PUBLIC");
      }

      // 3~4) Wallet 잔액 확인 + 차감 + PointHistory 기록 (기존 헬퍼 그대로 재사용)
      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount,
        sourceType: "send_pouch",
        sourceId: wish.id,
        memo: "복주머니 보내기",
      });
      if (!spendResult.ok) {
        throw new Error("INSUFFICIENT_BALANCE");
      }

      // 5) WishBokju 기록
      await tx.wishBokju.create({
        data: {
          wishId: wish.id,
          userId: auth.userId,
          amount,
          source: "manual",
        },
      });

      // 6) Wish.bokjuCount 증가
      const updated = await tx.wish.update({
        where: { id: wish.id },
        data: { bokjuCount: { increment: amount } },
        include: { user: { select: { nickname: true } } },
      });

      return { updated, balanceAfter: spendResult.balanceAfter };
    });

    const dto = toWishDto(result.updated as unknown as WishRow, auth.userId);
    return NextResponse.json(
      { success: true, data: { ...dto, walletBalanceAfter: result.balanceAfter } },
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
    if (message === "WISH_NOT_PUBLIC") {
      return NextResponse.json(
        { success: false, error: "복주머니를 보낼 수 없는 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    if (message === "INSUFFICIENT_BALANCE") {
      return NextResponse.json(
        { success: false, error: "복주머니가 부족합니다.", reason: "INSUFFICIENT_BALANCE" },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes/:id/bokju] 실패:", e);
    return NextResponse.json(
      { success: false, error: "복주머니 보내기에 실패했습니다." },
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
