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
// [정확도 개선 — 2026-09] 기존 `buildPreviewSajuInput()`(생년월일 해시
// 기반 가짜 명식)을 폐기하고, `saju-manseryeok-engine.ts`(npm
// lunar-javascript, Flutter `SajuEngine`과 동일 알고리즘·동일 6tail
// 원작 버전)로 **실제 만세력**을 계산한다. 사용자가 "생년월일만 넣어도
// 정확한 사주/관계가 나와야 한다"고 명시적으로 요구했다 — 더 이상
// "간이 미리보기"가 아니라 실제 명식을 산출하되, 태어난 시간을 모를
// 때만(timeKnown=false) 정오(12:00) 가정 근사가 남아있을 뿐이다.
// 이 근사 하나 때문에 `isPreview: true`를 유지해 화면에 "시간 미입력 시
// 정확도가 낮을 수 있음"을 안내한다(정직성 원칙 — 느낌표 없이 담담하게).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { isGuinjiInviteExpired } from "../../../_shared";
import { judgeGuinjiRelation } from "@/lib/guinji-relation-judger";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "@/lib/saju-manseryeok-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const CORS_HEADERS_WITH_METHODS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

interface RequestBody {
  birthDate?: string; // 'YYYY-MM-DD'
  calendarType?: string; // 'solar' | 'lunar', 기본 solar
  birthTime?: string | null; // 'HH:mm', null/미입력이면 시간모름
  gender?: string; // 'male' | 'female', 기본 female(미입력 시 십성 성별차 없음 — 대운 방향에만 영향)
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
  const [y, m, d] = birthDate.split("-").map((s) => Number(s));
  const isLunar = body.calendarType === "lunar";
  // 달력상 실존 날짜인지 검증. 양력은 JS Date 롤오버 특성(예: "1995-02-30"이
  // 조용히 3월 2일로 넘어가는 것)을 되돌려 만든 날짜가 원래 입력과 정확히
  // 같은지 재확인해 걸러낸다. 음력은 JS Date 검증이 무의미하므로(음력
  // 월/일 범위가 양력과 다름) lunar-javascript 자체의 range validation
  // (calculateSaju 호출부 try/catch)에 맡긴다 — 최소한 범위만 여기서 거른다.
  if (!isLunar) {
    const parsed = new Date(y, m - 1, d);
    const isRealDate =
      !Number.isNaN(parsed.getTime()) &&
      parsed.getFullYear() === y &&
      parsed.getMonth() === m - 1 &&
      parsed.getDate() === d;
    if (!isRealDate) {
      return NextResponse.json(
        { success: false, error: "생년월일을 다시 확인해 주세요." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
  } else if (m < 1 || m > 12 || d < 1 || d > 30) {
    return NextResponse.json(
      { success: false, error: "생년월일을 다시 확인해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const gender = body.gender === "male" ? "male" : "female";
  let timeUnknown = true;
  let hour = 12;
  let minute = 0;
  const birthTime = body.birthTime?.trim();
  if (birthTime && /^\d{2}:\d{2}$/.test(birthTime)) {
    const [hh, mm] = birthTime.split(":").map((s) => Number(s));
    if (hh >= 0 && hh <= 23 && mm >= 0 && mm <= 59) {
      hour = hh;
      minute = mm;
      timeUnknown = false;
    }
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

    let guestManseryeok;
    try {
      guestManseryeok = calculateSaju({
        year: y, month: m, day: d,
        hour, minute,
        gender,
        isLunar,
        timeUnknown,
      });
    } catch {
      return NextResponse.json(
        { success: false, error: "생년월일을 다시 확인해 주세요(달력상 존재하지 않는 날짜일 수 있어요)." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    const guestSaju = guinjiSajuInputFromManseryeok(guestManseryeok);
    const judged = judgeGuinjiRelation(ownerSaju, guestSaju);

    return NextResponse.json(
      {
        success: true,
        data: {
          ownerName: map.owner.nickname,
          relationType: judged.relationType,
          chemistryScore: judged.chemistryScore,
          // [정확도 개선] 실제 만세력 기반 명식이므로 더 이상 가짜 결과가
          // 아니다. isPreview는 오직 "시간 미입력 시 정오 가정 근사"만을
          // 뜻한다(timeUnknown과 함께 프론트가 안내 문구를 조건부 표시).
          isPreview: true,
          timeUnknown: guestManseryeok.timeUnknown,
          dayMasterKr: guestManseryeok.dayMaster.kr,
          dayMasterElement: guestManseryeok.dayMaster.element,
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
