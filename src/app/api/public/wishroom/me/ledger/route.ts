// 복주머니 적립/사용 내역 — Flutter WrRepository.ledger() 대응.
// [원본] app/api.js 보조 · GET /me/ledger (db.ledger 포팅).
// 기존 공용 Wallet(POINT)의 PointHistory 원장을 그대로 사용 — 소원방 전용 로그가
// 아니라 사용자의 전체 복주머니 히스토리를 보여준다(단일 지갑 원칙).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const rows = await prisma.pointHistory.findMany({
      where: { userId: auth.userId },
      orderBy: { createdAt: "desc" },
      take: 200,
    });

    const data = rows.map((r) => ({
      label: r.memo ?? r.sourceType,
      sub: r.sourceType,
      amount: r.amount,
      at: r.createdAt.getTime(),
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
