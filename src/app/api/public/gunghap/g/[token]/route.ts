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
// [응답] {inviteId, ownerName, joined, resultId?, status, majorId?, subName?}
//   - joined=true면 이미 게스트가 제출을 완료했다는 뜻(중복 제출 방지용
//     클라이언트 안내 — "이미 참여했어요, 결과 보기"로 유도).
//   - [2026-11 궁합 주제 반영 지시서 — Section 3] 4가지 상태를 명시적으로
//     구분해 내려준다(과거에는 result 존재 여부/revokedAt만으로 암묵
//     추론했음):
//       "completed" — 게스트가 이미 응답을 완료함(결과 존재). 완료된 결과는
//         만료 판정을 받지 않는다(영구 보존 — 확정 기준 "완료된 궁합 결과는
//         보존").
//       "cancelled" — 아직 응답 전에 소유자가 링크를 중단함(revokedAt 존재).
//       "expired"   — 아직 응답 전에 발급 후 7일이 지남(expiresAt 경과).
//       "pending"   — 응답 대기 중, 아직 유효함(기본 상태).
//     상태 우선순위: completed > cancelled > expired > pending (완료가 항상
//     최우선 — join/route.ts의 "invite.result != null 선확인" 원칙과 동일).
// [에러 매핑] 404 NOT_FOUND(토큰 없음/삭제됨) / 403 REVOKED(소유자가 중단,
//   하위 호환 — 기존 클라이언트는 이 code를 계속 사용 가능) / 410 EXPIRED(신규)
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

    // [4상태 판정 — completed 최우선] 이미 참여(result 존재)했다면 취소/
    // 만료 여부와 무관하게 항상 "completed"이고 결과를 볼 수 있어야 한다
    // (귀인지도 g/[token]/route.ts와 동일 순서 원칙 — "이미 참여한 사람은
    // revoked/expired 차단보다 먼저 판정", 확정 기준 "완료된 궁합 결과는
    // 보존").
    if (invite.result != null) {
      return NextResponse.json(
        {
          success: true,
          data: {
            ownerName: invite.ownerName ?? invite.owner.nickname,
            joined: true,
            resultId: toGunghapResultPublicId(invite.result.id),
            status: "completed",
            majorId: invite.majorId ?? null,
            subName: invite.subName ?? null,
          },
        },
        { headers: CORS_HEADERS },
      );
    }

    if (invite.revokedAt != null) {
      return NextResponse.json(
        {
          success: false,
          error: "초대한 사람이 이 링크를 중단했어요.",
          code: "REVOKED",
          data: { status: "cancelled" },
        },
        { status: 403, headers: CORS_HEADERS },
      );
    }

    if (invite.expiresAt != null && invite.expiresAt.getTime() < Date.now()) {
      return NextResponse.json(
        {
          success: false,
          error: "초대 링크가 만료되었어요(발급 후 7일이 지났어요).",
          code: "EXPIRED",
          data: { status: "expired" },
        },
        { status: 410, headers: CORS_HEADERS },
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          ownerName: invite.ownerName ?? invite.owner.nickname,
          joined: false,
          resultId: null,
          status: "pending",
          majorId: invite.majorId ?? null,
          subName: invite.subName ?? null,
          expiresAt: invite.expiresAt ? invite.expiresAt.toISOString() : null,
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
