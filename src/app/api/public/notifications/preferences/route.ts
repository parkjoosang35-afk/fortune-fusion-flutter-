// 알림 수신 설정(카테고리별 on/off) 공개 API — Flutter SettingsScreen 대응.
//
// [배경] admin_web에는 이미 NotificationPreference 모델과 관리자 조회 페이지
// (/notifications/settings)가 있었으나, 회원 앱(Flutter)이 직접 자신의
// 설정을 읽고 바꿀 수 있는 공개 API는 없었다(04A N-3 명시: "회원 앱에서
// 직접 설정하는 값이므로 관리자는 조회만 한다" — 즉 CUD는 회원 앱의 몫).
// 화이트리스트(marketing/fortune_update/matching/community)는
// seed_notification_settings.ts와 동일하게 재사용한다(신규 카테고리 없음).
//
// GET: 로그인 사용자의 4개 카테고리 설정을 전부 반환한다(레코드가 없는
//      카테고리는 기본값 isEnabled=true로 채워서 반환 — schema.prisma의
//      @default(true)와 동일한 원칙, 클라이언트가 "아직 한번도 안 건드림"과
//      "명시적으로 켬"을 구분할 필요가 없도록 단순화).
// PUT: { category, isEnabled } — upsert(카테고리별 @@unique(userId,category)).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CATEGORIES = ["marketing", "fortune_update", "matching", "community"] as const;
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
