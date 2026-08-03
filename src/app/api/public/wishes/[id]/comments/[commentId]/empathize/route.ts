// 공개(비인증) 소원 댓글 "공감(empathize)" API.
// cheer(응원)와 동일한 구조이나, 별도의 반응 종류(empathizeCount)와 금액(기본 1개)을
// 사용한다. [재화 구조 정리 - 재연결] LuckPouchRule(spend/empathize) 재연결.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch, getSpendRuleAmount } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const FALLBACK_AMOUNT = 1; // luck_pouch_rules(empathize) 시드 기본값과 동일

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

      const amount = await getSpendRuleAmount(tx, "empathize", FALLBACK_AMOUNT);
      const spendResult = await spendLuckPouch(tx, {
        userId,
        amount,
        sourceType: "wish_comment_empathize",
        sourceId: commentId,
        memo: "댓글 공감(empathize)",
      });
      if (!spendResult.ok) {
        throw new Error(`INSUFFICIENT_BALANCE:${spendResult.balanceAfter ?? 0}`);
      }

      const updated = await tx.comment.update({
        where: { id: commentId },
        data: { empathizeCount: { increment: 1 } },
      });

      return { updated, amount, balanceAfter: spendResult.balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          commentId: `wc_${result.updated.id}`,
          empathizeCount: result.updated.empathizeCount,
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
    console.error("[POST /api/public/wishes/[id]/comments/[commentId]/empathize] 실패:", e);
    return NextResponse.json(
      { success: false, error: "공감 처리에 실패했습니다." },
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
