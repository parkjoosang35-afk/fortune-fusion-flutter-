// 귀인지도 생성 API — Flutter GuinjiRepository.createMap() 대응.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-1] `POST /guinji/maps`.
//
// [요청] { name?: string, saju: GuinjiSajuInput } — name 생략 시
// "{닉네임}의 지도"로 자동 생성한다(S2 온보딩 화면 확정 문구 참고).
// saju는 owner 본인의 사주 계산 결과(B안 — 클라이언트 ManseryeokCoreEngine
// 산출값)이며, 이후 멤버 추가 시마다 RelationJudger가 재사용할 수 있도록
// GuinjiMap.ownerSajuParsed에 캐시 저장한다(M9 재계산 시 이 값도 갱신).
//
// [소유자당 1개 제약] schema.prisma `@@unique([ownerId])`. 이미 지도가
// 있으면 새로 만들지 않고 기존 지도를 그대로 반환한다(200) — 온보딩 화면
// 재진입 시 에러 없이 항상 "내 지도"로 안내하기 위함(개발계획서 §1 "온보딩
// →지도" 1:1 흐름과 일치).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  generateGuinjiToken,
  requireUser,
  toGuinjiMapPublicId,
  unauthorizedResponse,
} from "../_shared";
import { isValidGuinjiSajuInput } from "@/lib/guinji-relation-judger";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { name?: string; saju?: unknown };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  if (!isValidGuinjiSajuInput(body.saju)) {
    return NextResponse.json(
      { success: false, error: "saju(사주 계산 결과)가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 이미 지도가 있으면 그대로 반환(멱등) — @@unique([ownerId]) 보장.
    const existing = await prisma.guinjiMap.findUnique({
      where: { ownerId: auth.userId },
    });
    if (existing && existing.deletedAt == null) {
      return NextResponse.json(
        {
          success: true,
          data: { mapId: toGuinjiMapPublicId(existing.id), token: existing.token, isNew: false },
        },
        { headers: CORS_HEADERS }
      );
    }

    const name = body.name?.trim() || `${auth.nickname}의 지도`;

    // 토큰 충돌(사실상 발생하지 않지만 unique 제약이 있으므로 방어적 재시도).
    let created: { id: number; token: string } | null = null;
    for (let attempt = 0; attempt < 3 && !created; attempt++) {
      const token = generateGuinjiToken();
      try {
        created = await prisma.guinjiMap.create({
          data: {
            ownerId: auth.userId,
            name,
            token,
            ownerSajuParsed: JSON.stringify(body.saju),
          },
          select: { id: true, token: true },
        });
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code !== "P2002") throw e;
        // token 또는 ownerId 충돌 — ownerId 충돌이면 재조회 후 반환.
        const raced = await prisma.guinjiMap.findUnique({ where: { ownerId: auth.userId } });
        if (raced) {
          return NextResponse.json(
            {
              success: true,
              data: { mapId: toGuinjiMapPublicId(raced.id), token: raced.token, isNew: false },
            },
            { headers: CORS_HEADERS }
          );
        }
        // token 충돌이면 루프 재시도.
      }
    }
    if (!created) {
      throw new Error("TOKEN_GENERATION_FAILED");
    }

    return NextResponse.json(
      { success: true, data: { mapId: toGuinjiMapPublicId(created.id), token: created.token, isNew: true } },
      { status: 201, headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/guinji/maps] 실패:", e);
    return NextResponse.json(
      { success: false, error: "지도 생성 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
