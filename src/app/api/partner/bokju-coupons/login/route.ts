// [복주머니 마케팅 쿠폰] POST /api/partner/bokju-coupons/login
// 제휴업체 담당자 로그인(loginId/password) → HttpOnly Cookie 세션 발급.
// 관리자가 /admin/bokju-coupons/partners/:id/accounts 로 미리 발급한 계정만 사용 가능.
import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { createPartnerSession } from "@/lib/partner-session";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const loginId = typeof body.loginId === "string" ? body.loginId.trim() : "";
    const password = typeof body.password === "string" ? body.password : "";
    if (!loginId || !password) {
      return NextResponse.json(
        { success: false, error: "loginId/password는 필수입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    const account = await prisma.bokjuPartnerAccount.findUnique({ where: { loginId } });
    if (!account || account.status !== "ACTIVE") {
      return NextResponse.json(
        { success: false, error: "아이디 또는 비밀번호가 올바르지 않습니다." },
        { status: 401, headers: CORS_HEADERS }
      );
    }

    const ok = await bcrypt.compare(password, account.passwordHash);
    if (!ok) {
      return NextResponse.json(
        { success: false, error: "아이디 또는 비밀번호가 올바르지 않습니다." },
        { status: 401, headers: CORS_HEADERS }
      );
    }

    await createPartnerSession({
      partnerId: account.partnerId,
      accountId: account.id,
      loginId: account.loginId,
      role: account.role === "PARTNER_STAFF" ? "PARTNER_STAFF" : "PARTNER_ADMIN",
    });

    await prisma.bokjuPartnerAccount.update({
      where: { id: account.id },
      data: { lastLoginAt: new Date() },
    });

    return NextResponse.json(
      { success: true, data: { partnerId: account.partnerId, accountId: account.id, role: account.role } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/partner/bokju-coupons/login] 실패:", e);
    return NextResponse.json(
      { success: false, error: "로그인 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}
