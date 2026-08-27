// 내 귀인지도 조회 API — Flutter GuinjiRepository.fetchMyMap() 대응.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-2] `GET /guinji/maps/me`.
//
// [응답] { map, members, relationships } — S4(빈 지도)/S5(지도 메인) 화면이
// 이 하나의 응답으로 분기한다(members.length === 0 → 빈 지도).
// [M4 확정안] birthTime은 이 응답에서 소유자 본인 조회이므로 그대로
// 노출한다(소유자에게만 공유 원칙 — 요청자가 곧 소유자이기 때문).
// 반대로 S9(지인 참여) 쪽 GET /guinji/g/{token}에서는 노출하지 않는다
// (별도 라우트, 이번 Phase 범위 밖).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, CORS_HEADERS_WITH_AUTH, requireUser, toGuinjiMapPublicId, toGuinjiMemberPublicId, unauthorizedResponse } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { ownerId: auth.userId },
      include: {
        members: {
          where: { status: "active" },
          orderBy: { createdAt: "asc" },
        },
        relationships: true,
      },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return NextResponse.json(
        { success: true, data: null },
        { headers: CORS_HEADERS }
      );
    }

    const relationshipByMemberId = new Map(map.relationships.map((r) => [r.memberId, r]));

    return NextResponse.json(
      {
        success: true,
        data: {
          map: {
            mapId: toGuinjiMapPublicId(map.id),
            name: map.name,
            token: map.token,
            createdAt: map.createdAt.toISOString(),
          },
          members: map.members.map((m) => ({
            memberId: toGuinjiMemberPublicId(m.id),
            name: m.name,
            solarLunar: m.solarLunar,
            birthDate: m.birthDate,
            birthTime: m.birthTime,
            birthTimeMissing: m.birthTimeMissing,
            joined: m.joinedUserId != null,
          })),
          relationships: map.members
            .map((m) => relationshipByMemberId.get(m.id))
            .filter((r): r is NonNullable<typeof r> => r != null)
            .map((r) => ({
              memberId: toGuinjiMemberPublicId(r.memberId),
              relationType: r.relationType,
              chemistryScore: r.chemistryScore,
              ohaengEvidence: JSON.parse(r.ohaengEvidence),
            })),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/guinji/maps/me] 실패:", e);
    return NextResponse.json(
      { success: false, error: "지도 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
