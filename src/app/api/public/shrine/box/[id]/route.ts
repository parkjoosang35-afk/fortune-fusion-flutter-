// 신당(THE SHRINE) v3 — 10 부적함 상세 조회. 唯一 기록(이름/사주/소망/일련번호)
// 전체와 향 올리기 상태(오늘 올렸는지)를 함께 반환한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  requireUser,
  unauthorizedResponse,
  daysRemainingFromExpiry,
  todayKstKey,
} from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { id } = await params;
  const orderId = Number(id);
  if (!Number.isInteger(orderId) || orderId <= 0) {
    return NextResponse.json(
      { success: false, error: "orderId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const order = await prisma.shrineOrder.findFirst({
      where: { id: orderId, userId: auth.userId },
      include: { talismanItem: true },
    });
    if (!order) {
      return NextResponse.json(
        { success: false, error: "부적을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    const daysRemaining = daysRemainingFromExpiry(order.expiresDateKey);
    const expired = daysRemaining <= 0;
    return NextResponse.json(
      {
        success: true,
        data: {
          orderId: order.id,
          serial: order.serial,
          ownerName: order.ownerName,
          sajuPillars: order.sajuPillars,
          wish: order.wish,
          issuedDateKey: order.issuedDateKey,
          expiresDateKey: order.expiresDateKey,
          daysRemaining,
          displayStatus: order.status === "ARCHIVED" ? "ARCHIVED" : expired ? "EXPIRED" : "ACTIVE",
          incenseLitToday: order.lastIncenseDateKey === todayKstKey(),
          createdAt: order.createdAt.toISOString(),
          talisman: {
            slug: order.talismanItem.slug,
            category: order.talismanItem.category,
            hanja: order.talismanItem.hanja,
            name: order.talismanItem.name,
            aim: order.talismanItem.aim,
            sub: order.talismanItem.sub,
            meaning: order.talismanItem.meaning,
            effects: order.talismanItem.effects,
            recommendFor: order.talismanItem.recommendFor,
            validityTerm: order.talismanItem.validityTerm,
            usage: order.talismanItem.usage,
            goesWith: order.talismanItem.goesWith,
            imagePath: order.talismanItem.imagePath,
            thumbPath: order.talismanItem.thumbPath,
          },
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/shrine/box/:id] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 정보를 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
