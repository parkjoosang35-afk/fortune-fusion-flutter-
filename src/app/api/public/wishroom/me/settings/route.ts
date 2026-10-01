// 소원방 설정 변경 — Flutter WrRepository.settings() 대응.
// [원본] app/api.js 보조 · PATCH /me/settings { skipIntro? } (Object.assign 포팅).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getOrCreateUserState, buildMeView } from "../../_shared";

export const dynamic = "force-dynamic";

export async function PATCH(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { skipIntro?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      await getOrCreateUserState(tx, auth.userId);
      if (typeof body.skipIntro === "boolean") {
        await tx.wishRoomUserState.update({ where: { userId: auth.userId }, data: { skipIntro: body.skipIntro } });
      }
      return buildMeView(tx, auth.userId);
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
