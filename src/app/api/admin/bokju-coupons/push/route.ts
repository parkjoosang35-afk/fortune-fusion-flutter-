// [복주머니 마케팅 쿠폰 최종본 §10 "기존 회원 푸시 알림" + §22.5]
// POST /api/admin/bokju-coupons/push — 전체 이벤트 안내(BROADCAST) 또는
// 개별 회원 선물(INDIVIDUAL) 발송을 시작한다. 테스트 발송(isTest=true)은
// 즉시 처리하고 202가 아닌 200으로 응답하며, 그 외에는 작업만 생성하고
// 실제 발송은 백그라운드로 넘겨 202 + jobId를 반환한다(이미지 생성과 동일 패턴).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { createPushJob, BokjuCouponError } from "@/lib/bokju-coupon-service";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const campaignId = Number(body.campaignId);
    const sendMode = body.sendMode === "INDIVIDUAL" ? "INDIVIDUAL" : "BROADCAST";
    const targetFilter =
      body.targetFilter === "NEW" || body.targetFilter === "EXISTING" || body.targetFilter === "SPECIFIC"
        ? body.targetFilter
        : "ALL";
    const targetUserIds = Array.isArray(body.targetUserIds)
      ? body.targetUserIds.map((v: unknown) => Number(v)).filter((n: number) => Number.isInteger(n))
      : undefined;
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const messageBody = typeof body.body === "string" ? body.body.trim() : "";
    const scheduledAt = body.scheduledAt ? new Date(body.scheduledAt) : undefined;
    const isTest = body.isTest === true;

    if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

    const result = await createPushJob(
      { campaignId, sendMode, targetFilter, targetUserIds, title, body: messageBody, scheduledAt, isTest },
      actor.adminId
    );

    if ("test" in result) {
      return jsonOk(result, 200);
    }

    await writeCouponAuditLog({
      actorId: actor.adminId,
      actorType: "ADMIN",
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "PUSH_SEND_START",
      summary:
        sendMode === "INDIVIDUAL"
          ? `개별 회원 ${targetUserIds?.length ?? 0}명에게 쿠폰 선물 발송 시작`
          : `전체 회원 대상(${targetFilter}) 이벤트 안내 발송 시작`,
    });

    return jsonOk(result, 202);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/push] 실패:", e);
    return jsonError("푸시 발송 시작 중 오류가 발생했습니다.", 500);
  }
}
