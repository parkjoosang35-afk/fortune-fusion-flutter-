// 공개(비인증) 구독 플랜 목록 API — SubscriptionRepository.getPlans() 대응.
// benefits는 04A JSON 배열 문자열 컬럼(예: "[\"일일 운세 무제한\",\"광고 제거\"]")을
// 그대로 List<String>으로 매핑 가능(설계 충돌 없음, 조사 단계에서 확인됨).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseBenefits(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

export async function GET() {
  try {
    const plans = await prisma.subscriptionPlan.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: { price: "asc" },
    });
    const data = plans.map((p) => ({
      id: `plan_${p.id}`,
      name: p.name,
      price: p.price,
      period: p.period,
      benefits: parseBenefits(p.benefits),
      isActive: p.isActive,
    }));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/subscription/plans] 실패:", e);
    return NextResponse.json(
      { success: false, error: "구독 플랜을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
