// [복주머니 마케팅 쿠폰 최종본 §5] GET /api/admin/bokju-coupons/image-jobs/:id
// 이미지 생성 작업 진행률/결과 조회(화면이 2~3초 간격으로 polling).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { getImageJob } from "@/lib/bokju-coupon-image-service";

export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const jobId = Number(id);
  if (!Number.isInteger(jobId)) return jsonError("jobId가 올바르지 않습니다.");

  const job = await getImageJob(jobId);
  if (!job) return jsonError("작업을 찾을 수 없습니다.", 404);

  return jsonOk({
    id: job.id,
    campaignId: job.campaignId,
    status: job.status,
    totalCount: job.totalCount,
    processedCount: job.processedCount,
    failedCount: job.failedCount,
    failedCouponIds: job.failedCouponIds ? JSON.parse(job.failedCouponIds) : [],
    zipPath: job.zipPath,
    excelPath: job.excelPath,
    startedAt: job.startedAt?.toISOString() ?? null,
    completedAt: job.completedAt?.toISOString() ?? null,
    createdAt: job.createdAt.toISOString(),
  });
}
