// 알림센터 — Flutter WrRepository.notifications()/readNotifications() 대응.
// [원본] app/api.js 라우트 18 · GET /notifications(전체 목록) · POST /notifications(전체/특정 읽음).
//
// [NotiType 인코딩] 공용 `Notification` 테이블에는 category/deepLink만 있고 type 컬럼이
// 없다 — _shared.ts의 wrNotificationDeepLink()/parseWrNotificationDeepLink()로
// "wishroom:{publicId}?type=XXX" 포맷을 통해 type/roomId를 deepLink 하나에 함께 싣고,
// 조회 시 그 문자열을 다시 분해해 Flutter WrNotification.fromJson 계약(id/text/type/roomId/at/read)에
// 맞춰 변환한다. 소원방 알림만 대상으로 하므로 category="community"이면서
// deepLink가 "wishroom:"으로 시작하는 것만 조회한다(다른 도메인의 community 알림과 혼재 방지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWrNotificationDeepLink } from "../_shared";

export const dynamic = "force-dynamic";

function toNotificationDto(n: { id: number; title: string; body: string; deepLink: string | null; createdAt: Date; isRead: boolean }) {
  const { roomId, type } = parseWrNotificationDeepLink(n.deepLink);
  return {
    id: String(n.id),
    type,
    text: n.body || n.title,
    roomId,
    at: n.createdAt.getTime(),
    read: n.isRead,
  };
}

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const rows = await prisma.notification.findMany({
      where: { userId: auth.userId, category: "community", deepLink: { startsWith: "wishroom:" }, deletedAt: null },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    return NextResponse.json({ success: true, data: rows.map(toNotificationDto) }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { id?: string };
  try {
    body = await request.json().catch(() => ({}));
  } catch {
    body = {};
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const where: Record<string, unknown> = {
        userId: auth.userId,
        category: "community",
        deepLink: { startsWith: "wishroom:" },
        deletedAt: null,
      };
      if (body.id) {
        const numId = Number(body.id);
        if (!Number.isFinite(numId)) return { unread: await tx.notification.count({ where: { ...where, isRead: false } }) };
        where.id = numId;
      }
      await tx.notification.updateMany({ where, data: { isRead: true } });

      const unread = await tx.notification.count({
        where: { userId: auth.userId, category: "community", deepLink: { startsWith: "wishroom:" }, deletedAt: null, isRead: false },
      });
      return { unread };
    });
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
