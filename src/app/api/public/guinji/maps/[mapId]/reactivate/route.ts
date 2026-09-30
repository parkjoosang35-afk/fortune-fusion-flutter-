// 귀인지도 초대 링크 중단 해제 API — 소유자 전용.
// [귀인지도_초대링크_재발급_개발지시서_v1.1 §05 #3] `POST /guinji/maps/{mapId}/reactivate`.
//
// [핵심 동작] inviteStatus를 'active'로 되돌리고 revokedAt을 null로
// 리셋한다. token 값은 건드리지 않는다(revoke와 대칭 — "중단"의 반대는
// "토큰 유지한 채 다시 열기"이지 재발급이 아니다. 새 토큰이 필요하면
// 별도로 reissue를 호출해야 한다).
//
// [소유권 재검증 / 멱등성] revoke API와 동일 원칙.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGuinjiMapDbId,
  requireUser,
  unauthorizedResponse,
} from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ mapId: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { mapId: mapIdParam } = await params;
  const mapDbId = parseGuinjiMapDbId(mapIdParam);
  if (mapDbId === null) {
    return NextResponse.json(
      { success: false, error: "mapId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const existing = await prisma.guinjiMap.findUnique({ where: { id: mapDbId } });
    if (!existing || existing.deletedAt != null || existing.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (existing.ownerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인 지도만 중단 해제할 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // [멱등] 이미 active 상태면 그대로 반환.
    if (existing.inviteStatus === "active") {
      return NextResponse.json(
        {
          success: true,
          data: { token: existing.token, inviteStatus: existing.inviteStatus },
        },
        { headers: CORS_HEADERS }
      );
    }

    const updated = await prisma.guinjiMap.update({
      where: { id: mapDbId, ownerId: auth.userId },
      data: { inviteStatus: "active", revokedAt: null },
      select: { token: true, inviteStatus: true },
    });

    return NextResponse.json(
      {
        success: true,
        data: { token: updated.token, inviteStatus: updated.inviteStatus },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/guinji/maps/[mapId]/reactivate] 실패:", e);
    return NextResponse.json(
      { success: false, error: "중단 해제 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
