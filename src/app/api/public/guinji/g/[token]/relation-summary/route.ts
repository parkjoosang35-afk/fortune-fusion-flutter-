// 관계 지도 집계 API — 웹 랜딩페이지(`/g/[token]`)의 "관계 지도" 네트워크
// 그래프 렌더링용. 로그인 없이 호출 가능하다(카톡에서 들어온 방문자 대상).
//
// [비식별 원칙 — 절대] 이 라우트는 멤버 개개인의 이름·생년월일·관계유형을
// 절대 반환하지 않는다. 오직 "관계유형별 인원수(집계값)"만 내려준다 —
// 지도 소유자가 초대한 지인들의 신상이 로그인 없는 외부인에게 노출되는
// 것을 원천 차단한다(D2/기존 og/_shared.ts findGuinjiMapOwnerNickname과
// 동일한 화이트리스트 경계).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { GUINJI_RELATION_TYPE_ORDER } from "@/lib/guinji-relation-judger";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token } = await params;

  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      include: {
        // [2026-10-12 전수검수 수정] join/route.ts 집계와 동일하게 삭제(소프트)된
        // 멤버의 관계는 제외한다. 없으면 소유자가 멤버를 지워도 공개 링크의
        // "N명 참여" 숫자와 라벨 분포가 줄지 않았다(E2E로 재현됨).
        relationships: {
          where: { member: { status: "active" } },
          select: { relationType: true },
        },
      },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    // [귀인지도 초대링크 재발급 v1.1 — 2026 Phase] 만료 판정 제거(isGuinjiInviteExpired는
    // 삭제하지 않고 미사용으로 보존). 중단(revoked)된 링크도 집계는 그대로 노출한다
    // (E1 변형 화면이 "지금까지 N명이 참여했어요" 카피를 쓸 때 사용할 수 있도록).


    const counts: Record<string, number> = {};
    for (const t of GUINJI_RELATION_TYPE_ORDER) counts[t] = 0;
    for (const r of map.relationships) {
      if (counts[r.relationType] != null) counts[r.relationType] += 1;
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          total: map.relationships.length,
          counts,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/guinji/g/[token]/relation-summary] 실패:", e);
    return NextResponse.json(
      { success: false, error: "관계 지도 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: { ...CORS_HEADERS, "Access-Control-Allow-Methods": "GET, OPTIONS" },
  });
}
