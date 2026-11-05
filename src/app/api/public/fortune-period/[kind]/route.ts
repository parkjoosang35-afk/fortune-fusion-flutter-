// [신통방통 오늘·주간·월간 운세 — 2026-11 디자인 지시서 §5] GET-or-create API.
//
// [레거시 /api/public/fortune/daily 와의 구분] 그 라우트는 2026-08-13
// "일간 운세→80항목 통합" 결정으로 410 deprecated 상태다(신규 생성 없음,
// 과거 결과 조회만). 이 기능은 그와 무관한 신규 "무료 3종 운세"이므로
// 경로 충돌을 피해 /api/public/fortune-period/{kind}로 새로 둔다.
//
// [절대 원칙]
//  - 사주정보는 user_profiles 기존 필드를 그대로 쓴다(신규 저장 API 없음,
//    여기서는 읽기만 한다 — 저장/수정은 기존 PATCH /api/public/auth/profile).
//  - 3종 모두 무료 — 복주머니 차감/광고 시청 조건 없음(이 라우트는 그런
//    차감 로직을 아예 포함하지 않는다).
//  - period_key는 서버가 KST 기준으로 계산한다(클라이언트 값 불신).
//  - (userId, kind, periodKey, sajuRev) UNIQUE로 중복 생성을 막는다. 동시
//    요청이 와도 Prisma의 P2002(unique 충돌)를 흡수해 재조회만으로 정확히
//    1건을 반환한다(레이스에서 생성 경쟁에 "진" 요청도 에러 없이 기존 행을
//    반환 — getSajuFacts()의 upsert 패턴과 동일한 "흡수" 사상).
import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db";
import { authenticateRequest } from "@/lib/user-auth";
import { computePeriod, type FortuneKind } from "@/lib/fortune-period/period-key";
import {
  fetchFortuneFromEngine,
  FortuneEngineError,
  type FortunePayload,
  type ProfileBirthInfo,
} from "@/lib/fortune-period/engine-adapter";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function isValidKind(v: string): v is FortuneKind {
  return v === "today" || v === "week" || v === "month";
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ kind: string }> }
) {
  const { kind: rawKind } = await params;

  if (!isValidKind(rawKind)) {
    return NextResponse.json(
      { success: false, error: "지원하지 않는 운세 종류입니다.", reason: "INVALID_KIND" },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const kind = rawKind;

  // ── 1) 회원 인증 ──
  const payload = await authenticateRequest(request);
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "로그인이 필요합니다.", reason: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }
  const userId = payload.userId;

  // ── 2) 사주정보 확인(UserProfile 기존 필드 재사용) ──
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });
  if (!user || user.status !== "active") {
    return NextResponse.json(
      { success: false, error: "유효하지 않은 계정입니다.", reason: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  const profile = user.profile;
  if (!profile || !profile.birthDate) {
    // README §2 화면 흐름: 사주정보 없음 → 클라이언트가 등록 화면으로 리다이렉트.
    return NextResponse.json(
      {
        success: false,
        error: "사주정보가 필요해요.",
        reason: "SAJU_REQUIRED",
      },
      { status: 409, headers: CORS_HEADERS }
    );
  }

  const birthInfo: ProfileBirthInfo = {
    birthDate: profile.birthDate,
    birthTime: profile.birthTime,
    isLunar: profile.isLunar,
    isLeapMonth: profile.isLeapMonth,
    gender: user.gender,
  };
  const sajuRev = profile.sajuRev;

  // ── 3) 기간 키 계산(서버 KST 기준) ──
  const period = computePeriod(kind, new Date());

  try {
    // ── 4) 기존 결과 조회(동일 사주리비전만 유효 — 리비전이 바뀌면 재생성) ──
    const existing = await prisma.fortunePeriodResult.findUnique({
      where: {
        userId_kind_periodKey_sajuRev: {
          userId,
          kind,
          periodKey: period.periodKey,
          sajuRev,
        },
      },
    });

    if (existing && !existing.invalidated) {
      // [hasPrevious 판정] README §5 응답 스키마의 isNew/hasPrevious — 새로
      // 생성되지 않고 그대로 반환하는 경우 isNew=false. hasPrevious는 "이번
      // 기간 이전에" 같은 kind로 생성된 적이 있는지로 판단한다(new-period
      // 모달은 신규 생성 시에만 뜨므로 재조회 경로에서는 사실상 쓰이지
      // 않지만, 클라이언트 일관성을 위해 항상 계산해 함께 내려준다).
      const hasPrevious = await hasPreviousResult(userId, kind, period.periodKey);
      return okResponse(kind, period, existing.payload, false, hasPrevious);
    }

    // ── 5) 신규 생성: 엔진 호출 → 결정적 문장 조합 ──
    const fortunePayload: FortunePayload = await fetchFortuneFromEngine(kind, birthInfo, {
      startDate: period.startDate,
    });
    const payloadJson = JSON.stringify(fortunePayload);

    // ── 6) DB 저장(UNIQUE 제약으로 중복 생성 방지, 동시 요청 레이스 흡수) ──
    let savedPayload = payloadJson;
    try {
      const created = await prisma.fortunePeriodResult.create({
        data: {
          userId,
          kind,
          periodKey: period.periodKey,
          sajuRev,
          payload: payloadJson,
        },
      });
      savedPayload = created.payload;
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
        // [동시 요청 처리] 거의 동시에 들어온 다른 요청이 먼저 INSERT에 성공한
        // 경우 — 이 요청은 생성 경쟁에서 졌을 뿐이므로 에러로 취급하지 않고,
        // 방금 성공한 그 행을 재조회해 "정확히 1건"을 보장한다(README §5
        // "INSERT ON CONFLICT DO NOTHING → 재조회" pseudocode와 동일한 동작을
        // SQLite + Prisma 조합에서 구현한 것).
        const race = await prisma.fortunePeriodResult.findUnique({
          where: {
            userId_kind_periodKey_sajuRev: { userId, kind, periodKey: period.periodKey, sajuRev },
          },
        });
        if (!race) {
          // 이론상 거의 불가능(방금 P2002가 났다는 건 행이 있다는 뜻)하지만,
          // 혹시 그 사이 삭제되었다면 막 계산한 결과를 그대로 반환해 사용자
          // 경험은 끊기지 않게 한다(저장 실패와 조회 실패를 혼동하지 않음).
          return okResponse(kind, period, payloadJson, true, await hasPreviousResult(userId, kind, period.periodKey));
        }
        savedPayload = race.payload;
      } else {
        throw e;
      }
    }

    const hasPrevious = await hasPreviousResult(userId, kind, period.periodKey);
    return okResponse(kind, period, savedPayload, true, hasPrevious);
  } catch (e) {
    if (e instanceof FortuneEngineError) {
      console.error(`[GET /api/public/fortune-period/${kind}] 엔진 오류:`, e.message);
      return NextResponse.json(
        {
          success: false,
          error: "기운이 잠시 닿지 않았어요. 잠시 후 다시 시도해주세요.",
          reason: "ENGINE_ERROR",
          engineErrorKind: e.kind,
        },
        { status: e.kind === "VALIDATION" ? 400 : 502, headers: CORS_HEADERS }
      );
    }
    console.error(`[GET /api/public/fortune-period/${kind}] 실패:`, e);
    return NextResponse.json(
      { success: false, error: "운세를 불러오는 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

/** 이번 기간이 아닌, "과거"에 같은 kind로 생성된 결과가 있는지(사주리비전
 * 무관하게 하나라도) — README §3 "새 기간 안내창은 '이전 결과가 있을 때만'"
 * 조건 판정에 사용한다. */
async function hasPreviousResult(
  userId: number,
  kind: FortuneKind,
  currentPeriodKey: string
): Promise<boolean> {
  const prev = await prisma.fortunePeriodResult.findFirst({
    where: { userId, kind, periodKey: { not: currentPeriodKey } },
    select: { id: true },
  });
  return !!prev;
}

function okResponse(
  kind: FortuneKind,
  period: ReturnType<typeof computePeriod>,
  payloadJson: string,
  isNew: boolean,
  hasPrevious: boolean
) {
  const data = JSON.parse(payloadJson) as FortunePayload;
  return NextResponse.json(
    {
      success: true,
      data: {
        kind,
        periodKey: period.periodKey,
        period: { label: period.label, main: period.main, sub: period.sub, until: period.until },
        seal: data.seal,
        title: data.title,
        summary: data.summary,
        flow: data.flow,
        fields: data.fields,
        caution: data.caution,
        isNew,
        hasPrevious,
      },
    },
    { headers: CORS_HEADERS }
  );
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
