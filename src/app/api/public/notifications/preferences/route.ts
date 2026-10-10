// 알림 수신 설정(카테고리별 on/off) 공개 API — Flutter SettingsScreen 대응.
//
// [배경] admin_web에는 이미 NotificationPreference 모델과 관리자 조회 페이지
// (/notifications/settings)가 있었으나, 회원 앱(Flutter)이 직접 자신의
// 설정을 읽고 바꿀 수 있는 공개 API는 없었다(04A N-3 명시: "회원 앱에서
// 직접 설정하는 값이므로 관리자는 조회만 한다" — 즉 CUD는 회원 앱의 몫).
//
// [신통방통 관리자 최종 정리 지시서 §3 "알림 관리"] 원래 화이트리스트는
// marketing/fortune_update/matching/community 4종이었으나, "matching"은
// 서버 어디에서도 createNotification(category:"matching")으로 알림을
// 생성하는 코드가 0건(매칭 기능 자체가 이미 삭제됨 — 위시룸/커뮤니티 알림은
// 전부 "community" 카테고리만 사용)으로 확인되어, 회원이 이 토글을 켜고
// 꺼도 아무 알림에도 영향이 없는 죽은 선택지였다. GET 응답에서 더 이상
// "matching"을 반환하지 않도록 화이트리스트에서 제거한다(PUT도 자동으로
// 거부됨). 기존에 "matching" 카테고리로 저장된 NotificationPreference
// 레코드는 삭제하지 않고 DB에 그대로 보존한다(원칙: 유지→off, 데이터 보존).
//
// GET: 로그인 사용자의 3개 카테고리 설정을 전부 반환한다(레코드가 없는
//      카테고리는 기본값 isEnabled=true로 채워서 반환 — schema.prisma의
//      @default(true)와 동일한 원칙, 클라이언트가 "아직 한번도 안 건드림"과
//      "명시적으로 켬"을 구분할 필요가 없도록 단순화).
// PUT: { category, isEnabled } — upsert(카테고리별 @@unique(userId,category)).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CATEGORIES = ["marketing", "fortune_update", "community"] as const;
type Category = (typeof CATEGORIES)[number];

function isValidCategory(value: unknown): value is Category {
  return typeof value === "string" && (CATEGORIES as readonly string[]).includes(value);
}

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const rows = await prisma.notificationPreference.findMany({
      where: { userId: auth.userId, deletedAt: null },
      select: { category: true, isEnabled: true },
    });
    const byCategory = new Map(rows.map((r) => [r.category, r.isEnabled]));

    const data = CATEGORIES.map((category) => ({
      category,
      // 레코드가 없으면 기본 수신 동의(true)로 간주한다.
      isEnabled: byCategory.has(category) ? byCategory.get(category)! : true,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/notifications/preferences] 실패:", e);
    return NextResponse.json(
      { success: false, error: "알림 설정을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function PUT(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { category?: string; isEnabled?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  if (!isValidCategory(body.category)) {
    return NextResponse.json(
      { success: false, error: "category가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (typeof body.isEnabled !== "boolean") {
    return NextResponse.json(
      { success: false, error: "isEnabled는 boolean이어야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    await prisma.notificationPreference.upsert({
      where: { userId_category: { userId: auth.userId, category: body.category } },
      create: { userId: auth.userId, category: body.category, isEnabled: body.isEnabled },
      update: { isEnabled: body.isEnabled, deletedAt: null },
    });

    return NextResponse.json(
      { success: true, data: { category: body.category, isEnabled: body.isEnabled } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[PUT /api/public/notifications/preferences] 실패:", e);
    return NextResponse.json(
      { success: false, error: "알림 설정 저장에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
