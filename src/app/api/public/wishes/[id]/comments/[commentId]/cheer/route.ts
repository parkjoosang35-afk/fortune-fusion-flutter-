// 공개(비인증) 소원 댓글 "응원(cheer)" API.
//
// [재화 구조 정리 - 재연결] LuckPouchRule(spend/cheer, targetScope=wish_board)가
// 지금까지 어떤 API에서도 소비되지 않던 참고용 시드였던 것을, 실제 댓글 응원
// 액션과 연결한다. 기존 "소원 응원(support)" 토글(무료, 좋아요류)과는 별개의
// 기능이다 — support는 소원 글 자체에 대한 무료 반응, cheer는 "댓글"에 대해
// 복주머니를 소비하는 유료 반응(토글 아님, 누를 때마다 카운트 증가 + 차감).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch, getSpendRuleAmount } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const FALLBACK_AMOUNT = 2; // luck_pouch_rules(cheer) 시드 기본값과 동일

function parseDbId(idParam: string, prefix: string): number | null {
  const match = new RegExp(`^${prefix}_(\\d+)$`).exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; commentId: string }> }
) {
  const { id, commentId: commentIdParam } = await params;
  const wishId = parseDbId(id, "wp");
  const commentId = parseDbId(commentIdParam, "wc");
  if (wishId === null || commentId === null) {
    return NextResponse.json(
      { success: false, error: "id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const result = await prisma.$transaction(async (tx) => {
      const comment = await tx.comment.findFirst({
        where: { id: commentId, targetType: "wish", targetId: wishId, status: "active", deletedAt: null },
      });
      if (!comment) throw new Error("COMMENT_NOT_FOUND");

      const amount = await getSpendRuleAmount(tx, "cheer", FALLBACK_AMOUNT);
      const spendResult = await spendLuckPouch(tx, {
        userId,
        amount,
        sourceType: "wish_comment_cheer",
        sourceId: commentId,
        memo: "댓글 응원(cheer)",
      });
      if (!spendResult.ok) {
        throw new Error(`INSUFFICIENT_BALANCE:${spendResult.balanceAfter ?? 0}`);
      }

      const updated = await tx.comment.update({
        where: { id: commentId },
        data: { cheerCount: { increment: 1 } },
      });

      return { updated, amount, balanceAfter: spendResult.balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          commentId: `wc_${result.updated.id}`,
          cheerCount: result.updated.cheerCount,
          amountSpent: result.amount,
          balanceAfter: result.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "COMMENT_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "댓글을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message.startsWith("INSUFFICIENT_BALANCE:")) {
      const balance = Number(message.split(":")[1] ?? 0);
      return NextResponse.json(
        { success: false, error: "복주머니가 부족합니다.", data: { balance } },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes/[id]/comments/[commentId]/cheer] 실패:", e);
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
