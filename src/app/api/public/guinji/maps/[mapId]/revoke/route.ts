// 귀인지도 초대 링크 중단 API — 소유자 전용.
// [귀인지도_초대링크_재발급_개발지시서_v1.1 §05 #2] `POST /guinji/maps/{mapId}/revoke`.
//
// [핵심 동작] token 값은 그대로 두고 inviteStatus만 'revoked'로 바꾼다
// (재발급과 달리 token을 바꾸지 않는 이유 — v1.1 §04 "핵심 구분": 중단은
// 옛 링크가 계속 조회되어야 "OOO님이 이 링크를 닫았어요" 같은 맥락 있는
// REVOKED 화면(E1 변형, page.tsx 참고)을 보여줄 수 있다).
//
// [소유권 재검증] reissue와 동일 원칙 — WHERE절에 ownerId 포함.
//
// [멱등성] 이미 revoked 상태인 지도를 다시 호출해도 에러 없이 현재 상태를
// 그대로 반환한다(재시도/중복 클릭 안전 — deleteMember API와 동일 패턴).
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
        { success: false, error: "본인 지도만 중단할 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // [멱등] 이미 중단 상태면 그대로 반환.
    if (existing.inviteStatus === "revoked") {
      return NextResponse.json(
        {
          success: true,
          data: {
            token: existing.token,
            inviteStatus: existing.inviteStatus,
            revokedAt: existing.revokedAt?.toISOString() ?? null,
          },
        },
        { headers: CORS_HEADERS }
      );
    }

    const updated = await prisma.guinjiMap.update({
      where: { id: mapDbId, ownerId: auth.userId },
      data: { inviteStatus: "revoked", revokedAt: new Date() },
      select: { token: true, inviteStatus: true, revokedAt: true },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          token: updated.token,
          inviteStatus: updated.inviteStatus,
          revokedAt: updated.revokedAt?.toISOString() ?? null,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/guinji/maps/[mapId]/revoke] 실패:", e);
    return NextResponse.json(
      { success: false, error: "중단 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
