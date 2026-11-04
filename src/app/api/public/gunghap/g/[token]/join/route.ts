// 궁합지도(Gunghap Map) 게스트 참여 API — 초대받은 사람이 본인 사주정보를
// 직접 입력하면, 서버가 사주를 계산하고 3개 엔진(FACT/등급/서술)을 연결해
// 실제 궁합 결과를 생성·저장한다.
// [신통방통 궁합지도 개발 지시서 §1-2, §2 "게스트 입력", 개발 승인(API 단계)]
//
// [절대 원칙 — 초대자는 상대방 생년월일을 모른다] 이 라우트는 로그인을
// 요구하지 않는다(귀인지도 `guinji/g/[token]/join/route.ts`의 익명 웹
// 참여 흐름과 동일 설계). 초대자(owner)는 이 요청에 전혀 관여하지 않고,
// 오직 초대받은 사람이 링크를 열어 자신의 정보를 입력한다.
//
// [서버 계산 원칙] "사주 계산은 서버에서 처리합니다" — 게스트는 이름/
// 생년월일/성별/시간만 보내고, 서버가 `calculateSaju()`(귀인지도와 완전히
// 동일한 만세력 엔진)로 사주를 계산한다. 초대자의 사주(`ownerSajuParsed`)는
// 초대 생성 시 이미 클라이언트가 계산해 저장해 둔 값을 그대로 쓴다(서버가
// 재계산하지 않음 — "B안" 비대칭 신뢰 모델, 초대 생성 단계와 동일 설계).
//
// [중복 제출 방지 — 1초대 1결과] `GunghapPairResult.@@unique([inviteId])`
// 로 스키마 수준에서 "초대 1건당 응답 1건"을 강제한다. 이미 결과가 있는
// 초대에 다시 요청이 오면(동일인 재제출이든 동시 요청 경쟁이든) 새로
// 계산/저장하지 않고 **기존 저장된 결과를 그대로 반환**한다(created:false).
// 동시 요청 경쟁 상황은 트랜잭션 내 create → P2002 캐치 → 기존 레코드
// 재조회로 안전하게 처리한다(아래 핵심 로직 참고).
//
// [3개 엔진 연결] computeGunghapFact() → gradeAllCategories() →
// narrateAllCategories() 순서로 연결한다(지시서 §1-3 "궁합 결과").
//
// [무료/유료 분리] 이 응답(join 직후)은 **무료 결과만** 반환한다 — 분야별
// 등급(grade)만 노출하고, 4요소 서술(관계특징/잘맞는부분/갈등가능성/
// 개선방향)은 포함하지 않는다(상세 보고서는 별도 잠금해제 API를 통해서만
// 제공 — §2 "무료/유료 분리").
//
// [개인정보 최소 저장] joinedUserId는 항상 null로 저장한다(귀인지도 익명
// 참여와 동일 — 로그인 세션을 조회/연결하지 않는다). 결과 조회·잠금해제는
// 초대 소유자(owner)만 가능하도록 설계되어 있으므로(results/[resultId]
// 라우트 참고), 게스트 본인 식별 정보를 추가로 보관할 필요가 없다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { GuinjiSajuInput } from "@/lib/guinji-relation-judger";
import { guinjiSajuInputToV2 } from "@/lib/guinji-v2/adapter";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "@/lib/saju-manseryeok-engine";
import type { GunghapFactResult } from "@/lib/gunghap/gunghap-relation-fact";
import {
  computeGunghapResult,
  toFreeCategoryView,
  type StoredCategoryResult,
} from "@/lib/gunghap/gunghap-compute-helper";
import { CORS_HEADERS, CORS_HEADERS_WITH_AUTH, toGunghapResultPublicId } from "../../../_shared";

export const dynamic = "force-dynamic";

interface RequestBody {
  name?: string;
  birthDate?: string; // 'YYYY-MM-DD'
  calendarType?: string; // 'solar' | 'lunar', 기본 solar
  isLeapMonth?: boolean; // 음력 + 윤달일 때만 true (양력이면 무시)
  birthTime?: string | null; // 'HH:mm', null/미입력이면 시간모름
  gender?: string; // 'male' | 'female'
  agreePolicy?: boolean;
  agreeAge14?: boolean;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> },
) {
  const { token } = await params;

  let body: RequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const name = body.name?.trim();
  if (!name || name.length > 20) {
    return NextResponse.json(
      { success: false, error: "이름을 입력해 주세요(1~20자)." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  if (body.agreePolicy !== true || body.agreeAge14 !== true) {
    return NextResponse.json(
      { success: false, error: "개인정보처리방침 동의와 14세 이상 확인이 필요해요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const birthDate = body.birthDate?.trim();
  if (!birthDate || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    return NextResponse.json(
      { success: false, error: "생년월일을 YYYY-MM-DD 형식으로 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS },
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
        { status: 400, headers: CORS_HEADERS },
      );
    }
  } else if (m < 1 || m > 12 || d < 1 || d > 30) {
    return NextResponse.json(
      { success: false, error: "생년월일을 다시 확인해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  // [윤달 — 양력이면 무시] 지시서 §2 "양력·음력·윤달·출생시간 모름을
  // 지원합니다". isLunar=false일 때 isLeapMonth를 무시하는 것은
  // calculateSaju() 자체의 절대 규칙(saju-manseryeok-engine.ts 주석 참고)과
  // 동일하게 이 라우트에서도 명시적으로 보장한다.
  const isLeapMonth = isLunar && body.isLeapMonth === true;

  // [2026-11 귀인지도 버그 재발 방지 — 성별 암묵 기본값 금지] 값이 없거나
  // 'male'/'female'이 아니면 명시적으로 400 거부한다.
  if (body.gender !== "male" && body.gender !== "female") {
    return NextResponse.json(
      { success: false, error: "성별을 선택해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  const gender = body.gender;

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
    const invite = await prisma.gunghapInvite.findUnique({
      where: { token },
      include: {
        owner: { select: { nickname: true } },
        result: true,
      },
    });

    if (!invite || invite.deletedAt != null || invite.status !== "active") {
      return NextResponse.json(
        { success: false, error: "초대 링크를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS },
      );
    }

    // [중복 제출 방지 — 1초대 1결과] 이미 결과가 있으면 재계산하지 않고
    // 기존 저장값을 그대로 반환한다(idempotent). 동일인 재제출이든, 다른
    // 사람이 같은 링크에 또 입력을 시도하는 경우든 동일하게 처리한다 —
    // 스키마 설계(1:1) 자체가 "초대 1건당 응답 1건"이기 때문이다.
    if (invite.result != null) {
      return buildJoinResponse(invite.result, invite.owner.nickname, invite.ownerName, false, invite.majorId, invite.subName);
    }
    if (invite.revokedAt != null) {
      return NextResponse.json(
        { success: false, error: "초대한 사람이 이 링크를 중단했어요.", code: "REVOKED" },
        { status: 403, headers: CORS_HEADERS },
      );
    }
    // [2026-11 궁합 주제 반영 지시서 — Section 3] 7일 만료 체크. completed
    // 분기(위 invite.result != null)보다 뒤에 있으므로 이미 응답 완료된
    // 초대는 이 체크에 영향받지 않는다(확정 기준 "완료된 궁합 결과는 보존").
    if (invite.expiresAt != null && invite.expiresAt.getTime() < Date.now()) {
      return NextResponse.json(
        { success: false, error: "초대 링크가 만료되었어요(발급 후 7일이 지났어요).", code: "EXPIRED" },
        { status: 410, headers: CORS_HEADERS },
      );
    }
    if (!invite.ownerSajuParsed) {
      return NextResponse.json(
        { success: false, error: "초대자 사주 정보가 없어요." },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    // [서버 사주 계산] 게스트의 사주는 반드시 서버가 계산한다(클라이언트
    // 신뢰 없음 — 초대 생성(owner) 경로와 반대되는 신뢰 모델).
    let guestManseryeok;
    try {
      guestManseryeok = calculateSaju({
        year: y, month: m, day: d,
        hour, minute,
        gender,
        isLunar,
        timeUnknown,
        isLeapMonth,
      });
    } catch {
      return NextResponse.json(
        { success: false, error: "생년월일을 다시 확인해 주세요(달력상 존재하지 않는 날짜일 수 있어요)." },
        { status: 400, headers: CORS_HEADERS },
      );
    }

    const guestSaju: GuinjiSajuInput = guinjiSajuInputFromManseryeok(guestManseryeok);
    const ownerSaju = JSON.parse(invite.ownerSajuParsed) as GuinjiSajuInput;

    const ownerPersonInput = guinjiSajuInputToV2(ownerSaju, invite.ownerName ?? invite.owner.nickname);
    const guestPersonInput = guinjiSajuInputToV2(guestSaju, name);

    // [3개 엔진 연결 — Phase 3에서 gunghap-compute-helper.ts로 추출,
    // 로직 자체는 완전히 동일] FACT → 등급 → 서술 순서로 연결해 8개
    // 분야의 실제 결과를 생성한다. 어느 단계도 임의 수치를 넣지 않는다
    // (모든 값은 fact에서 결정론적으로 파생).
    const { fact, stored, engineVersion, ruleVersion } = await computeGunghapResult(
      ownerPersonInput,
      guestPersonInput,
    );

    const outcome = await prisma.$transaction(async (tx) => {
      try {
        const created = await tx.gunghapPairResult.create({
          data: {
            inviteId: invite.id,
            joinedUserId: null, // [개인정보 최소 저장] 익명 — 로그인 세션 연결 안 함.
            guestName: name,
            guestGender: gender,
            guestSolarLunar: isLunar ? "lunar" : "solar",
            guestBirthDate: birthDate,
            guestBirthTime: timeUnknown ? null : (birthTime ?? null),
            guestBirthTimeMissing: timeUnknown,
            guestIsLeapMonth: isLeapMonth,
            guestSajuParsed: JSON.stringify(guestSaju),
            factTrace: JSON.stringify(fact),
            categoryResults: JSON.stringify(stored),
            engineVersion,
            ruleVersion,
            // [2026-11 궁합 주제 반영 지시서 — Section 1/2] 초대 생성 시
            // 저장된 주제를 결과에도 복사한다(게스트는 join 시점에 주제를
            // 다시 선택하지 않음 — 초대자가 고른 주제를 그대로 따른다).
            majorId: invite.majorId ?? null,
            subName: invite.subName ?? null,
          },
        });
        return { result: created, created: true };
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code !== "P2002") throw e;
        // [동시 요청 경쟁 처리] 거의 동시에 두 요청이 들어와 하나가 먼저
        // 커밋되면, 나중 요청은 unique 제약(P2002)으로 걸린다 — 이 경우
        // 새로 만들지 않고 먼저 저장된 결과를 그대로 반환한다(중복 생성
        // 0건 보장).
        const existing = await tx.gunghapPairResult.findUnique({ where: { inviteId: invite.id } });
        if (!existing) throw e;
        return { result: existing, created: false };
      }
    });

    return buildJoinResponse(outcome.result, invite.owner.nickname, invite.ownerName, outcome.created, invite.majorId, invite.subName, guestManseryeok);
  } catch (e) {
    console.error("[POST /api/public/gunghap/g/[token]/join] 실패:", e);
    return NextResponse.json(
      { success: false, error: "참여 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

type GunghapPairResultRow = NonNullable<
  Awaited<ReturnType<typeof prisma.gunghapPairResult.findUnique>>
>;

function buildJoinResponse(
  result: GunghapPairResultRow,
  ownerNickname: string,
  ownerName: string | null,
  created: boolean,
  majorId?: string | null,
  subName?: string | null,
  guestManseryeok?: ReturnType<typeof calculateSaju>,
) {
  const fact = JSON.parse(result.factTrace) as GunghapFactResult;
  const stored = JSON.parse(result.categoryResults) as StoredCategoryResult[];

  return NextResponse.json(
    {
      success: true,
      data: {
        resultId: toGunghapResultPublicId(result.id),
        ownerName: ownerName ?? ownerNickname,
        guestName: result.guestName,
        relationType: fact.base.relationType,
        relationTypeLabel: fact.base.relationTypeLabel,
        relationTypeDesc: fact.base.relationTypeDesc,
        chemistryScore: fact.base.chemistryScore,
        grade: fact.base.grade,
        gradeCode: fact.base.gradeCode,
        timeUnknown: guestManseryeok ? guestManseryeok.timeUnknown : result.guestBirthTimeMissing,
        dayMasterKr: guestManseryeok ? guestManseryeok.dayMaster.kr : fact.member.dayMaster,
        dayMasterElement: guestManseryeok
          ? guestManseryeok.dayMaster.element
          : fact.member.dayMasterElement,
        majorId: majorId ?? result.majorId ?? null,
        subName: subName ?? result.subName ?? null,
        categories: toFreeCategoryView(stored, majorId ?? result.majorId),
        unlockCost: 100,
        joined: true,
      },
    },
    { status: created ? 201 : 200, headers: CORS_HEADERS },
  );
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
