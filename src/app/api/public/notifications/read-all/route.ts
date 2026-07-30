// 공개(비인증) 전체 알림 읽음 처리 API — Flutter NotificationRepository.markAllRead() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.notification.updateMany({
      where: { userId, isRead: false, deletedAt: null },
      data: { isRead: true },
    });

    return NextResponse.json(
      { success: true, data: { updatedCount: result.count } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/notifications/read-all] 실패:", e);
    return NextResponse.json(
      { success: false, error: "전체 읽음 처리에 실패했습니다." },
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
