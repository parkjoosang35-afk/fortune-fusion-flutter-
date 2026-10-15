// [복주머니 마케팅 쿠폰] GET/POST /api/admin/bokju-coupons/partners
// 제휴업체 목록 조회 + 신규 등록.
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { registerPartner } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const partners = await prisma.bokjuPartner.findMany({
      orderBy: { createdAt: "desc" },
      include: { accounts: { select: { id: true, loginId: true, role: true, status: true, lastLoginAt: true } } },
    });
    return jsonOk({
      partners: partners.map((p) => ({
        id: p.id,
        name: p.name,
        managerName: p.managerName,
        managerContact: p.managerContact,
        status: p.status,
        createdAt: p.createdAt.toISOString(),
        accounts: p.accounts.map((a) => ({
          id: a.id,
          loginId: a.loginId,
          role: a.role,
          status: a.status,
          lastLoginAt: a.lastLoginAt?.toISOString() ?? null,
        })),
      })),
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/partners] 실패:", e);
    return jsonError("업체 목록 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function POST(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const name = typeof body.name === "string" ? body.name.trim() : "";
    if (!name) return jsonError("name은 필수입니다.");

    const result = await registerPartner({
      name,
      managerName: typeof body.managerName === "string" ? body.managerName : undefined,
      managerContact: typeof body.managerContact === "string" ? body.managerContact : undefined,
    });
    return jsonOk(result, 201);
  } catch (e) {
    console.error("[POST /api/admin/bokju-coupons/partners] 실패:", e);
    return jsonError("업체 등록 중 오류가 발생했습니다.", 500);
  }
}
