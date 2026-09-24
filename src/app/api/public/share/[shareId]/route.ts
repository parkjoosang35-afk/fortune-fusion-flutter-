// 결과 공유 조회/삭제 API — Flutter ShareApiService.fetchSharedResult()/
// deleteShareLink(), 그리고 admin_web `/r/[id]` SSR 페이지가 공용으로 쓴다.
// [sintong-share-proposal.pdf §5] `GET /api/share/{id}`, `DELETE /api/share/{id}`.
//
// [GET — 인증 불필요] 카톡 등으로 링크를 받은 미설치자는 로그인 상태를
// 알 수 없으므로, guinji `g/[token]/route.ts`와 동일하게 비로그인 열람을
// 허용한다. shareId 자체가 유일한 접근 통제 수단이다(NFR-03).
//
// [DELETE — 소유자만] 자신이 만든 공유 링크만 삭제(soft-delete)할 수
// 있다. JWT로 본인 확인 후 status='removed'로 전환한다(물리 삭제 없음 —
// 감사/통계 목적, guinji GuinjiMap.status 패턴과 동일).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  requireUser,
  unauthorizedResponse,
} from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ shareId: string }> }
) {
  const { shareId } = await params;

  try {
    const shared = await prisma.sharedResult.findUnique({
      where: { shareId },
      include: { user: { select: { nickname: true } } },
    });

    if (!shared || shared.deletedAt != null || shared.status !== "active") {
      return NextResponse.json(
        { success: false, error: "공유된 결과를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // 조회수 증가는 응답을 막지 않도록 결과 반환 후에도 무방하지만, 이
    // 단순 카운터 업데이트는 실패해도 조회 자체를 막을 이유가 없으므로
    // best-effort로 처리한다(실패해도 원본 조회는 이미 성공).
    prisma.sharedResult
      .update({ where: { shareId }, data: { viewCount: { increment: 1 } } })
      .catch((e) => console.error("[GET /api/public/share/[shareId]] 조회수 증가 실패:", e));

    let payload: unknown = null;
    try {
      payload = JSON.parse(shared.payload);
    } catch {
      payload = shared.payload;
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          shareId: shared.shareId,
          resultType: shared.resultType,
          title: shared.title,
          description: shared.description,
          payload,
          imageUrl: shared.imageUrl,
          ownerNickname: shared.user.nickname,
          viewCount: shared.viewCount,
          createdAt: shared.createdAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/share/[shareId]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "공유 결과 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ shareId: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { shareId } = await params;

  try {
    const shared = await prisma.sharedResult.findUnique({ where: { shareId } });
    if (!shared || shared.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "공유된 결과를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (shared.userId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인이 만든 공유 링크만 삭제할 수 있어요." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    await prisma.sharedResult.update({
      where: { shareId },
      data: { status: "removed", deletedAt: new Date() },
    });

    return NextResponse.json({ success: true }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[DELETE /api/public/share/[shareId]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "공유 링크 삭제 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
