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
import { isGuinjiInviteExpired } from "@/app/api/public/guinji/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const RELATION_TYPE_ORDER = ["guin", "oreunpal", "inyeon", "salrim", "horang"] as const;

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token } = await params;

  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      include: {
        relationships: {
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
    if (isGuinjiInviteExpired(map.createdAt)) {
      return NextResponse.json(
        { success: false, error: "초대 링크가 만료되었어요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const counts: Record<string, number> = {};
    for (const t of RELATION_TYPE_ORDER) counts[t] = 0;
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
