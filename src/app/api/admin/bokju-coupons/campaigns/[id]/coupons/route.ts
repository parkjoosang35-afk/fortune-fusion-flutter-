// [복주머니 마케팅 쿠폰] GET /api/admin/bokju-coupons/campaigns/:id/coupons
// 캠페인 소속 쿠폰 목록(상태/업체 배정 여부 포함) — "발행 쿠폰 관리"/"쿠폰 사용 내역" 화면용.
// 쿼리: ?status=ISSUED (선택), ?page=1&pageSize=50 (기본 50건 페이지네이션)
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  const url = new URL(request.url);
  const status = url.searchParams.get("status") || undefined;
  const page = Math.max(1, Number(url.searchParams.get("page")) || 1);
  const pageSize = Math.min(200, Math.max(1, Number(url.searchParams.get("pageSize")) || 50));

  try {
    const where = { campaignId, ...(status ? { status } : {}) };
    const [total, coupons] = await Promise.all([
      prisma.bokjuCoupon.count({ where }),
      prisma.bokjuCoupon.findMany({
        where,
        orderBy: { id: "asc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: { campaign: { select: { title: true } } },
      }),
    ]);

    return jsonOk({
      total,
      page,
      pageSize,
      coupons: coupons.map((c) => ({
        id: c.id,
        couponNo: c.couponNo,
        status: c.status,
        partnerId: c.partnerId,
        allocationId: c.allocationId,
        assignedUserId: c.assignedUserId,
        issuedAt: c.issuedAt.toISOString(),
        expiresAt: c.expiresAt.toISOString(),
        redeemedAt: c.redeemedAt ? c.redeemedAt.toISOString() : null,
        redeemedBy: c.redeemedBy,
        revokedAt: c.revokedAt ? c.revokedAt.toISOString() : null,
        revokedReason: c.revokedReason,
      })),
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/campaigns/:id/coupons] 실패:", e);
    return jsonError("쿠폰 목록 조회 중 오류가 발생했습니다.", 500);
  }
}
