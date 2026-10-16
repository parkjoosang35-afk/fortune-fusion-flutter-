// [복주머니 마케팅 쿠폰 최종본 §5 "실패 재시도"] POST .../image-jobs/:id/retry
// 실패한 쿠폰 이미지만 재생성한다(전체 재생성 금지 원칙).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { retryFailedImages } from "@/lib/bokju-coupon-image-service";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const jobId = Number(id);
  if (!Number.isInteger(jobId)) return jsonError("jobId가 올바르지 않습니다.");

  try {
    const registerBaseUrl =
      process.env.NEXT_PUBLIC_APP_BASE_URL || new URL(request.url).origin.replace(/:\d+$/, "");
    const result = await retryFailedImages(jobId, { registerBaseUrl });
    return jsonOk(result, 202);
  } catch (e) {
    console.error("[POST image-jobs/:id/retry] 실패:", e);
    return jsonError(e instanceof Error ? e.message : "재시도 중 오류가 발생했습니다.", 400);
  }
}
