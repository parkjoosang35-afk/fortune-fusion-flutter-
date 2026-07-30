// 공개(비인증) 알림 읽음 처리 API — Flutter NotificationRepository.markRead() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const notificationId = Number(id);
  if (!Number.isInteger(notificationId) || notificationId <= 0) {
    return NextResponse.json(
      { success: false, error: "알림 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const existing = await prisma.notification.findUnique({
      where: { id: notificationId },
    });
    if (!existing) {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 알림입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    if (!existing.isRead) {
      await prisma.notification.update({
        where: { id: notificationId },
        data: { isRead: true },
      });
    }

    return NextResponse.json({ success: true, data: { id: notificationId, isRead: true } }, {
      headers: CORS_HEADERS,
    });
  } catch (e) {
    console.error("[POST /api/public/notifications/[id]/read] 실패:", e);
    return NextResponse.json(
      { success: false, error: "읽음 처리에 실패했습니다." },
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
