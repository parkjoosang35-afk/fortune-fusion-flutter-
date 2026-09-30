// 귀인지도 초대 링크 재발급 API — 소유자 전용.
// [귀인지도_초대링크_재발급_개발지시서_v1.1 §05 #1] `POST /guinji/maps/{mapId}/reissue`.
//
// [핵심 동작] token 값 자체를 새로 생성해 UPDATE한다(v1.0의 "토큰 UPDATE
// 절대 금지" 규칙은 1:N 구조를 전제로 한 것이라 1:1 구조(@@unique([ownerId]))
// 인 이 스키마에는 적용되지 않는다 — v1.1 §04가 이 규칙을 명시적으로
// 철회함). 재발급과 동시에 inviteStatus를 'active'로 리셋하고
// tokenIssuedAt을 현재 시각으로 갱신, revokedAt은 null로 되돌린다
// (중단 중이던 링크를 재발급하면 곧바로 살아나는 것이 자연스러운 동작).
//
// [옛 토큰의 운명] token 컬럼 값 자체가 바뀌므로, 옛 토큰으로 들어오는
// 방문자는 `/g/{oldToken}` 조회 시 findUnique가 아무것도 찾지 못해
// INVALID 화면(§07-3, E5)으로 떨어진다 — 맥락 있는 안내는 Phase 2(별칭
// 테이블) 과제이며 이번 축소판 범위 밖이다. 그래서 이 API 응답에
// "이전 링크로 들어오던 사람은 더 이상 들어올 수 없어요"라는 warning을
// 함께 실어, 주인 관리 화면이 재발급 직전 확인 다이얼로그에 활용할 수
// 있게 한다.
//
// [소유권 재검증 — 절대] 클라이언트가 보낸 mapId만 신뢰하지 않고, WHERE절에
// ownerId까지 포함해 서버가 재검증한다(다른 지도의 mapId를 넣어도 갱신되지
// 않고 404).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  generateGuinjiToken,
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
    // [소유권 재검증] update의 where에 id+ownerId를 함께 넣으면, 다른
    // 사람의 mapId를 넣었을 때 Prisma가 "레코드를 찾을 수 없음"(P2025)
    // 에러를 던진다 — 이를 잡아 404/403으로 변환한다.
    const existing = await prisma.guinjiMap.findUnique({ where: { id: mapDbId } });
    if (!existing || existing.deletedAt != null || existing.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (existing.ownerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인 지도만 재발급할 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // 토큰 충돌(사실상 발생하지 않지만 unique 제약이 있으므로 방어적 재시도).
    let updated: { token: string; inviteStatus: string; tokenIssuedAt: Date } | null = null;
    for (let attempt = 0; attempt < 3 && !updated; attempt++) {
      const newToken = generateGuinjiToken();
      try {
        updated = await prisma.guinjiMap.update({
          where: { id: mapDbId, ownerId: auth.userId },
          data: {
            token: newToken,
            inviteStatus: "active",
            tokenIssuedAt: new Date(),
            revokedAt: null,
          },
          select: { token: true, inviteStatus: true, tokenIssuedAt: true },
        });
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code !== "P2002") throw e;
        // token 충돌 — 다음 루프에서 새 토큰으로 재시도.
      }
    }

    if (!updated) {
      return NextResponse.json(
        { success: false, error: "토큰 재발급에 실패했습니다. 다시 시도해 주세요." },
        { status: 500, headers: CORS_HEADERS }
      );
    }

    const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";

    return NextResponse.json(
      {
        success: true,
        data: {
          token: updated.token,
          url: `${baseUrl}/g/${updated.token}`,
          inviteStatus: updated.inviteStatus,
          tokenIssuedAt: updated.tokenIssuedAt.toISOString(),
          ogImageUrl: `${baseUrl}/api/public/og/guinji/${updated.token}.png`,
          warning: "이전 링크로 들어오던 사람은 더 이상 들어올 수 없어요.",
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/guinji/maps/[mapId]/reissue] 실패:", e);
    return NextResponse.json(
      { success: false, error: "재발급 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
