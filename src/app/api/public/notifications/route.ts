// 공개(비인증) 알림 목록 조회 API — Flutter NotificationRepository.getList() 대응.
// [문서2/문서7 B-1 반영] notification_provider.dart가 완전 Mock(하드코딩 2건)이었던
// 상태를 실연동으로 전환하기 위한 신규 라우트. 복합 인덱스가 필요한 orderBy+where
// 조합을 피하기 위해 where(userId)만 사용하고 정렬은 결과에서 메모리로 처리한다
// (다른 공개 API들의 확립된 패턴 — Firebase 가이드 "쿼리 최적화" 원칙과 동일 취지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");
  const limit = Math.min(100, Math.max(1, Number(searchParams.get("limit") ?? "50") || 50));

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 단순 where(userId)만 사용(복합 인덱스 불필요) + 메모리에서 최신순 정렬.
    const rows = await prisma.notification.findMany({
      where: { userId, deletedAt: null },
      orderBy: { sentAt: "desc" },
      take: limit,
    });

    const unreadCount = rows.filter((n) => !n.isRead).length;

    return NextResponse.json(
      {
        success: true,
        data: {
          notifications: rows.map((n) => ({
            id: n.id,
            title: n.title,
            body: n.body,
            isRead: n.isRead,
            sentAt: n.sentAt.toISOString(),
          })),
          unreadCount,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/notifications] 실패:", e);
    return NextResponse.json(
      { success: false, error: "알림 목록을 불러오지 못했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
