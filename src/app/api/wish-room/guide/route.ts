// 공개(비인증) 소원방 이용방법/가이드 슬라이드 조회 API.
// 관리자 CMS(이용방법관리)에서 편집한 순서/문구/이미지/노출여부를 그대로 반영한다
// (§ "관리자 설정값 하드코딩 금지" — 슬라이드 텍스트도 클라이언트에 박아두지 않음).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, corsOptionsResponse } from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const slides = await prisma.wishRoomGuideSlide.findMany({
      where: { isActive: true },
      orderBy: { displayOrder: "asc" },
    });
    return NextResponse.json(
      {
        success: true,
        data: {
          slides: slides.map((s) => ({
            id: s.id,
            title: s.title,
            body: s.body,
            imageUrl: s.imageUrl,
            displayOrder: s.displayOrder,
          })),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/wish-room/guide] 실패:", e);
    return NextResponse.json({ success: false, error: "가이드 조회에 실패했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("GET");
}
