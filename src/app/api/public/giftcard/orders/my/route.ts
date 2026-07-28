// 공개(비인증) 내 상품권 발급 내역 API — GiftcardRepository.getMyOrders() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function pickEmoji(brand: string, name: string): string {
  const text = `${brand} ${name}`;
  if (text.includes("스타벅스") || text.includes("커피") || text.includes("카페")) return "☕";
  if (text.includes("치킨") || text.includes("BBQ")) return "🍗";
  if (text.includes("배스킨") || text.includes("아이스크림")) return "🍨";
  if (text.includes("문화상품권") || text.includes("영화")) return "🎟️";
  if (text.includes("GS25") || text.includes("CU") || text.includes("편의점")) return "🏪";
  if (text.includes("피자")) return "🍕";
  if (text.includes("햄버거") || text.includes("버거")) return "🍔";
  return "🎁";
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const issues = await prisma.giftcardIssue.findMany({
      where: { userId, deletedAt: null },
      include: { product: true, usage: true },
      orderBy: { createdAt: "desc" },
    });

    const data = issues.map((issue) => ({
      id: `gci_${issue.id}`,
      product: {
        id: `gc_${issue.product.id}`,
        name: issue.product.name,
        brand: issue.product.brand,
        requiredPoint: issue.product.requiredPoint,
        stockCount: issue.product.stockCount,
        validDays: issue.product.validDays,
        imageEmoji: pickEmoji(issue.product.brand, issue.product.name),
      },
      pointSpent: issue.pointSpent,
      status: issue.status,
      issuedCode: issue.issuedCode,
      issuedAt: issue.issuedAt?.toISOString() ?? null,
      expiresAt: issue.expiresAt?.toISOString() ?? null,
      usedAt: issue.usage?.usedAt.toISOString() ?? null,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/giftcard/orders/my] 실패:", e);
    return NextResponse.json(
      { success: false, error: "발급 내역을 불러오지 못했습니다." },
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
