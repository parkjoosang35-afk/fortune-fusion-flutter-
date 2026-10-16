// [복주머니 마케팅 쿠폰] GET/POST /api/admin/bokju-coupons/campaigns
// 캠페인 목록 조회 + 신규 생성(DRAFT 상태로 시작).
import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import {
  createCampaign,
  BokjuCouponError,
  BOKJU_COUPON_DESIGN_TEMPLATES,
  type CreateCampaignInput,
} from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const campaigns = await prisma.bokjuCouponCampaign.findMany({
      orderBy: { createdAt: "desc" },
    });
    return jsonOk({
      campaigns: campaigns.map((c) => ({
        id: c.id,
        title: c.title,
        grantAmount: c.grantAmount,
        issueType: c.issueType,
        targetAudience: c.targetAudience,
        distributionMethod: c.distributionMethod,
        designTemplate: c.designTemplate,
        customTemplateId: c.customTemplateId,
        status: c.status,
        validFrom: c.validFrom.toISOString(),
        validTo: c.validTo.toISOString(),
        issuedCount: c.issuedCount,
        allocatedCount: c.allocatedCount,
        redeemedCount: c.redeemedCount,
        usedCount: c.usedCount,
        sharedTotalLimit: c.sharedTotalLimit,
        createdAt: c.createdAt.toISOString(),
      })),
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/campaigns] 실패:", e);
    return jsonError("캠페인 목록 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function POST(request: NextRequest) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const grantAmount = Number(body.grantAmount);
    if (!title) return jsonError("title은 필수입니다.");
    if (!Number.isInteger(grantAmount) || grantAmount <= 0) {
      return jsonError("grantAmount는 1 이상의 정수여야 합니다.");
    }
    if (!body.validFrom || !body.validTo) return jsonError("validFrom/validTo는 필수입니다.");

    const input: CreateCampaignInput = {
      title,
      grantAmount,
      issueType: body.issueType === "SHARED" ? "SHARED" : "INDIVIDUAL",
      targetAudience: ["ALL", "NEW", "EXISTING"].includes(body.targetAudience) ? body.targetAudience : "ALL",
      useLimitPerMember: Number.isInteger(body.useLimitPerMember) ? body.useLimitPerMember : 1,
      sharedTotalLimit: Number.isInteger(body.sharedTotalLimit) ? body.sharedTotalLimit : undefined,
      validFrom: new Date(body.validFrom),
      validTo: new Date(body.validTo),
      guideText: typeof body.guideText === "string" ? body.guideText : undefined,
      distributionMethod: ["DIRECT", "PARTNER", "GIFT"].includes(body.distributionMethod)
        ? body.distributionMethod
        : "PARTNER",
      designTemplate: BOKJU_COUPON_DESIGN_TEMPLATES.includes(body.designTemplate)
        ? body.designTemplate
        : "CLASSIC",
      customTemplateId:
        body.customTemplateId === null || body.customTemplateId === undefined || body.customTemplateId === ""
          ? null
          : Number.isInteger(Number(body.customTemplateId))
            ? Number(body.customTemplateId)
            : null,
    };

    const result = await createCampaign(input, actor.adminId);
    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/campaigns] 실패:", e);
    return jsonError("캠페인 생성 중 오류가 발생했습니다.", 500);
  }
}
