// 공개(비인증) 대표 소원 지정 API — Flutter WishRoomRepository.setRepresentative() 대응.
//
// [설계] 소원방의 "대표 소원" 개념은 서버가 단일 진실 원천으로 관리한다
// (§ "클라이언트에서 서버 상태 임의 변경 금지" — Flutter가 로컬에서 isRepresentative
// 플래그를 직접 뒤집지 않고, 항상 이 API를 통해 서버가 확정한 결과를 반영한다).
// 대표는 항상 최대 1개이므로, 지정 시 같은 유저의 기존 대표는 자동으로 해제한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  serializeWish,
  parseWishRoomWishId,
  CORS_HEADERS,
  corsOptionsResponse,
} from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface RepresentBody {
  userId?: number;
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const wishId = parseWishRoomWishId(id);
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: RepresentBody;
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 회원간 데이터 격리 — userId로 항상 필터링.
      const target = await tx.wishRoomWish.findFirst({ where: { id: wishId, userId, status: "active" } });
      if (!target) throw new Error("WISH_NOT_FOUND");

      if (!target.isRepresentative) {
        // 기존 대표 해제 -> 대상 소원을 대표로 승격(단일 대표 규칙).
        await tx.wishRoomWish.updateMany({
          where: { userId, status: "active", isRepresentative: true },
          data: { isRepresentative: false },
        });
        await tx.wishRoomWish.update({ where: { id: target.id }, data: { isRepresentative: true } });
      }

      await tx.wishRoomProfile.updateMany({
        where: { userId },
        data: { representativeWishId: target.id },
      });

      const updated = await tx.wishRoomWish.findUniqueOrThrow({ where: { id: target.id } });
      return updated;
    });

    return NextResponse.json(
      { success: true, data: { wish: serializeWish(result) } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WISH_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/wish-room/wishes/[id]/represent] 실패:", e);
    return NextResponse.json(
      { success: false, error: "대표 소원 지정에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
