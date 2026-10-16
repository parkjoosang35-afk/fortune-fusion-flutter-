// [복주머니 마케팅 쿠폰 최종본 §5] POST /api/admin/bokju-coupons/campaigns/:id/generate-images
// 캠페인에 발행된 전체 쿠폰에 대해 모바일 쿠폰 이미지(QR 합성) 대량 생성을
// 백그라운드 작업으로 시작한다. 요청은 즉시 jobId를 반환하고, 진행률은
// GET /api/admin/bokju-coupons/image-jobs/:id로 polling한다.
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { startImageGenerationJob } from "@/lib/bokju-coupon-image-service";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    // 등록(QR) 링크 기준 도메인. 운영 환경 변수가 없으면 요청 Origin을 사용한다.
    const registerBaseUrl =
      process.env.NEXT_PUBLIC_APP_BASE_URL || new URL(request.url).origin.replace(/:\d+$/, "");

    const result = await startImageGenerationJob(campaignId, actor.adminId, { registerBaseUrl });

    await writeCouponAuditLog({
      actorId: actor.adminId,
      actorType: "ADMIN",
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "IMAGE_GENERATE_START",
      summary: `모바일 쿠폰 이미지 생성 시작(${result.totalCount}장)`,
    });

    return jsonOk(result, 202);
  } catch (e) {
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/generate-images] 실패:", e);
    return jsonError(e instanceof Error ? e.message : "이미지 생성 작업 시작 중 오류가 발생했습니다.", 400);
  }
}
