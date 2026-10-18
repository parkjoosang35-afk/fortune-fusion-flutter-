// [복주머니 마케팅 쿠폰 — 턴D(02w §0-AA-4)] GET /api/partner/bokju-coupons/allocations/:id/download
// 업체 전용 — 본인에게 배정된 쿠폰 이미지만 응답 스트림으로 직접 흘려보낸다
// (타 업체 쿠폰 노출 금지, allocation.partnerId !== session.partnerId면 403).
// 이미지가 아직 생성되지 않았으면(관리자가 이미지 생성을 안 했으면) 404.
// [턴D] buildAllocationZip(Buffer.concat 메모리 적재)을 제거하고
// streamAllocationZip(스트리밍)으로 전환했다 — 인증/격리 로직 자체는
// 이미 턴D 요구사항(본인 allocation만)을 충족하고 있었으므로 그대로 유지.
import { PassThrough, Readable } from "stream";
import { prisma } from "@/lib/db";
import { requirePartnerOrResponse, isPartnerSession } from "@/lib/partner-session";
import { streamAllocationZip } from "@/lib/bokju-coupon-image-service";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function jsonErr(message: string, status: number) {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await requirePartnerOrResponse();
  if (!isPartnerSession(session)) return session;

  const { id } = await params;
  const allocationId = Number(id);
  if (!Number.isInteger(allocationId)) {
    return jsonErr("allocationId가 올바르지 않습니다.", 400);
  }

  const allocation = await prisma.bokjuCouponAllocation.findUnique({ where: { id: allocationId } });
  if (!allocation || allocation.partnerId !== session.partnerId) {
    return jsonErr("본인 업체의 배정이 아닙니다.", 403);
  }

  const coupons = await prisma.bokjuCoupon.findMany({
    where: { allocationId },
    select: { id: true },
    orderBy: { id: "asc" },
  });
  if (coupons.length === 0) {
    return jsonErr("배정된 쿠폰이 없습니다.", 404);
  }

  const passthrough = new PassThrough();

  streamAllocationZip(passthrough, allocation.campaignId, allocationId, coupons.map((c) => c.id)).catch((e) => {
    console.error("[GET /api/partner/bokju-coupons/allocations/:id/download] 스트리밍 실패:", e);
    passthrough.destroy(e instanceof Error ? e : new Error(String(e)));
  });

  const webStream = Readable.toWeb(passthrough) as unknown as ReadableStream;

  return new Response(webStream, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="coupons_allocation_${allocationId}.zip"`,
    },
  });
}
