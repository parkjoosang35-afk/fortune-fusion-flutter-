// [복주머니 마케팅 쿠폰 최종본 §12 "감사 로그"] 발행·배정·전달·배포보고·회수·
// 재배정·중지 등 담당자 행위 기록 공용 헬퍼. page-config-helpers.ts의
// writeAuditLog()와 동일한 패턴이지만 bokju 전용 테이블(BokjuCouponAuditLog)에
// 쓴다(서로 다른 도메인의 actionType을 한 테이블에 섞지 않기 위함).
import { prisma } from "@/lib/db";

export async function writeCouponAuditLog(params: {
  actorId: string | null;
  actorType?: "ADMIN" | "PARTNER" | "SYSTEM";
  campaignId?: number | null;
  targetType: "CAMPAIGN" | "COUPON" | "ALLOCATION" | "PARTNER";
  targetId?: number | null;
  actionType: string;
  summary: string;
  payload?: unknown;
}): Promise<void> {
  try {
    await prisma.bokjuCouponAuditLog.create({
      data: {
        actorId: params.actorId,
        actorType: params.actorType ?? "ADMIN",
        campaignId: params.campaignId ?? null,
        targetType: params.targetType,
        targetId: params.targetId ?? null,
        actionType: params.actionType,
        summary: params.summary,
        payload: params.payload !== undefined ? JSON.stringify(params.payload) : null,
      },
    });
  } catch (e) {
    // 감사 로그 실패가 본 흐름(쿠폰 발행/배정 등)을 막으면 안 된다.
    console.error("[writeCouponAuditLog] 실패:", e);
  }
}
