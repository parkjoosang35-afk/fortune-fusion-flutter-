// 귀인지도 초대 링크 — 로그인 없는 "웹 미리보기" 관계판정 API.
// [Phase A-2 — 카톡 공유 바이럴 개선] 카톡 등에서 초대 링크(`/g/{token}`)를
// 열었을 때, 지금까지는 "앱에서 열기" 버튼만 있어 앱이 없는 사람은 이름·
// 생년월일을 입력할 방법이 전혀 없었다(2026-08 실사용자 리포트로 발견).
// 이 API는 로그인 없이 이름·생년월일만으로 즉시 관계 결과를 보여주는
// "웹 미리보기" 전용이다.
//
// [절대 원칙 — 결제없음/서버최종판단] 이 결과는 지급/저장을 유발하지
// 않는다: DB에 아무것도 쓰지 않고(GuinjiMapMember/GuinjiRelationship 생성
// 없음), PointPolicy 지급도 전혀 발생하지 않는다. "1명 참여 = 20P" 지급은
// 오직 로그인 후 정식 참여(`POST /guinji/maps/{mapId}/members`)에서만
// 일어난다 — 이 라우트는 순수 조회/계산 응답일 뿐이다.
//
// [간이 판정 — 정직성 원칙] `buildPreviewSajuInput()` 주석 참고. 이것은
// 정통사주 만세력 실계산이 아니라 결정론적 규칙(생년월일 해시) 기반
// 간이 계산이다. 응답에 `isPreview: true`를 항상 포함해, 프론트가 반드시
// "간이 미리보기"임을 사용자에게 표시하도록 강제한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { isGuinjiInviteExpired } from "../../../_shared";
import { buildPreviewSajuInput, judgeGuinjiRelation } from "@/lib/guinji-relation-judger";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const CORS_HEADERS_WITH_METHODS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

interface RequestBody {
  birthDate?: string; // 'YYYY-MM-DD'
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token } = await params;

  let body: RequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const birthDate = body.birthDate?.trim();
  if (!birthDate || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    return NextResponse.json(
      { success: false, error: "생년월일을 YYYY-MM-DD 형식으로 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  // 대략적인 날짜 유효성(달력상 실존 날짜인지) 확인 — 존재하지 않는 날짜로
  // 해시를 돌려 이상한 결과를 주지 않도록 최소 방어.
  const parsed = new Date(`${birthDate}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) {
    return NextResponse.json(
      { success: false, error: "생년월일을 다시 확인해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

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
    if (isGuinjiInviteExpired(map.createdAt)) {
      return NextResponse.json(
        { success: false, error: "초대 링크가 만료되었어요.", code: "EXPIRED" },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (!map.ownerSajuParsed) {
      return NextResponse.json(
        { success: false, error: "지도 소유자 사주 정보가 없어요." },
        { status: 500, headers: CORS_HEADERS }
      );
    }

    const ownerSaju = JSON.parse(map.ownerSajuParsed);
    const guestPreviewSaju = buildPreviewSajuInput(birthDate);
    const judged = judgeGuinjiRelation(ownerSaju, guestPreviewSaju);

    return NextResponse.json(
      {
        success: true,
        data: {
          ownerName: map.owner.nickname,
          relationType: judged.relationType,
          chemistryScore: judged.chemistryScore,
          isPreview: true,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/guinji/g/[token]/preview] 실패:", e);
    return NextResponse.json(
      { success: false, error: "미리보기 계산 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_METHODS });
}
