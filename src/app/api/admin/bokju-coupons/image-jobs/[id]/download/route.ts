// [복주머니 마케팅 쿠폰 — 턴D(02w §0-AA-4)] GET /api/admin/bokju-coupons/image-jobs/:id/download
// 쿠폰 이미지 ZIP을 파일로 미리 만들어 두지 않고, 요청 시점에 그 자리에서
// 응답 스트림으로 직접 흘려보낸다(참고구현 streamImagesZip(res, items, meta)와
// 동일한 패턴). 기존에는 runImageJob() 완료 시점에 미리 zip 파일을 만들어
// zipPath를 DB에 저장해 두었으나, 그 경로가 public/ 밖(storage/ 그리고 이후
// /var/lib/...)인데 응답에는 public 경로 문자열을 돌려주는 "깨진 링크" 상태가
// 발생했다(02t/02u/02w 보안 수정) — 스트리밍으로 바꾸면 그 불일치가 원천
// 차단된다. 쿼리 파라미터 part/part_size로 대용량 캠페인을 분할 다운로드할
// 수 있다(참고구현과 동일, 기본 partSize=1000).
import { PassThrough, Readable } from "stream";
import { prisma } from "@/lib/db";
import { jsonError, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { getImageJob, streamCouponImagesZip } from "@/lib/bokju-coupon-image-service";

export const dynamic = "force-dynamic";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const jobId = Number(id);
  if (!Number.isInteger(jobId)) return jsonError("jobId가 올바르지 않습니다.");

  const job = await getImageJob(jobId);
  if (!job) return jsonError("작업을 찾을 수 없습니다.", 404);

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: job.campaignId } });
  if (!campaign) return jsonError("캠페인을 찾을 수 없습니다.", 404);

  const coupons = await prisma.bokjuCoupon.findMany({
    where: { campaignId: job.campaignId },
    select: { id: true },
    orderBy: { id: "asc" },
  });
  if (coupons.length === 0) return jsonError("발행된 쿠폰이 없습니다.", 404);

  const url = new URL(request.url);
  const part = Number(url.searchParams.get("part") ?? 1);
  const partSize = Number(url.searchParams.get("part_size") ?? 1000);

  const passthrough = new PassThrough();

  // await하지 않는다 — archive.finalize()가 쓰는 동안 동시에 Response가 그
  // 바이트를 읽어 흘려보내야 하므로, 여기서 기다리면 교착(deadlock)된다.
  streamCouponImagesZip(passthrough, job.campaignId, coupons.map((c) => c.id), {
    campaignTitle: campaign.title,
    part,
    partSize,
  }).catch((e) => {
    console.error(`[GET .../image-jobs/:id/download] 스트리밍 실패:`, e);
    passthrough.destroy(e instanceof Error ? e : new Error(String(e)));
  });

  const webStream = Readable.toWeb(passthrough) as unknown as ReadableStream;
  const encodedTitle = encodeURIComponent(`${campaign.title}_쿠폰이미지_part${part}.zip`);

  return new Response(webStream, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="coupons_part${part}.zip"; filename*=UTF-8''${encodedTitle}`,
    },
  });
}
