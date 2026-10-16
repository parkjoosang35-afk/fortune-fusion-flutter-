// [복주머니 마케팅 쿠폰] GET /api/admin/bokju-coupons/push-jobs/:id
// 푸시 발송 작업 진행 상태 polling(이미지 생성 작업의 image-jobs/:id와 동일 패턴).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { getPushJob } from "@/lib/bokju-coupon-service";

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

  const job = await getPushJob(jobId);
  if (!job) return jsonError("발송 작업을 찾을 수 없습니다.", 404);

  return jsonOk({
    id: job.id,
    campaignId: job.campaignId,
    sendMode: job.sendMode,
    targetFilter: job.targetFilter,
    title: job.title,
    body: job.body,
    status: job.status,
    successCount: job.successCount,
    failCount: job.failCount,
    isTest: job.isTest,
    createdAt: job.createdAt,
    completedAt: job.completedAt,
  });
}
