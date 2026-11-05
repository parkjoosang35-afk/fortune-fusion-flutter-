// 귀인지도 멤버 "직접 추가"(DIRECT) API — 지도 소유자(로그인 회원)가
// 초대 링크 없이 지인의 생년월일을 바로 입력해 즉시 멤버로 등록한다.
//
// [배경 — 궁합지도 DIRECT 방식과의 정합성] 궁합지도(gunghap)는 이미
// INVITE(상대가 링크로 직접 입력) + DIRECT(로그인 당사자가 상대 정보를
// 바로 입력) 두 가지 플로우를 모두 제공한다(`gunghap/direct/route.ts`
// 참고). 귀인지도는 그동안 INVITE에 해당하는 두 경로
// (`maps/{mapId}/members/route.ts` — 로그인 지인 참여, `g/{token}/join/
// route.ts` — 비로그인 지인 참여)만 있었고, "소유자가 바로 입력"하는
// DIRECT 방식이 없었다. 사용자 확인("귀인지도에도 궁합지도 DIRECT와
// 동일한 개념을 추가 개발")에 따라 이 라우트를 신설한다.
//
// [기존 API와의 관계 — 절대 원칙] 이 라우트는 완전히 새로 추가되는
// 것이며, 기존 3개 귀인지도 참여 API
// (`members/route.ts`/`g/[token]/join/route.ts`/`g/[token]/preview/
// route.ts`)의 동작·계약은 단 한 글자도 변경하지 않는다(additive-only).
//
// [B안 비대칭 신뢰 모델 — gunghap/direct/route.ts와 동일 원칙]
// 로그인한 지도 "소유자" 본인의 사주는 이미 `GuinjiMap.ownerSajuParsed`에
// 캐시돼 있으므로 재전송받지 않고 그대로 재사용한다. 반대로 "지인"의
// 사주는 반드시 서버가 `calculateSaju()`로 계산한다(클라이언트가 보낸
// 값을 신뢰하지 않음 — 지인은 로그인 당사자가 아니므로).
//
// [중복 방지] 기존 `members/route.ts`(지인 본인 참여, joinedUserId 필수)와
// 달리 이 라우트는 joinedUserId가 없는(소유자가 대신 입력한) 멤버를
// 만든다. 완전히 동일한 (mapId, name.trim(), birthDate) 조합이 이미 활성
// 멤버로 존재하면 새로 만들지 않고 기존 관계를 그대로 반환한다
// (g/[token]/join/route.ts의 "설계 결정 2"와 동일한 idempotent 패턴 —
// 소유자가 같은 지인을 실수로 중복 등록하는 것을 방지).
//
// [포인트 미지급] 소유자 본인이 입력한 멤버는 "참여"가 아니라 소유자의
// 직접 등록 행위이므로, `guinji_join`(+20P) 포인트는 지급하지 않는다
// (g/[token]/join/route.ts의 "설계 결정 1"과 동일한 이유 — 소유자가
// 스스로 반복 입력해 포인트를 farming하는 악용을 막기 위함).
//
// [요청] { name, gender('male'|'female'), solarLunar('solar'|'lunar'),
//   birthDate('YYYY-MM-DD'), birthTime?('HH:mm'), isLeapMonth? }
//
// [에러 매핑] MAP_NOT_FOUND(404) / OWNER_SAJU_MISSING(500, 이론상 발생
// 불가) / INVALID_DATE(400).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGuinjiMapDbId,
  requireUser,
  toGuinjiMemberPublicId,
  unauthorizedResponse,
} from "../../../../_shared";
import { GuinjiSajuInput } from "@/lib/guinji-relation-judger";
import { judgeGuinjiRelationV2 } from "@/lib/guinji-v2/judge";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "@/lib/saju-manseryeok-engine";

export const dynamic = "force-dynamic";

interface RequestBody {
  name?: string;
  gender?: string; // 'male' | 'female'
  solarLunar?: string; // 'solar' | 'lunar'
  birthDate?: string; // 'YYYY-MM-DD'
  birthTime?: string | null; // 'HH:mm'
  isLeapMonth?: boolean;
}

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
      { success: false, error: "이름(별명)을 입력해 주세요(1~20자)." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // [성별 암묵 기본값 금지 — 2026-11 귀인지도 버그 재발 방지 원칙과 동일]
  if (body.gender !== "male" && body.gender !== "female") {
    return NextResponse.json(
      { success: false, error: "성별을 선택해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const gender = body.gender;

  const solarLunar = body.solarLunar === "lunar" ? "lunar" : "solar";
  const isLunar = solarLunar === "lunar";
  const isLeapMonth = isLunar && body.isLeapMonth === true;

  const birthDate = body.birthDate?.trim();
  if (!birthDate || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    return NextResponse.json(
      { success: false, error: "생년월일을 YYYY-MM-DD 형식으로 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const [y, m, d] = birthDate.split("-").map((s) => Number(s));
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
    const outcome = await prisma.$transaction(async (tx) => {
      const map = await tx.guinjiMap.findUnique({ where: { id: mapDbId } });
      if (!map || map.deletedAt != null || map.status !== "active") {
        throw new Error("MAP_NOT_FOUND");
      }
      if (map.ownerId !== auth.userId) {
        // [소유자 전용] 이 라우트는 지도 소유자만 호출할 수 있다 — 타인의
        // 지도에 멤버를 몰래 추가하는 것을 방지.
        throw new Error("MAP_NOT_FOUND");
      }
      if (!map.ownerSajuParsed) {
        throw new Error("OWNER_SAJU_MISSING");
      }

      // [중복 방지 — idempotent] 동일 지도에 동일 (이름+생년월일) 활성
      // 멤버가 이미 있으면 새로 만들지 않고 기존 관계를 그대로 반환한다.
      const existingMember = await tx.guinjiMapMember.findFirst({
        where: { mapId: map.id, name, birthDate, status: "active" },
        include: { relationship: true },
      });
      if (existingMember?.relationship) {
        return {
          member: existingMember,
          relationship: existingMember.relationship,
          created: false,
        };
      }

      // [서버 사주 계산 — 지인 전용] 소유자가 아닌 "지인"의 사주는
      // 반드시 서버가 계산한다(클라이언트가 보낸 값을 신뢰하지 않음).
      let memberManseryeok;
      try {
        memberManseryeok = calculateSaju({
          year: y,
          month: m,
          day: d,
          hour,
          minute,
          gender,
          isLunar,
          timeUnknown,
          isLeapMonth,
        });
      } catch {
        throw new Error("INVALID_DATE");
      }
      const memberSaju: GuinjiSajuInput =
        guinjiSajuInputFromManseryeok(memberManseryeok);
      const ownerSaju = JSON.parse(map.ownerSajuParsed) as GuinjiSajuInput;

      const judged = await judgeGuinjiRelationV2(ownerSaju, memberSaju, {
        other: name,
      });

      const member = await tx.guinjiMapMember.create({
        data: {
          mapId: map.id,
          joinedUserId: null, // [DIRECT] 소유자가 대신 입력 — 실제 회원 참여 아님.
          name,
          gender,
          solarLunar,
          birthDate,
          birthTime: timeUnknown ? null : birthTime ?? null,
          birthTimeMissing: timeUnknown,
          sajuParsed: JSON.stringify(memberSaju),
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

      // [포인트 미지급] guinji_join(+20P)은 지인 본인이 참여하는
      // members/route.ts·g/[token]/join/route.ts에서만 지급한다.
      return { member, relationship, created: true };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          memberId: toGuinjiMemberPublicId(outcome.member.id),
          relationship: {
            relationType: outcome.relationship.relationType,
            chemistryScore: outcome.relationship.chemistryScore,
            ohaengEvidence: JSON.parse(outcome.relationship.ohaengEvidence),
          },
          created: outcome.created,
        },
      },
      { status: outcome.created ? 201 : 200, headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    const errorMap: Record<string, { status: number; error: string }> = {
      MAP_NOT_FOUND: { status: 404, error: "지도를 찾을 수 없어요." },
      OWNER_SAJU_MISSING: { status: 500, error: "지도 소유자 사주 정보가 없어요." },
      INVALID_DATE: {
        status: 400,
        error: "생년월일을 다시 확인해 주세요(달력상 존재하지 않는 날짜일 수 있어요).",
      },
    };
    const mapped = errorMap[message];
    if (mapped) {
      return NextResponse.json(
        { success: false, error: mapped.error },
        { status: mapped.status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/guinji/maps/[mapId]/members/direct] 실패:", e);
    return NextResponse.json(
      { success: false, error: "등록 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
