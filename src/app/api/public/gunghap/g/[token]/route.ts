// 궁합지도(Gunghap Map) 초대 토큰 열람 API — 게스트가 초대 링크를 열었을 때
// 참여 폼을 보여주기 전에 토큰 유효성을 확인한다.
// [신통방통 궁합지도 개발 지시서 §1-2 "g/{token}/join", 개발 승인(API 단계) §2]
//
// [설계 결정 — 익명 접근 허용, 귀인지도와 다른 점] 귀인지도의 동급 라우트
// (`guinji/g/[token]/route.ts`)는 `requireUser()`로 로그인을 강제한다 —
// 귀인지도 앱의 게스트 참여 흐름이 "로그인한 앱 사용자가 딥링크로 진입"을
// 전제하기 때문이다. 반면 궁합지도는 지시서 §1-2 "초대받은 사람이 직접
// 자신의 생년월일을 입력합니다"가 로그인 여부를 전제하지 않고, 오히려
// "초대 발송자가 상대방의 생년월일을 미리 알고 있어야 하는 구조로 만들지
// 마세요"라는 절대 원칙이 "앱을 설치/로그인하지 않은 사람도 링크만으로
// 참여"할 수 있어야 함을 내포한다(귀인지도 `guinji/g/[token]/join`의
// 익명 웹 참여 흐름과 동일 설계 사상). 따라서 이 GET도 POST(join)와
// 동일하게 **로그인을 요구하지 않는다**.
//
// [응답] {inviteId, ownerName, joined, resultId?}
//   - joined=true면 이미 게스트가 제출을 완료했다는 뜻(중복 제출 방지용
//     클라이언트 안내 — "이미 참여했어요, 결과 보기"로 유도).
// [에러 매핑] 404 NOT_FOUND(토큰 없음/삭제됨) / 403 REVOKED(소유자가 중단)
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, CORS_HEADERS_WITH_AUTH, toGunghapResultPublicId } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> },
) {
  const { token } = await params;

  try {
    const invite = await prisma.gunghapInvite.findUnique({
      where: { token },
      include: {
        owner: { select: { nickname: true } },
        result: { select: { id: true } },
      },
    });

    if (!invite || invite.deletedAt != null || invite.status !== "active") {
      return NextResponse.json(
        { success: false, error: "초대 링크를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS },
      );
    }

    // [중요] 이미 참여(result 존재)했다면 revoke 여부와 무관하게 결과를
    // 볼 수 있어야 한다(귀인지도 g/[token]/route.ts와 동일 순서 원칙 —
    // "이미 참여한 사람은 revoked 차단보다 먼저 판정").
    if (invite.result == null && invite.revokedAt != null) {
      return NextResponse.json(
        { success: false, error: "초대한 사람이 이 링크를 중단했어요.", code: "REVOKED" },
        { status: 403, headers: CORS_HEADERS },
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          ownerName: invite.ownerName ?? invite.owner.nickname,
          joined: invite.result != null,
          resultId: invite.result ? toGunghapResultPublicId(invite.result.id) : null,
        },
      },
      { headers: CORS_HEADERS },
    );
  } catch (e) {
    console.error("[GET /api/public/gunghap/g/[token]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "초대 링크 확인 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
