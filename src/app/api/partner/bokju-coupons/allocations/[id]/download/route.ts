// [복주머니 마케팅 쿠폰] GET /api/partner/bokju-coupons/allocations/:id/download
// 업체 전용 — 본인에게 배정된 쿠폰 이미지만 ZIP으로 다운로드(타 업체 쿠폰 노출 금지).
// 이미지가 아직 생성되지 않았으면(관리자가 이미지 생성을 안 했으면) 404.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requirePartnerOrResponse, isPartnerSession } from "@/lib/partner-session";
import { buildAllocationZip } from "@/lib/bokju-coupon-image-service";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await requirePartnerOrResponse();
  if (!isPartnerSession(session)) return session;

  const { id } = await params;
  const allocationId = Number(id);
  if (!Number.isInteger(allocationId)) {
    return NextResponse.json({ success: false, error: "allocationId가 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const allocation = await prisma.bokjuCouponAllocation.findUnique({ where: { id: allocationId } });
    if (!allocation || allocation.partnerId !== session.partnerId) {
      return NextResponse.json({ success: false, error: "본인 업체의 배정이 아닙니다." }, { status: 403, headers: CORS_HEADERS });
    }

    const coupons = await prisma.bokjuCoupon.findMany({
      where: { allocationId },
      select: { id: true },
      orderBy: { id: "asc" },
    });
    if (coupons.length === 0) {
      return NextResponse.json({ success: false, error: "배정된 쿠폰이 없습니다." }, { status: 404, headers: CORS_HEADERS });
    }

    const zipBuffer = await buildAllocationZip(allocation.campaignId, allocationId, coupons.map((c) => c.id));

    return new NextResponse(new Uint8Array(zipBuffer), {
      status: 200,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": "application/zip",
        "Content-Disposition": `attachment; filename="coupons_allocation_${allocationId}.zip"`,
      },
    });
  } catch (e) {
    console.error("[GET /api/partner/bokju-coupons/allocations/:id/download] 실패:", e);
    return NextResponse.json({ success: false, error: "다운로드 중 오류가 발생했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}
