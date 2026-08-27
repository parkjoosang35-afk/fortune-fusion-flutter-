// 내 귀인지도 조회 API — Flutter GuinjiRepository.fetchMyMap() 대응.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-2] `GET /guinji/maps/me`.
//
// [응답] { map, members, relationships } — S4(빈 지도)/S5(지도 메인) 화면이
// 이 하나의 응답으로 분기한다(members.length === 0 → 빈 지도).
// [M4 확정안] birthTime은 이 응답에서 소유자 본인 조회이므로 그대로
// 노출한다(소유자에게만 공유 원칙 — 요청자가 곧 소유자이기 때문).
// 반대로 S9(지인 참여) 쪽 GET /guinji/g/{token}에서는 노출하지 않는다
// (별도 라우트, 이번 Phase 범위 밖).
//
// [§11 "매일 첫 /guinji 방문 → 출석 적립"] 지도가 있는 사용자가 오늘(KST) 처음
// 이 API를 호출하면 PointPolicy('guinji_daily_visit', 3P/1일1회)를 지급한다.
// fortune/daily route.ts의 "첫 열람 보너스" 패턴과 동일하게 checkPolicyEligibility
// (scope:'daily')로 중복 지급을 방지하고, earnLuckPouch()로 일일 총 상한 클리핑까지
// 함께 적용한다(§ 단일 소스 원칙 — 이 파일에서 직접 지급 로직을 재구현하지 않음).
// 지도가 없는 사용자(맵 미생성)는 방문 보상 대상이 아니다(온보딩 전이므로).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch, checkPolicyEligibility } from "@/lib/luck-pouch-engine";
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

    // [§11 매일 첫 방문 보상] 조회 자체는 GET(부수효과 없어야 정상)이지만, 기존
    // fortune/daily 패턴과 동일하게 "오늘 첫 조회"를 방문으로 간주해 트랜잭션으로
    // 지급한다(멱등: PointHistory에 오늘자 guinji_daily_visit 기록이 있으면 스킵).
    await prisma.$transaction(async (tx) => {
      const eligibility = await checkPolicyEligibility(tx, auth.userId, "guinji_daily_visit", {
        scope: "daily",
      });
      if (!eligibility.eligible) return;
      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "guinji_daily_visit" } });
      const amount = policy?.isActive === false ? 0 : policy?.amount ?? 3;
      if (amount <= 0) return;
      await earnLuckPouch(tx, {
        userId: auth.userId,
        amount,
        sourceType: "guinji_daily_visit",
        memo: "귀인지도 오늘 첫 방문",
      });
    });

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
