// 궁합지도(Gunghap Map) 직접 생성(DIRECT) API — 로그인 사용자가 초대 링크
// 없이 마이페이지 등에서 상대 정보를 직접 입력해 즉시 궁합 결과를 만든다.
// [신통방통 궁합지도 통합 최종 개발 지시서 Phase 3]
//
// [요청] {
//   requestKey: string,       // 멱등키(아래 "멱등성 설계" 참고, 필수)
//   mySaju: GuinjiSajuInput,  // 로그인 사용자 본인 사주(클라이언트 선계산, "B안")
//   myName?: string,
//   partnerName, partnerBirthDate, partnerCalendarType, partnerIsLeapMonth,
//   partnerBirthTime, partnerGender  // 상대 정보(서버가 사주 재계산)
// }
//
// [B안 비대칭 신뢰 모델 — 초대 생성/join과 완전히 동일한 원칙 재사용]
// 로그인 사용자 "본인"의 사주는 Flutter가 이미 계산한 값을 그대로 신뢰한다
// (invites/route.ts의 `saju` 필드와 동일 계약 — `isValidGuinjiSajuInput()`
// 재사용). 반대로 "상대방"의 사주는 반드시 서버가 `calculateSaju()`로
// 재계산한다(join/route.ts의 게스트 사주 계산과 완전히 동일한 신뢰 모델 —
// 로그인 사용자라 해도 상대방 사주를 클라이언트가 계산해 보낸 값을 그대로
// 믿지 않는다. 상대방은 로그인 당사자가 아니므로 "자기 자신에 대해서만
// 클라이언트 계산을 신뢰한다" 원칙을 그대로 지킨다).
//
// [멱등성 설계 — API 재시도 vs 의도적 재조회 구분]
// "동일한 상대 정보로 다시 조회"는 재시도와 의도적 재생성을 데이터 내용
// 만으로는 구분할 수 없다(상대 생년월일이 같으면 요청 바디가 완전히
// 동일할 수 있음). 따라서 "요청 내용"이 아니라 "요청 세션"을 식별하는
// 별도 키 `requestKey`(Flutter가 "확인하기" 버튼을 누르는 매 순간 새
// UUID를 생성해 전송)를 둔다.
//   - 동일 requestKey로 재요청(네트워크 재시도, 중복 탭 등) → 기존 저장된
//     결과를 그대로 반환한다(created:false, 재계산/재저장 없음).
//   - 새 requestKey로 요청(사용자가 나중에 다시 버튼을 눌러 같은 상대와
//     또 궁합을 보는 경우) → 새 결과를 생성한다(created:true) — "의도적
//     재조회"는 막지 않는다(지시서 요구사항).
// 스키마 수준 보장은 `GunghapPairResult.@@unique([ownerUserId, requestKey])`
// (Phase 3 신규 마이그레이션, 로컬에만 적용 — 운영 적용은 별도 배포 단계)로
// 강제한다. join/route.ts와 동일하게 트랜잭션 내 create → P2002 캐치 →
// 기존 레코드 재조회 패턴으로 동시 요청 경쟁도 안전하게 처리한다.
//
// [3개 엔진 연결] `gunghap-compute-helper.ts`의 `computeGunghapResult()`를
// 그대로 재사용한다(join/route.ts와 완전히 동일한 계산 경로 — Phase 3에서
// 이 목적을 위해 미리 추출해 둔 공용 함수).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { GuinjiSajuInput, isValidGuinjiSajuInput } from "@/lib/guinji-relation-judger";
import { guinjiSajuInputToV2 } from "@/lib/guinji-v2/adapter";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "@/lib/saju-manseryeok-engine";
import { computeGunghapResult, toFreeCategoryView, type StoredCategoryResult } from "@/lib/gunghap/gunghap-compute-helper";
import { GUNGHAP_CATEGORY_ORDER } from "@/lib/gunghap/gunghap-category-rules";
import type { GunghapFactResult } from "@/lib/gunghap/gunghap-relation-fact";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  requireUser,
  toGunghapResultPublicId,
  unauthorizedResponse,
} from "../_shared";

export const dynamic = "force-dynamic";

interface RequestBody {
  requestKey?: string;
  mySaju?: unknown;
  myName?: string;
  partnerName?: string;
  partnerBirthDate?: string; // 'YYYY-MM-DD'
  partnerCalendarType?: string; // 'solar' | 'lunar'
  partnerIsLeapMonth?: boolean;
  partnerBirthTime?: string | null; // 'HH:mm'
  partnerGender?: string; // 'male' | 'female'
  majorId?: string;
  subName?: string;
}

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: RequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  // [멱등키 필수] 없으면 중복 생성 방지/의도적 재조회 구분이 불가능하므로
  // 명시적으로 400 거부한다(묵시적 기본값 금지 — 귀인지도 2026-11 버그
  // 재발 방지 원칙과 동일하게 "필수값은 반드시 검증한다"를 지킨다).
  const requestKey = body.requestKey?.trim();
  if (!requestKey || requestKey.length < 8 || requestKey.length > 100) {
    return NextResponse.json(
      { success: false, error: "requestKey가 올바르지 않습니다(8~100자)." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  if (!isValidGuinjiSajuInput(body.mySaju)) {
    return NextResponse.json(
      { success: false, error: "mySaju(본인 사주 계산 결과)가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const myName = body.myName?.trim();
  if (myName && myName.length > 20) {
    return NextResponse.json(
      { success: false, error: "이름은 20자 이내로 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const partnerName = body.partnerName?.trim();
  if (!partnerName || partnerName.length > 20) {
    return NextResponse.json(
      { success: false, error: "상대방 이름을 입력해 주세요(1~20자)." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const partnerBirthDate = body.partnerBirthDate?.trim();
  if (!partnerBirthDate || !/^\d{4}-\d{2}-\d{2}$/.test(partnerBirthDate)) {
    return NextResponse.json(
      { success: false, error: "상대방 생년월일을 YYYY-MM-DD 형식으로 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  const [y, m, d] = partnerBirthDate.split("-").map((s) => Number(s));
  const isLunar = body.partnerCalendarType === "lunar";
  if (!isLunar) {
    const parsed = new Date(y, m - 1, d);
    const isRealDate =
      !Number.isNaN(parsed.getTime()) &&
      parsed.getFullYear() === y &&
      parsed.getMonth() === m - 1 &&
      parsed.getDate() === d;
    if (!isRealDate) {
      return NextResponse.json(
        { success: false, error: "상대방 생년월일을 다시 확인해 주세요." },
        { status: 400, headers: CORS_HEADERS },
      );
    }
  } else if (m < 1 || m > 12 || d < 1 || d > 30) {
    return NextResponse.json(
      { success: false, error: "상대방 생년월일을 다시 확인해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  // [윤달 — 양력이면 무시, join/route.ts와 동일 원칙]
  const isLeapMonth = isLunar && body.partnerIsLeapMonth === true;

  // [성별 암묵 기본값 금지 — 2026-11 귀인지도 버그 재발 방지, join/route.ts와 동일]
  if (body.partnerGender !== "male" && body.partnerGender !== "female") {
    return NextResponse.json(
      { success: false, error: "상대방 성별을 선택해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  const partnerGender = body.partnerGender;

  // [2026-11 궁합 주제 반영 지시서 — Section 1/2] 사용자가 고른 궁합 분야.
  // 선택사항(미지정 시 레거시와 동일하게 8분야 전체 노출).
  const majorId = body.majorId?.trim();
  if (majorId && !GUNGHAP_CATEGORY_ORDER.includes(majorId as (typeof GUNGHAP_CATEGORY_ORDER)[number])) {
    return NextResponse.json(
      { success: false, error: "majorId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  const subName = body.subName?.trim();
  if (subName && subName.length > 40) {
    return NextResponse.json(
      { success: false, error: "subName은 40자 이내여야 합니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  let timeUnknown = true;
  let hour = 12;
  let minute = 0;
  const partnerBirthTime = body.partnerBirthTime?.trim();
  if (partnerBirthTime && /^\d{2}:\d{2}$/.test(partnerBirthTime)) {
    const [hh, mm] = partnerBirthTime.split(":").map((s) => Number(s));
    if (hh >= 0 && hh <= 23 && mm >= 0 && mm <= 59) {
      hour = hh;
      minute = mm;
      timeUnknown = false;
    }
  }

  try {
    // [멱등 — 동일 requestKey 재요청 시 재계산 없이 기존 결과 반환]
    // join/route.ts의 "invite.result != null" 선확인과 동일한 원칙 —
    // 트랜잭션 진입 전에 먼저 조회해 불필요한 사주 재계산(CPU 비용)과
    // 트랜잭션 진입 자체를 피한다. 동시 요청 경쟁은 아래 트랜잭션 내
    // P2002 캐치로 추가 방어한다.
    const existingByKey = await prisma.gunghapPairResult.findUnique({
      where: { ownerUserId_requestKey: { ownerUserId: auth.userId, requestKey } },
    });
    if (existingByKey) {
      return buildDirectResponse(existingByKey, myName, false);
    }

    // [서버 사주 계산 — 상대방 전용] 로그인 당사자가 아닌 "상대방"의
    // 사주는 반드시 서버가 계산한다(join/route.ts의 게스트 사주 계산과
    // 완전히 동일한 신뢰 모델 — 클라이언트가 보낸 상대방 사주를 신뢰하지
        // 않음).
    let partnerManseryeok;
    try {
      partnerManseryeok = calculateSaju({
        year: y, month: m, day: d,
        hour, minute,
        gender: partnerGender,
        isLunar,
        timeUnknown,
        isLeapMonth,
      });
    } catch {
      return NextResponse.json(
        { success: false, error: "상대방 생년월일을 다시 확인해 주세요(달력상 존재하지 않는 날짜일 수 있어요)." },
        { status: 400, headers: CORS_HEADERS },
      );
    }

    const partnerSaju: GuinjiSajuInput = guinjiSajuInputFromManseryeok(partnerManseryeok);
    const mySajuInput = body.mySaju as GuinjiSajuInput;

    const myPersonInput = guinjiSajuInputToV2(mySajuInput, myName || auth.nickname);
    const partnerPersonInput = guinjiSajuInputToV2(partnerSaju, partnerName);

    // [3개 엔진 연결 — join/route.ts와 완전히 동일한 공용 헬퍼 재사용]
    const { fact, stored, engineVersion, ruleVersion } = await computeGunghapResult(
      myPersonInput,
      partnerPersonInput,
    );

    const outcome = await prisma.$transaction(async (tx) => {
      try {
        const created = await tx.gunghapPairResult.create({
          data: {
            inviteId: null, // [Option A] DIRECT 결과는 invite 레코드 없음.
            resultType: "DIRECT",
            ownerUserId: auth.userId,
            requestKey,
            joinedUserId: null,
            guestName: partnerName,
            guestGender: partnerGender,
            guestSolarLunar: isLunar ? "lunar" : "solar",
            guestBirthDate: partnerBirthDate,
            guestBirthTime: timeUnknown ? null : (partnerBirthTime ?? null),
            guestBirthTimeMissing: timeUnknown,
            guestIsLeapMonth: isLeapMonth,
            guestSajuParsed: JSON.stringify(partnerSaju),
            factTrace: JSON.stringify(fact),
            categoryResults: JSON.stringify(stored),
            engineVersion,
            ruleVersion,
            majorId: majorId || null,
            subName: subName || null,
          },
        });
        return { result: created, created: true };
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code !== "P2002") throw e;
        // [동시 요청 경쟁 처리 — join/route.ts와 동일 패턴] 거의 동시에
        // 같은 requestKey로 두 요청이 들어와 하나가 먼저 커밋되면, 나중
        // 요청은 unique 제약(P2002)으로 걸린다 — 새로 만들지 않고 먼저
        // 저장된 결과를 그대로 반환한다(중복 생성 0건 보장).
        const existing = await tx.gunghapPairResult.findUnique({
          where: { ownerUserId_requestKey: { ownerUserId: auth.userId, requestKey } },
        });
        if (!existing) throw e;
        return { result: existing, created: false };
      }
    });

    return buildDirectResponse(outcome.result, myName, outcome.created, partnerManseryeok);
  } catch (e) {
    console.error("[POST /api/public/gunghap/direct] 실패:", e);
    return NextResponse.json(
      { success: false, error: "궁합 생성 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

type GunghapPairResultRow = NonNullable<
  Awaited<ReturnType<typeof prisma.gunghapPairResult.findUnique>>
>;

function buildDirectResponse(
  result: GunghapPairResultRow,
  myName: string | undefined,
  created: boolean,
  partnerManseryeok?: ReturnType<typeof calculateSaju>,
) {
  const fact = JSON.parse(result.factTrace) as GunghapFactResult;
  const stored = JSON.parse(result.categoryResults) as StoredCategoryResult[];

  return NextResponse.json(
    {
      success: true,
      data: {
        resultId: toGunghapResultPublicId(result.id),
        resultType: "DIRECT",
        ownerName: myName ?? null,
        guestName: result.guestName,
        relationType: fact.base.relationType,
        relationTypeLabel: fact.base.relationTypeLabel,
        relationTypeDesc: fact.base.relationTypeDesc,
        chemistryScore: fact.base.chemistryScore,
        grade: fact.base.grade,
        gradeCode: fact.base.gradeCode,
        timeUnknown: partnerManseryeok ? partnerManseryeok.timeUnknown : result.guestBirthTimeMissing,
        dayMasterKr: partnerManseryeok ? partnerManseryeok.dayMaster.kr : fact.member.dayMaster,
        dayMasterElement: partnerManseryeok
          ? partnerManseryeok.dayMaster.element
          : fact.member.dayMasterElement,
        majorId: result.majorId ?? null,
        subName: result.subName ?? null,
        categories: toFreeCategoryView(stored, result.majorId),
        unlockCost: 100,
        created,
      },
    },
    { status: created ? 201 : 200, headers: CORS_HEADERS },
  );
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
