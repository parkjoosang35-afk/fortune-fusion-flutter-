// [AI 쿠폰 디자인 표시·숨김 기능 §4] GET/POST /api/admin/bokju-coupons/design-assets
// GET: 지금까지 생성된 AI 배경 이미지 목록(템플릿 생성/수정 화면의 "배경 선택" 목록).
// POST: 관리자가 자유 텍스트로 새 배경을 요청 → AI 호출 → 정규화된 PNG를 저장하고
// BokjuCouponDesignAsset 행을 만든다. [AiBackgroundError 정직한 실패 원칙]
// BOKJU_AI_IMAGE_API_KEY가 설정돼 있지 않으면 성공한 척하지 않고 명확한
// AI_NOT_CONFIGURED 오류를 그대로 반환한다(§4, 카카오 SDK 때와 동일한 원칙).
import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { generateCouponBackground, AiBackgroundError } from "@/lib/bokju-coupon-ai-background-client";
import { listDesignAssets } from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const assets = await listDesignAssets();
    return jsonOk({
      assets: assets.map((a) => ({ ...a, createdAt: a.createdAt.toISOString() })),
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/design-assets] 실패:", e);
    return jsonError("배경 이미지 목록 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function POST(request: NextRequest) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("배경 생성 권한이 없습니다.", 403);

  try {
    const body = await request.json().catch(() => ({}));
    const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
    if (!prompt) return jsonError("배경 요청 문구(prompt)를 입력해 주세요.");
    if (prompt.length > 500) return jsonError("배경 요청 문구는 500자 이내로 입력해 주세요.");

    // 먼저 GENERATING 상태로 행을 만들어 둔다(실패해도 "요청 이력"이 남아
    // 관리자가 무엇을 시도했었는지 추적 가능하도록).
    const asset = await prisma.bokjuCouponDesignAsset.create({
      data: { prompt, imagePath: "", status: "GENERATING", createdBy: actor.adminId },
    });

    try {
      const result = await generateCouponBackground(asset.id, prompt);
      const updated = await prisma.bokjuCouponDesignAsset.update({
        where: { id: asset.id },
        data: { imagePath: result.imagePath, status: "READY" },
      });
      return jsonOk(
        {
          id: updated.id,
          prompt: updated.prompt,
          imagePath: updated.imagePath,
          status: updated.status,
          createdAt: updated.createdAt.toISOString(),
        },
        201
      );
    } catch (genErr) {
      const code = genErr instanceof AiBackgroundError ? genErr.code : "AI_UNKNOWN_ERROR";
      const message = genErr instanceof AiBackgroundError ? genErr.message : "AI 배경 생성 중 알 수 없는 오류가 발생했습니다.";
      await prisma.bokjuCouponDesignAsset.update({
        where: { id: asset.id },
        data: { status: "FAILED", failReason: message },
      });
      console.error(
        `[POST /api/admin/bokju-coupons/design-assets] AI 생성 실패(assetId=${asset.id}, code=${code}):`,
        genErr
      );
      // [정직한 실패 원칙] 200으로 감추지 않고 422로 명확히 실패를 알린다.
      // (assetId는 실패 이력으로 남아 있으므로 관리자가 목록에서 실패 사유를 확인 가능)
      return jsonError(message, 422);
    }
  } catch (e) {
    console.error("[POST /api/admin/bokju-coupons/design-assets] 실패:", e);
    return jsonError("배경 생성 요청 처리 중 오류가 발생했습니다.", 500);
  }
}
