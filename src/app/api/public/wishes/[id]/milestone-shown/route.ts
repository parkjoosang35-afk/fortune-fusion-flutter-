// 소원성 최종단계(레벨4) 특별 전체화면 연출을 "이미 봤음"으로 표시하는 API.
// isMilestoneShown 플래그로 1회만 노출되도록 보장(연출을 매번 재생하면 화려함이
// 오히려 피로감을 줄 수 있어 03단계 UX 원칙에 따라 1회 제한).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseWishDbId(idParam: string): number | null {
  const match = /^wp_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const wishId = parseWishDbId(id);
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "소원 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  try {
    await prisma.wish.update({
      where: { id: wishId },
      data: { isMilestoneShown: true },
    });
    return NextResponse.json({ success: true }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/wishes/[id]/milestone-shown] 실패:", e);
    return NextResponse.json(
      { success: false, error: "처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
