// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/partners/:id/accounts
// 업체 로그인 계정 발급. 관리자가 초기 비밀번호를 직접 설정해 업체 담당자에게
// 전달하는 방식(이번 단계에서는 이메일 발송 등 초대 플로우는 범위 밖, loginId/password
// 그대로 안내). passwordHash는 bcrypt(기존 user-auth.ts의 hashPassword와 동일 방식).
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const partnerId = Number(id);
  if (!Number.isInteger(partnerId)) return jsonError("partnerId가 올바르지 않습니다.");

  try {
    const body = await request.json();
    const loginId = typeof body.loginId === "string" ? body.loginId.trim() : "";
    const password = typeof body.password === "string" ? body.password : "";
    const role = body.role === "PARTNER_STAFF" ? "PARTNER_STAFF" : "PARTNER_ADMIN";
    if (!loginId) return jsonError("loginId는 필수입니다.");
    if (password.length < 8) return jsonError("password는 8자 이상이어야 합니다.");

    const partner = await prisma.bokjuPartner.findUnique({ where: { id: partnerId } });
    if (!partner) return jsonError("업체를 찾을 수 없습니다.", 404);

    const passwordHash = await bcrypt.hash(password, 10);
    const account = await prisma.bokjuPartnerAccount.create({
      data: { partnerId, loginId, passwordHash, role },
    });
    return jsonOk({ accountId: account.id, loginId: account.loginId, role: account.role }, 201);
  } catch (e) {
    if (typeof e === "object" && e !== null && (e as { code?: string }).code === "P2002") {
      return jsonError("이미 사용 중인 loginId입니다.", 409);
    }
    console.error("[POST /api/admin/bokju-coupons/partners/:id/accounts] 실패:", e);
    return jsonError("계정 발급 중 오류가 발생했습니다.", 500);
  }
}
