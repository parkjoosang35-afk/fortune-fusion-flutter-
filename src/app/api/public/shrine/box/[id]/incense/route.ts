// 신당(THE SHRINE) v3 — §7 향 올리기. 하루 1회, +3일(최대 49일), 서버 시간
// (KST) 기준. ShrineIncenseLog.@@unique([shrineOrderId, dateKey])가 동시
// 요청에서도 "하루 1회"를 원자적으로 보장한다(이중 안전장치 — 호출 전에도
// lastIncenseDateKey로 먼저 막지만, 최종 방어는 DB 유니크 제약).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  requireUser,
  unauthorizedResponse,
  daysRemainingFromExpiry,
  todayKstKey,
  addDaysToKstKey,
  SHRINE_LIFE_DAYS,
  SHRINE_INCENSE_BONUS_DAYS,
} from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(
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

  const today = todayKstKey();

  try {
    const order = await prisma.shrineOrder.findFirst({ where: { id: orderId, userId: auth.userId } });
    if (!order) {
      return NextResponse.json(
        { success: false, error: "부적을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (order.status === "ARCHIVED") {
      return NextResponse.json(
        { success: false, error: "보관 중인 부적에는 향을 올릴 수 없습니다.", reason: "ARCHIVED" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    const currentRemaining = daysRemainingFromExpiry(order.expiresDateKey);
    if (currentRemaining <= 0) {
      // README §2 "10(기간 만료) → 「같은 부적 다시 부탁하기」 → 05" — 향이
      // 아니라 05 상세로 돌아가 재주문해야 한다.
      return NextResponse.json(
        {
          success: false,
          error: "부적의 기운이 다했습니다. 같은 부적을 다시 부탁해보세요.",
          reason: "EXPIRED",
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    if (order.lastIncenseDateKey === today) {
      return NextResponse.json(
        { success: false, error: "오늘은 이미 향을 올렸어요. 내일 다시 올 수 있어요.", reason: "ALREADY_LIT_TODAY" },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // README §7 "+3일(최대 49)" — 오늘 기준 남은 일수가 49를 넘지 않도록 clamp.
    const extended = addDaysToKstKey(order.expiresDateKey, SHRINE_INCENSE_BONUS_DAYS);
    const maxAllowed = addDaysToKstKey(today, SHRINE_LIFE_DAYS);
    const newExpiresDateKey = extended > maxAllowed ? maxAllowed : extended;

    const result = await prisma.$transaction(async (tx) => {
      // 동시 요청(더블탭 등)에도 "하루 1회"를 DB 유니크 제약으로 최종 방어.
      await tx.shrineIncenseLog.create({
        data: {
          shrineOrderId: order.id,
          dateKey: today,
          daysBefore: currentRemaining,
          daysAfter: daysRemainingFromExpiry(newExpiresDateKey),
        },
      });
      return tx.shrineOrder.update({
        where: { id: order.id },
        data: {
          expiresDateKey: newExpiresDateKey,
          lastIncenseDateKey: today,
          daysRemaining: daysRemainingFromExpiry(newExpiresDateKey),
        },
      });
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          orderId: result.id,
          daysBefore: currentRemaining,
          daysAfter: daysRemainingFromExpiry(result.expiresDateKey),
          expiresDateKey: result.expiresDateKey,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const code = (e as { code?: string }).code;
    if (code === "P2002") {
      // ShrineIncenseLog 유니크 제약 충돌 — 동시 요청 중 하나만 성공, 나머지는 거부.
      return NextResponse.json(
        { success: false, error: "오늘은 이미 향을 올렸어요. 내일 다시 올 수 있어요.", reason: "ALREADY_LIT_TODAY" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/shrine/box/:id/incense] 실패:", e);
    return NextResponse.json(
      { success: false, error: "향을 올리지 못했습니다. 잠시 후 다시 시도해주세요." },
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
