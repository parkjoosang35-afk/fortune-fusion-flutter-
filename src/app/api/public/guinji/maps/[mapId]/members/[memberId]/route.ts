// 귀인지도 멤버 삭제(소프트 삭제) API — Flutter/웹 공용.
// [2026-11 신규] 사용자가 격노하며 지적한 문제: "상대방이 생년월일을 잘못
// 넣거나 이름을 잘못 넣어서 귀인지도가 잘못 나올 때 삭제하는 게 없다"
// → 지도 소유자가 잘못 입력된 멤버를 삭제할 수 있어야 한다. 사용자는
// 명시적으로 "웹에서도 소유자가 삭제 가능"해야 한다고 요구했다(앱뿐만
// 아니라). 이 API는 Flutter 앱(Bearer JWT, SharedPreferences 저장 토큰)과
// 웹 관리 페이지(/my/guinji, localStorage 저장 토큰) 양쪽이 동일하게
// `requireUser()` Bearer 인증으로 호출하는 단일 엔드포인트다.
//
// [완전 삭제가 아니라 소프트 삭제] GuinjiMapMember.status를 "removed"로
// 바꾸고 deletedAt을 채운다 — 스키마에 이미 "M5 탈퇴·철회" 주석과 함께
// 설계되어 있던 필드를 그대로 사용한다(하드 삭제는 하지 않는다 — 실수로
// 지운 경우 복구 가능성을 남기고, 관련 GuinjiRelationship(1:1, unique
// memberId)의 참조 무결성도 그대로 유지된다).
//
// [소유자만 삭제 가능] map.ownerId !== auth.userId면 403. 멤버 본인이나
// 타인이 자기/남의 지도 멤버를 지울 수 없다 — "지도 소유자"만의 권한이다.
//
// [집계 반영] join/route.ts와 g/[token]/page.tsx의 관계 카운트 쿼리는
// `relationships: { where: { member: { status: "active" } } }`로 필터링
// 하도록 이미 수정되어 있으므로, 이 API가 status를 "removed"로 바꾸는
// 즉시 초대 랜딩페이지·관계지도 그래프에서도 자동으로 제외된다(별도
// 캐시 무효화 불필요 — 매 요청 시 DB에서 재조회).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGuinjiMapDbId,
  parseGuinjiMemberDbId,
  requireUser,
  unauthorizedResponse,
} from "../../../../_shared";

export const dynamic = "force-dynamic";

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ mapId: string; memberId: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { mapId: mapIdParam, memberId: memberIdParam } = await params;
  const mapDbId = parseGuinjiMapDbId(mapIdParam);
  const memberDbId = parseGuinjiMemberDbId(memberIdParam);
  if (mapDbId === null || memberDbId === null) {
    return NextResponse.json(
      { success: false, error: "mapId/memberId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const map = await prisma.guinjiMap.findUnique({ where: { id: mapDbId } });
    if (!map || map.deletedAt != null || map.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    // [소유자만] 본인 지도가 아니면 403 — 다른 사람의 지도 멤버를
    // 지도 자체를 알아도 지울 수 없어야 한다.
    if (map.ownerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인 지도의 멤버만 삭제할 수 있어요." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    const member = await prisma.guinjiMapMember.findUnique({ where: { id: memberDbId } });
    if (!member || member.mapId !== map.id) {
      return NextResponse.json(
        { success: false, error: "해당 멤버를 찾을 수 없어요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (member.status === "removed") {
      // 이미 삭제된 멤버 — 멱등하게 성공으로 응답(에러 아님, 재시도/중복
      // 클릭에 안전).
      return NextResponse.json({ success: true, data: { alreadyRemoved: true } }, { headers: CORS_HEADERS });
    }

    await prisma.guinjiMapMember.update({
      where: { id: memberDbId },
      data: { status: "removed", deletedAt: new Date() },
    });

    return NextResponse.json({ success: true, data: { alreadyRemoved: false } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[DELETE /api/public/guinji/maps/[mapId]/members/[memberId]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "삭제 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
