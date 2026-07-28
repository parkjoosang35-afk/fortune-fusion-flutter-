// 공개(비인증) 상품권 상품 목록 API — GiftcardRepository.getProducts() 대응.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// 04A image_file_id 대응 - 이모지로 간소화 표현(brand 키워드 매칭, 03§9.2 과설계 방지)
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

export async function GET() {
  try {
    const products = await prisma.giftcardProduct.findMany({
      where: { isActive: true, status: "active", deletedAt: null },
      orderBy: { requiredPoint: "asc" },
    });
    const data = products.map((p) => ({
      id: `gc_${p.id}`,
      name: p.name,
      brand: p.brand,
      requiredPoint: p.requiredPoint,
      stockCount: p.stockCount,
      validDays: p.validDays,
      imageEmoji: pickEmoji(p.brand, p.name),
    }));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/giftcard/products] 실패:", e);
    return NextResponse.json(
      { success: false, error: "상품 목록을 불러오지 못했습니다." },
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
