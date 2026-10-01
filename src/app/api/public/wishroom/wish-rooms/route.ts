// 소원방 생성 — Flutter WrRepository.createRoom() 대응.
// [원본] app/api.js 라우트 1 · POST /wish-rooms.
// 진행 중인(ARCHIVED가 아닌) 소원방이 이미 있으면 409 ROOM_EXISTS.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { WR, WishRoomError, buildRoomView, checkSealDate, filterText, serializeEquip, type EquipShape } from "@/lib/wishroom-engine";
import { getOrCreateUserState, requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../_shared";

export const dynamic = "force-dynamic";

const DEFAULT_EQUIP: EquipShape = { CANDLE: "c_basic", FLOWER: "f_none", BACKGROUND: "b_night", SPECIAL: "s_none", DECORATION: [], SEAL: [], THEME: [] };

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: {
    text?: string;
    char?: string;
    sealUntil?: string | null;
    visibility?: "PUBLIC" | "LINK" | "PRIVATE";
    theme?: string;
    wishColor?: string;
    paper?: string;
    force?: boolean;
    draft?: boolean;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const existing = await tx.wishRoom.findFirst({
        where: { userId: auth.userId, status: { not: "ARCHIVED" }, deletedAt: null },
      });
      if (existing) {
        throw new WishRoomError(409, "ROOM_EXISTS", "진행 중인 소원방이 있어요");
      }

      const text = (body.text ?? "").trim();
      if (text.length > 100) {
        throw new WishRoomError(400, "TOO_LONG", "100자 이내로 적어주세요");
      }
      filterText(text, !!body.force); // 비어있음/욕설/개인정보 의심 시 WishRoomError throw

      const isDraft = !!body.draft;
      const sealUntil = isDraft ? null : checkSealDate(body.sealUntil ?? undefined);

      const state = await getOrCreateUserState(tx, auth.userId);
      const theme = WR.THEMES.some((t) => t.id === body.theme) ? (body.theme as string) : "free";

      const room = await tx.wishRoom.create({
        data: {
          userId: auth.userId,
          charCode: body.char || state.repCharCode,
          text,
          theme,
          wishColor: body.wishColor || "hope",
          paper: body.paper || "hanji",
          visibility: body.visibility || "PUBLIC",
          status: isDraft ? "DRAFT" : "ACTIVE",
          equipJson: serializeEquip(DEFAULT_EQUIP),
          sealUntil,
          capsule: sealUntil ? "LOCKED" : null,
          points: 0,
          level: 1,
        },
        include: { user: { select: { nickname: true } } },
      });

      return buildRoomView(tx, room, auth.userId);
    });

    return NextResponse.json({ success: true, data: view }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
