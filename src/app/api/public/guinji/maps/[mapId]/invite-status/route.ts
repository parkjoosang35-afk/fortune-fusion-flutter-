// 귀인지도 초대 링크 현재 상태 조회 API — 소유자 전용, 관리 화면 표시용.
// [귀인지도_초대링크_재발급_개발지시서_v1.1 §05 #4] `GET /guinji/maps/{mapId}/invite-status`.
//
// [joinedMemberCount 주의] 이름과 달리 "링크 유입 횟수"가 아니라 "실제로
// 지도에 합류한 활성 멤버 수"다(지시서 §05 명세 그대로: "링크 유입 횟수가
// 아니라 '합류한 멤버 수'"). 소프트 삭제(status='removed')된 멤버는
// members/[memberId] DELETE API와 동일한 원칙으로 제외한다.
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

export async function GET(
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
    const map = await prisma.guinjiMap.findUnique({
      where: { id: mapDbId },
      include: {
        members: { where: { status: "active" }, select: { id: true } },
      },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (map.ownerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인 지도만 조회할 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          token: map.token,
          inviteStatus: map.inviteStatus,
          tokenIssuedAt: map.tokenIssuedAt.toISOString(),
          joinedMemberCount: map.members.length,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/guinji/maps/[mapId]/invite-status] 실패:", e);
    return NextResponse.json(
      { success: false, error: "상태 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
