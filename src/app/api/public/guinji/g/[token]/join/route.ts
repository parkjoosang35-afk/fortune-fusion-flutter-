// 귀인지도 초대 링크 — 로그인 없는 "웹 정식 참여" API.
//
// [2026-09, 바이럴 흐름 근본 수정] 사용자가 극도로 분노하며 지적한 문제:
// "링크를 보내면 사주(생년월일)를 넣으면 거기서 끝나야지, 앱에서 또
// 들어가서 몰라야 해? 정보를 넣어도 지도에 올라가지도 않고 랭킹도 안
// 보이고 지도도 안 올라간다" — 즉 기존 `/preview` 라우트는 DB에 아무것도
// 저장하지 않는 "순수 계산 전용"으로 의도적으로 설계되어 있었고, 실제로
// 지도에 반영하는 `/guinji/maps/{mapId}/members`는 `requireUser()`로
// 로그인을 강제해, 웹에서는 절대 실제 참여가 불가능한 구조였다(이중 API
// 분리 문제). 이 라우트는 그 구조를 깨고, **로그인 없이 이름+생년월일을
// 한 번만 입력하면 그 자리에서 (1) 관계 결과가 나오고 (2) 실제로
// GuinjiMapMember/GuinjiRelationship이 생성되어 지도·랭킹에 즉시 반영**
// 되도록 한다 — doryeong.app(경쟁 서비스) 레퍼런스와 동등한 수준.
//
// [설계 결정 1 — 포인트 보상 미지급] `guinji_join` PointPolicy(+20P)는
// 로그인 기반 정식 참여(`/guinji/maps/{mapId}/members`, requireUser 강제)
// 에서만 지급한다. 익명 참여는 신원 확인이 없어 동일인이 반복 제출해
// 소유자에게 포인트를 무한정 farming할 수 있는 악용 위험이 있으므로,
// 이 라우트는 포인트를 절대 지급하지 않는다(이 결정은 사용자에게 투명하게
// 공유해야 한다).
//
// [설계 결정 2 — 중복 방지] 로그인이 없으므로 User.id 기준 중복 검사가
// 불가능하다. 대신 (mapId, name.trim(), birthDate) 조합이 이미 활성
// 멤버로 존재하면 새로 만들지 않고 기존 관계를 그대로 반환한다(에러가
// 아니라 idempotent 응답 — 새로고침/재제출로 지도에 중복 인물이 쌓이는
// 것을 막는다). 완벽한 악용 방지는 아니지만(다른 이름으로 재제출은 막지
// 못함) 신원 확인 장치가 없는 익명 플로우의 현실적 최소선이다.
//
// [절대 원칙 — 개인정보/연령 동의] `agreePolicy`(개인정보처리방침 동의)와
// `agreeAge14`(14세 이상 확인)가 모두 true가 아니면 참여를 거부한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { isGuinjiInviteExpired } from "../../../_shared";
import { GUINJI_RELATION_TYPE_ORDER, GuinjiSajuInput, judgeGuinjiRelation } from "@/lib/guinji-relation-judger";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "@/lib/saju-manseryeok-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const CORS_HEADERS_WITH_METHODS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

interface RequestBody {
  name?: string;
  birthDate?: string; // 'YYYY-MM-DD'
  calendarType?: string; // 'solar' | 'lunar', 기본 solar
  birthTime?: string | null; // 'HH:mm', null/미입력이면 시간모름
  gender?: string; // 'male' | 'female'
  agreePolicy?: boolean;
  agreeAge14?: boolean;
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

  const name = body.name?.trim();
  if (!name || name.length > 20) {
    return NextResponse.json(
      { success: false, error: "이름을 입력해 주세요(1~20자)." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (body.agreePolicy !== true || body.agreeAge14 !== true) {
    return NextResponse.json(
      { success: false, error: "개인정보처리방침 동의와 14세 이상 확인이 필요해요." },
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
    const guestSaju: GuinjiSajuInput = guinjiSajuInputFromManseryeok(guestManseryeok);
    const ownerSaju = JSON.parse(map.ownerSajuParsed) as GuinjiSajuInput;
    const judged = judgeGuinjiRelation(ownerSaju, guestSaju);

    const outcome = await prisma.$transaction(async (tx) => {
      // [설계 결정 2] 동일 지도에 동일 (이름+생년월일) 활성 멤버가 이미
      // 있으면 새로 만들지 않고 그 관계를 그대로 재사용한다(idempotent).
      const existingMember = await tx.guinjiMapMember.findFirst({
        where: { mapId: map.id, name, birthDate, status: "active" },
        include: { relationship: true },
      });
      if (existingMember?.relationship) {
        return { member: existingMember, relationship: existingMember.relationship, created: false };
      }

      const member = await tx.guinjiMapMember.create({
        data: {
          mapId: map.id,
          joinedUserId: null, // [설계 결정] 익명 참여 — 스키마가 이미 nullable로 지원.
          name,
          solarLunar: isLunar ? "lunar" : "solar",
          birthDate,
          birthTime: timeUnknown ? null : birthTime ?? null,
          birthTimeMissing: timeUnknown,
          sajuParsed: JSON.stringify(guestSaju),
        },
      });

      const relationship = await tx.guinjiRelationship.create({
        data: {
          mapId: map.id,
          ownerId: map.ownerId,
          memberId: member.id,
          relationType: judged.relationType,
          chemistryScore: judged.chemistryScore,
          ohaengEvidence: JSON.stringify(judged.ohaengEvidence),
        },
      });

      // [설계 결정 1] 익명 참여는 포인트 미지급 — guinji_join PointPolicy는
      // 로그인 기반 /guinji/maps/{mapId}/members 에서만 지급된다.

      return { member, relationship, created: true };
    });

    // 최신 관계 지도 집계(비식별) — 프론트가 이 응답만으로 즉시 그래프를
    // 다시 그릴 수 있게 한다(추가 GET 호출 없이 1회 요청으로 완결).
    // [2026-11 멤버 삭제 기능] 소유자가 잘못 입력된 멤버를 삭제(소프트
    // 삭제, GuinjiMapMember.status="removed")하면 그 관계는 더 이상
    // 집계·그래프에 나타나면 안 된다. relationType만 보고 카운트하던
    // 기존 로직은 memberId↔member.status 조인이 없어 삭제해도 숫자가
    // 줄지 않는 버그가 있었으므로, member.status="active" 조건을 조인해
    // 필터링한다.
    const allRelationships = await prisma.guinjiRelationship.findMany({
      where: { mapId: map.id, member: { status: "active" } },
      select: { relationType: true },
    });
    const rawCounts: Record<string, number> = {};
    for (const t of GUINJI_RELATION_TYPE_ORDER) rawCounts[t] = 0;
    for (const r of allRelationships) {
      if (rawCounts[r.relationType] != null) rawCounts[r.relationType] += 1;
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          ownerName: map.owner.nickname,
          relationType: outcome.relationship.relationType,
          chemistryScore: outcome.relationship.chemistryScore,
          timeUnknown: guestManseryeok.timeUnknown,
          dayMasterKr: guestManseryeok.dayMaster.kr,
          dayMasterElement: guestManseryeok.dayMaster.element,
          joined: true, // [명시] 이 응답은 실제로 지도에 반영되었음을 뜻한다.
          // [2026-11 추가 — "같은 귀인 4명이 다 똑같다" 버그 수정] 사람마다
          // 다르게 계산되는 오행/합충/방향성 근거 데이터를 응답에 포함한다.
          // 지금까지 이 값은 DB(guinjiRelationship.ohaengEvidence)에만
          // 저장되고 클라이언트로는 절대 전달되지 않아, 결과 화면이
          // 관계유형별 고정 문구 1개만 보여주는 원인이었다. 이제
          // `relation-narrative.ts`가 이 값을 받아 사람마다 다른 서술을
          // 조합해 만든다(어뷰징 없이 — 완전 무작위가 아니라 실제 계산값
          // 기반). idempotent 재사용 경로(기존 멤버 재제출)에서도
          // relationType/chemistryScore와 마찬가지로 outcome.relationship
          // (DB 저장값) 기준으로 통일해, 매번 재계산한 judged 대신 실제
          // 저장된 값과 항상 일치하도록 한다.
          ohaengEvidence: JSON.parse(outcome.relationship.ohaengEvidence) as typeof judged.ohaengEvidence,
          mapSummary: { total: allRelationships.length, counts: rawCounts },
        },
      },
      { status: outcome.created ? 201 : 200, headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/guinji/g/[token]/join] 실패:", e);
    return NextResponse.json(
      { success: false, error: "참여 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_METHODS });
}
