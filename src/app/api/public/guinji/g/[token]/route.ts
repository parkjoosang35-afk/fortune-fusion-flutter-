// 귀인지도 초대 토큰 열람 API — Flutter GuestJoinScreen(S9) 딥링크 진입 대응.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-4] `GET /guinji/g/{token}`.
//
// [흐름] `sintong.app/g/{token}` 딥링크로 진입한 지인(guest, 로그인 필요)이
// 참여 폼(S9)을 보여주기 전에, 토큰이 유효한지·이미 참여했는지 확인한다.
//   - 토큰이 아예 없으면 → NOT_FOUND (E5 NoMapScreen)
//   - 지도가 삭제/비활성 상태면 → NOT_FOUND (E5, "지도 주인이 봉인을 거두었습니다")
//   - [M6 확정] 지도 생성 후 7일 경과 → EXPIRED (E1, "새 지도 만들기")
//   - 이미 활성 멤버로 참여했다면 joined=true를 반환(E3 "내 결과 보기"로 유도할 근거)
//
// [응답] {mapId, ownerName, joined, expired}
// [에러 매핑] 404 EXPIRED(§6 "만료") / 404 NOT_FOUND
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  isGuinjiInviteExpired,
  requireUser,
  toGuinjiMapPublicId,
  unauthorizedResponse,
} from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { token } = await params;

  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      include: { owner: { select: { nickname: true } } },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // [M6 확정] 7일 만료 체크 — 지도 자체는 살아있어도 이 초대 링크는 더 이상
    // 유효하지 않은 것으로 취급한다(E1 "새 지도 만들기" 안내로 이어짐).
    if (isGuinjiInviteExpired(map.createdAt)) {
      return NextResponse.json(
        { success: false, error: "초대 링크가 만료되었어요.", code: "EXPIRED" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const existingMember = await prisma.guinjiMapMember.findFirst({
      where: { mapId: map.id, joinedUserId: auth.userId, status: "active" },
      select: { id: true },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          mapId: toGuinjiMapPublicId(map.id),
          ownerName: map.owner.nickname,
          joined: existingMember != null,
          expired: false,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/guinji/g/[token]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "초대 링크 확인 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
