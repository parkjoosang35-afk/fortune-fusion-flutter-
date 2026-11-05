// 신당(THE SHRINE) v3 — 「민세레나에게 부탁하기」(05 상세 → 결제 게이트 성공 →
// 07 부탁 연출) 확정 API.
//
// [설계 원칙 — fortune/tarot/route.ts 템플릿 그대로 재사용] 지갑차감(FREEPASS/
// POUCH/AD)은 전부 ResultAccessService(beginResultAccess)가 전담하고, 이
// 라우트는 그 결제가 확정된 "뒤"에 唯一 기록(이름/사주/소망/일련번호)을 가진
// ShrineOrder를 서버 트랜잭션으로 생성한다. reserveResultGeneration()는
// contentType 타입이 "compatibility"|"tarot"로 하드코딩돼 있어 shrine은 쓸 수
// 없으므로, tarot route.ts와 동일한 셀프 updateMany 락 패턴을 그대로 쓴다.
//
// [사용자 요구사항 #1 — 서버 처리] 지갑/복주머니 차감, 일련번호 발급, 향
// 일수 계산 모두 이 라우트(및 /box/incense)의 DB 트랜잭션 안에서만 일어난다.
// 클라이언트는 어떤 값도 계산하지 않고 서버 응답을 그대로 표시만 한다.
//
// [사용자 요구사항 #2 — 사주] buildSajuPillarsHanja()가 UserProfile에 저장된
// 생년월일로 calculateSaju()(정통사주 lunar-javascript 엔진)를 호출한다.
// 프로토타입의 하드코딩 SAJU8 상수는 사용하지 않는다.
//
// [요청] { talismanSlug: string, wish: string, paymentMethod, transactionId, adSessionId? }
// [응답] { success, data: { orderId, serial, talisman, ownerName, sajuPillars, wish,
//          issuedDateKey, expiresDateKey, daysRemaining, resultAccess } }
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  beginResultAccess,
  failAndRefundResultAccess,
  ResultAccessError,
  type ResultAccessPaymentMethod,
} from "@/lib/result-access-service";
import {
  CORS_HEADERS,
  requireUser,
  unauthorizedResponse,
  todayKstKey,
  addDaysToKstKey,
  buildSajuPillarsHanja,
  SHRINE_LIFE_DAYS,
} from "../_shared";

export const dynamic = "force-dynamic";

const MAX_WISH_LENGTH = 40; // README §4-1 "소망 입력(40자)".

/** README §6 唯一 일련번호 "神堂 N°00000" — 전역 유일, 서버 채번(클라이언트 계산 금지). */
function formatShrineSerial(n: number): string {
  return `神堂 N°${String(n).padStart(5, "0")}`;
}

export async function POST(request: NextRequest) {
  let body: {
    talismanSlug?: string;
    wish?: string;
    paymentMethod?: string;
    transactionId?: string;
    adSessionId?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;

  const talismanSlug = body.talismanSlug?.trim();
  const wish = body.wish?.trim();
  const transactionId = body.transactionId?.trim();
  const paymentMethod = body.paymentMethod as ResultAccessPaymentMethod | undefined;
  const VALID_METHODS: ResultAccessPaymentMethod[] = ["FREEPASS", "POUCH", "AD"];

  if (!talismanSlug) {
    return NextResponse.json(
      { success: false, error: "talismanSlug가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!wish || wish.length === 0 || wish.length > MAX_WISH_LENGTH) {
    return NextResponse.json(
      { success: false, error: `소망은 1~${MAX_WISH_LENGTH}자로 입력해주세요.` },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!transactionId) {
    return NextResponse.json(
      { success: false, error: "transactionId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!paymentMethod || !VALID_METHODS.includes(paymentMethod)) {
    return NextResponse.json(
      { success: false, error: "paymentMethod는 FREEPASS/POUCH/AD 중 하나여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // ── §4-3 "부족은 서버에서 최종 판정" — 부적/회원정보를 먼저 확인한다. ──
  const talisman = await prisma.talismanItem.findUnique({ where: { slug: talismanSlug } });
  if (!talisman || !talisman.isActive) {
    return NextResponse.json(
      { success: false, error: "부적을 찾을 수 없습니다." },
      { status: 404, headers: CORS_HEADERS }
    );
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });
  if (!user || user.status !== "active") {
    return NextResponse.json(
      { success: false, error: "유효하지 않은 계정입니다." },
      { status: 401, headers: CORS_HEADERS }
    );
  }
  const profile = user.profile;
  if (!profile?.realName || !profile.birthDate) {
    // README §1 "실명·사주 필요" — 05 상세 화면이 "회원 정보 확인" 단계에서
    // 이 상태를 먼저 걸러내야 하지만, 직접 API 호출 우회에 대비해 서버에서도
    // 최종 방어한다(타로/궁합 라우트의 birthDate 검증과 동일한 원칙).
    return NextResponse.json(
      {
        success: false,
        error: "신당 부적을 받으려면 먼저 마이페이지에서 실명과 생년월일을 입력해주세요.",
        reason: "PROFILE_INCOMPLETE",
      },
      { status: 409, headers: CORS_HEADERS }
    );
  }

  // ── 동일 거래로 재생성하지 않는다(§8.4 멱등성) — tarot route.ts와 동일 패턴. ──
  const existing = await prisma.resultAccessTransaction.findUnique({
    where: { transactionId },
    include: { shrineOrder: { include: { talismanItem: true } } },
  });
  if (existing) {
    if (existing.userId !== userId || existing.contentType !== "shrine_bujeok" || existing.paymentMethod !== paymentMethod) {
      return NextResponse.json(
        { success: false, reason: "TRANSACTION_OWNER_MISMATCH", error: "잘못된 요청입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    if (existing.status === "success" && existing.shrineOrder) {
      return NextResponse.json(
        { success: true, data: toOrderDto(existing.shrineOrder, existing) },
        { headers: CORS_HEADERS }
      );
    }
    if (existing.status !== "pending") {
      return NextResponse.json(
        { success: false, error: "이미 종료된 요청입니다.", reason: "TRANSACTION_ALREADY_PROCESSED" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
  }

  // ── §8.5 "결제 확정 후 생성" — 唯一 기록을 만들기 전에 먼저 차감을 확정한다. ──
  let resultAccessBegin: Awaited<ReturnType<typeof beginResultAccess>> | null = null;
  try {
    resultAccessBegin = await beginResultAccess({
      userId,
      transactionId,
      contentType: "shrine_bujeok",
      categoryKey: talisman.category,
      paymentMethod,
      adSessionId: body.adSessionId ?? null,
    });
  } catch (e) {
    if (e instanceof ResultAccessError) {
      const AD_SESSION_STATUS: Record<string, number> = {
        AD_SESSION_REQUIRED: 400,
        AD_SESSION_NOT_FOUND: 404,
        AD_SESSION_NOT_COMPLETED: 409,
        AD_SESSION_ALREADY_USED: 409,
      };
      const status =
        e.code === "NO_FREEPASS_BALANCE"
          ? 403
          : e.code === "INSUFFICIENT_POUCH_BALANCE"
            ? 409
            : AD_SESSION_STATUS[e.code] ?? 400;
      return NextResponse.json(
        { success: false, error: e.message, reason: e.code },
        { status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/shrine/order] ResultAccess 확정 실패:", e);
    return NextResponse.json(
      { success: false, error: "결과보기 권한 확인 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }

  // ── reserveResultGeneration()은 contentType 타입이 "compatibility"|"tarot"로
  // 제한돼 shrine에 쓸 수 없다 — tarot route.ts와 동일한 셀프 락을 직접 구현한다. ──
  try {
    const claim = await prisma.resultAccessTransaction.updateMany({
      where: { transactionId: resultAccessBegin.transactionId, userId, status: "pending", contentId: null },
      data: { contentId: "shrine_bujeok:generating" },
    });
    if (claim.count !== 1) {
      return NextResponse.json(
        { success: false, error: "부적을 짓는 중입니다. 잠시 후 다시 확인해주세요.", reason: "GENERATION_IN_PROGRESS" },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // ── §6 唯一 기록용 사주 — 서버가 UserProfile로 직접 계산(클라이언트 값 불신). ──
    const sajuPillars = buildSajuPillarsHanja({
      birthDate: profile.birthDate,
      birthTime: profile.birthTime,
      isLunar: profile.isLunar,
      isLeapMonth: profile.isLeapMonth,
      birthTimeUnknown: profile.birthTimeUnknown,
      gender: user.gender,
    });

    const issuedDateKey = todayKstKey();
    const expiresDateKey = addDaysToKstKey(issuedDateKey, SHRINE_LIFE_DAYS);

    // ── §6 "일련번호는 서버가 주문마다 1회 발급(중복 불가)" — P2002 재시도
    // 패턴(guinji/maps/route.ts와 동일)으로 동시 발급 경쟁을 안전하게 처리. ──
    const outcome = await createShrineOrderWithUniqueSerial({
      userId,
      talismanItemId: talisman.id,
      ownerName: profile.realName,
      sajuPillars,
      wish,
      transactionId: resultAccessBegin.transactionId,
      issuedDateKey,
      expiresDateKey,
    });

    return NextResponse.json(
      { success: true, data: toOrderDto({ ...outcome, talismanItem: talisman }, { transactionId: resultAccessBegin.transactionId, paymentMethod, amount: resultAccessBegin.amount }) },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    // ── §8.6 실패 시 환불 ──
    try {
      await failAndRefundResultAccess(resultAccessBegin.transactionId);
    } catch (refundError) {
      console.error("[POST /api/public/shrine/order] 환불 처리 실패:", refundError);
    }
    console.error("[POST /api/public/shrine/order] 실패:", e);
    return NextResponse.json(
      { success: false, error: "바람이 촛불을 흔듭니다. 잠시 뒤 다시 오십시오." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

/** [§6 唯一 일련번호 발급] ShrineOrder 테이블 전체 행 수 + 1을 기준값으로 채번하고,
 * 동시 생성 경쟁으로 같은 번호가 나오면(serial @unique) P2002를 잡아 최대 5회
 * 재시도한다 — guinji/maps/route.ts의 "token 충돌 재시도" 패턴과 동일. */
async function createShrineOrderWithUniqueSerial(params: {
  userId: number;
  talismanItemId: number;
  ownerName: string;
  sajuPillars: string;
  wish: string;
  transactionId: string;
  issuedDateKey: string;
  expiresDateKey: string;
}) {
  const { userId, talismanItemId, ownerName, sajuPillars, wish, transactionId, issuedDateKey, expiresDateKey } = params;
  for (let attempt = 0; attempt < 5; attempt++) {
    const count = await prisma.shrineOrder.count();
    const serial = formatShrineSerial(124 + count * 7);
    try {
      return await prisma.$transaction(async (tx) => {
        const txnRow = await tx.resultAccessTransaction.findUniqueOrThrow({
          where: { transactionId },
          select: { id: true },
        });
        const order = await tx.shrineOrder.create({
          data: {
            userId,
            talismanItemId,
            serial,
            ownerName,
            sajuPillars,
            wish,
            resultAccessTransactionId: txnRow.id,
            issuedDateKey,
            expiresDateKey,
            daysRemaining: SHRINE_LIFE_DAYS,
            status: "ACTIVE",
          },
          include: { talismanItem: true },
        });
        await tx.resultAccessTransaction.update({
          where: { transactionId },
          data: { status: "success", contentId: `shrine_bujeok_${order.id}` },
        });
        return order;
      });
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code !== "P2002") throw e;
      // serial 또는 resultAccessTransactionId 충돌 — 다음 루프에서 최신 count로 다시 채번.
      continue;
    }
  }
  throw new Error("SHRINE_SERIAL_EXHAUSTED");
}

function toOrderDto(
  order: {
    id: number;
    serial: string;
    ownerName: string;
    sajuPillars: string;
    wish: string;
    issuedDateKey: string;
    expiresDateKey: string;
    daysRemaining: number;
    status: string;
    talismanItem: { slug: string; category: string; hanja: string; name: string; aim: string; imagePath: string; thumbPath: string | null };
  },
  access: { transactionId: string; paymentMethod: string; amount: number }
) {
  return {
    orderId: order.id,
    serial: order.serial,
    ownerName: order.ownerName,
    sajuPillars: order.sajuPillars,
    wish: order.wish,
    issuedDateKey: order.issuedDateKey,
    expiresDateKey: order.expiresDateKey,
    daysRemaining: order.daysRemaining,
    status: order.status,
    talisman: {
      slug: order.talismanItem.slug,
      category: order.talismanItem.category,
      hanja: order.talismanItem.hanja,
      name: order.talismanItem.name,
      aim: order.talismanItem.aim,
      imagePath: order.talismanItem.imagePath,
      thumbPath: order.talismanItem.thumbPath,
    },
    resultAccess: {
      transactionId: access.transactionId,
      paymentMethod: access.paymentMethod,
      amount: access.amount,
    },
  };
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
