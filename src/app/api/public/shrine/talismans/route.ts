// 신당(THE SHRINE) v3 — 부적 마스터 카탈로그 조회(03 메인 · 04 직접 고르기 ·
// 06 추천받기가 공용으로 사용). 인증 불필요(비로그인 탐색 자유 원칙, 결과보기
// 패턴과 동일 — 05에서 "부탁하기"를 누를 때만 로그인/결제가 필요하다).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS } from "../_shared";

export const dynamic = "force-dynamic";

function toTalismanDto(t: {
  slug: string;
  category: string;
  hanja: string;
  name: string;
  aim: string;
  sub: string | null;
  meaning: string;
  effects: unknown;
  recommendFor: unknown;
  validityTerm: string;
  usage: unknown;
  goesWith: unknown;
  imagePath: string;
  thumbPath: string | null;
}) {
  return {
    id: t.slug,
    category: t.category,
    hanja: t.hanja,
    name: t.name,
    aim: t.aim,
    sub: t.sub,
    meaning: t.meaning,
    effects: t.effects,
    recommendFor: t.recommendFor,
    validityTerm: t.validityTerm,
    usage: t.usage,
    goesWith: t.goesWith,
    imagePath: t.imagePath,
    thumbPath: t.thumbPath,
  };
}

/** GET /api/public/shrine/talismans — 67종 전체(또는 ?category=로 필터) 목록. */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const category = searchParams.get("category");

  try {
    const items = await prisma.talismanItem.findMany({
      where: { isActive: true, ...(category ? { category } : {}) },
      orderBy: { sortOrder: "asc" },
    });
    return NextResponse.json(
      { success: true, data: items.map(toTalismanDto) },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/shrine/talismans] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 목록을 불러오지 못했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
