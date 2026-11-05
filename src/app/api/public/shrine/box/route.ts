// 신당(THE SHRINE) v3 — 09 부적함 목록 조회. 로그인 사용자의 ShrineOrder
// 전체를 반환한다(소지 중/보관 중/기간 만료 전부 포함 — README §1 "기간이
// 끝나도 부적은 지워지지 않아요").
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  requireUser,
  unauthorizedResponse,
  daysRemainingFromExpiry,
  todayKstKey,
} from "../_shared";

export const dynamic = "force-dynamic";

function toBoxItemDto(order: {
  id: number;
  serial: string;
  ownerName: string;
  sajuPillars: string;
  wish: string;
  issuedDateKey: string;
  expiresDateKey: string;
  lastIncenseDateKey: string | null;
  status: string;
  createdAt: Date;
  talismanItem: { slug: string; category: string; hanja: string; name: string; imagePath: string; thumbPath: string | null };
}) {
  const daysRemaining = daysRemainingFromExpiry(order.expiresDateKey);
  const expired = daysRemaining <= 0;
  return {
    orderId: order.id,
    serial: order.serial,
    ownerName: order.ownerName,
    sajuPillars: order.sajuPillars,
    wish: order.wish,
    issuedDateKey: order.issuedDateKey,
    expiresDateKey: order.expiresDateKey,
    daysRemaining,
    // README §1 10행 상태 표기: 소지 중(ACTIVE & 미만료) / 기간 만료(만료) / 보관 중(ARCHIVED).
    displayStatus: order.status === "ARCHIVED" ? "ARCHIVED" : expired ? "EXPIRED" : "ACTIVE",
    incenseLitToday: order.lastIncenseDateKey === todayKstKey(),
    createdAt: order.createdAt.toISOString(),
    talisman: {
      slug: order.talismanItem.slug,
      category: order.talismanItem.category,
      hanja: order.talismanItem.hanja,
      name: order.talismanItem.name,
      imagePath: order.talismanItem.imagePath,
      thumbPath: order.talismanItem.thumbPath,
    },
  };
}

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const orders = await prisma.shrineOrder.findMany({
      where: { userId: auth.userId },
      include: { talismanItem: true },
      orderBy: { createdAt: "desc" },
    });
    const items = orders.map(toBoxItemDto);
    const summary = {
      active: items.filter((i) => i.displayStatus === "ACTIVE").length,
      expired: items.filter((i) => i.displayStatus === "EXPIRED").length,
      archived: items.filter((i) => i.displayStatus === "ARCHIVED").length,
    };
    return NextResponse.json(
      { success: true, data: { items, summary } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/shrine/box] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적함을 불러오지 못했습니다." },
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
