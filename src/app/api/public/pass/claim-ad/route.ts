// 광고 프리패스 신규 지급은 횟수제로만 허용한다. 기존 시간제 보유 행은 유지한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { claimCoupangDailyPass, OpenPassServiceError } from "@/lib/open-pass-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { policyId?: number };
  try { body = await request.json(); }
  catch { return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS }); }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;
  try {
    const policy = await prisma.passPolicy.findFirst({
      where: { ...(body.policyId ? { id: Number(body.policyId) } : {}), passType: "ad", isActive: true, deletedAt: null },
      orderBy: { id: "asc" },
    });
    if (!policy) throw new OpenPassServiceError("POLICY_NOT_FOUND", "활성화된 광고 프리패스 정책이 없습니다.");
    if (policy.grantCount == null) throw new OpenPassServiceError("COUNT_POLICY_REQUIRED", "광고 프리패스 지급 횟수를 관리자에서 설정해주세요.");
    // 기존 횟수제 광고 정책의 하루 한 번 획득 계약은 그대로 유지한다.
    const result = await claimCoupangDailyPass({ userId, policyId: policy.id });
    if (!result.claimed) return NextResponse.json({ success: false, error: "오늘의 프리패스를 이미 받으셨어요.", code: "ALREADY_CLAIMED_TODAY" }, { status: 409, headers: CORS_HEADERS });
    const pass = result.userPass!;
    return NextResponse.json({ success: true, data: {
      userPassId: pass.id, policyId: policy.id, policyName: policy.name,
      expiresAt: pass.expiresAt.toISOString(), idempotent: false,
      grantedCount: pass.grantedCount, remainingCount: pass.remainingCount,
    } }, { headers: CORS_HEADERS });
  } catch (e) {
    if (e instanceof OpenPassServiceError) return NextResponse.json({ success: false, error: e.message, code: e.code }, { status: e.code === "POLICY_NOT_FOUND" ? 404 : 409, headers: CORS_HEADERS });
    console.error("[POST /api/public/pass/claim-ad] 실패:", e);
    return NextResponse.json({ success: false, error: "광고 프리패스 발급 중 오류가 발생했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: {
    "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  } });
}
