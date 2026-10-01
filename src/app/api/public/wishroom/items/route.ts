// 아이템 카탈로그 — Flutter WrRepository.items() 대응.
// [원본] app/api.js 13 · GET /items.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedItemIds, isAlwaysOwnedItem, WR } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const owned = await getOwnedItemIds(tx, auth.userId);
      return WR.ITEMS.map((i) => ({ ...i, owned: isAlwaysOwnedItem(i) || owned.has(i.id) }));
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
