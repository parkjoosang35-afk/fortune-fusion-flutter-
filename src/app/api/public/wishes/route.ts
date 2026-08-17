// 소원방 목록/작성 API — WishWallRepository.fetchFeed()/createWish() 대응.
//
// [작업6-1-C] Mock(MockWishWallRepository)을 대체할 실제 API.
// GET: 최신순/인기순 정렬, 카테고리 필터, 페이지네이션, status='visible|gratitude'만
//      노출(deleted/blinded 제외).
// POST: 작성자는 반드시 authenticateRequest()로 결정한 로그인 사용자(JWT)만 허용.
//       성공 시 point_policies.wish_reward(현재 amount=2, dailyLimit=1) 정책에 따라
//       checkPolicyEligibility() → earnLuckPouch()로 실제 복주머니를 지급하고,
//       grantedAmount를 응답에 포함한다(클라이언트는 이 값으로만 "+N 적립" 문구를
//       표시해야 한다 — 하드코딩 금지, 이미 지급된 경우 grantedAmount=0).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { checkPolicyEligibility, earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  CORS_HEADERS,
  glassLevelToCandleLevel,
  requireUser,
  toWishDto,
  unauthorizedResponse,
  WISH_VISIBLE_WHERE,
  type WishRow,
} from "./_shared";

export const dynamic = "force-dynamic";

const ALLOWED_CATEGORIES = [
  "exam",
  "job",
  "money",
  "love",
  "family",
  "health",
  "travel",
  "growth",
  "etc",
];

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const category = searchParams.get("category");
  const sort = searchParams.get("sort") === "popular" ? "popular" : "latest";
  const page = Math.max(1, Number(searchParams.get("page") ?? "1"));
  const pageSize = Math.min(
    50,
    Math.max(1, Number(searchParams.get("pageSize") ?? "20"))
  );

  // 목록은 비로그인 열람을 허용한다(로그인 시 isMine 판별용으로만 사용).
  const auth = await requireUser(request);

  try {
    const where: Record<string, unknown> = { ...WISH_VISIBLE_WHERE };
    if (category && category !== "all") {
      if (!ALLOWED_CATEGORIES.includes(category)) {
        return NextResponse.json(
          { success: false, error: "category 값이 올바르지 않습니다." },
          { status: 400, headers: CORS_HEADERS }
        );
      }
      where.category = category;
    }

    const [wishes, total] = await Promise.all([
      prisma.wish.findMany({
        where,
        include: { user: { select: { nickname: true } } },
        orderBy:
          sort === "popular"
            ? [{ bokjuCount: "desc" }, { supportCount: "desc" }]
            : [{ createdAt: "desc" }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      prisma.wish.count({ where }),
    ]);

    const data = (wishes as unknown as WishRow[]).map((w) =>
      toWishDto(w, auth?.userId ?? null)
    );

    return NextResponse.json(
      {
        success: true,
        data,
        pagination: { page, pageSize, total, hasMore: page * pageSize < total },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/wishes] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 목록을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: {
    category?: string;
    content?: string;
    goalTag?: string | null;
    glassLevel?: number;
    visibility?: "anonymous" | "public" | "private";
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const category = body.category ?? "";
  const content = (body.content ?? "").trim();
  if (!ALLOWED_CATEGORIES.includes(category)) {
    return NextResponse.json(
      { success: false, error: "category 값이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (content.length < 5 || content.length > 200) {
    return NextResponse.json(
      { success: false, error: "소원 내용은 5자 이상 200자 이하여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const visibility = body.visibility ?? "anonymous";
  // isAnonymous는 기존 Wish.isAnonymous 필드 그대로 사용(닉네임 노출 여부).
  // visibility='private'인 경우는 status='private_only'로 별도 표시(신규 필드 없음).
  const isAnonymous = visibility === "anonymous";
  const candleLevel = glassLevelToCandleLevel(body.glassLevel ?? 0);

  try {
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: auth.userId } });
      if (!user) throw new Error("USER_NOT_FOUND");

      const wish = await tx.wish.create({
        data: {
          userId: auth.userId,
          content,
          category,
          isAnonymous,
          goalTag: body.goalTag ?? null,
          candleLevel,
          status: visibility === "private" ? "private_only" : "visible",
        },
        include: { user: { select: { nickname: true } } },
      });

      // [소원 작성 보상] PointPolicy.wish_reward(amount=2, dailyLimit=1, scope=daily)
      // 정책을 그대로 사용한다. 정책값을 코드에서 하드코딩하지 않고 checkPolicyEligibility
      // /earnLuckPouch가 DB의 PointPolicy/EconomyConfig를 그대로 참조하도록 위임한다.
      const eligibility = await checkPolicyEligibility(tx, auth.userId, "wish_reward", {
        scope: "daily",
      });

      let grantedAmount = 0;
      if (eligibility.eligible) {
        const policy = await tx.pointPolicy.findUnique({
          where: { sourceType: "wish_reward" },
        });
        const amount = policy?.amount ?? 0;
        if (amount > 0) {
          const outcome = await earnLuckPouch(tx, {
            userId: auth.userId,
            amount,
            sourceType: "wish_reward",
            sourceId: wish.id,
            memo: "소원 봉인 완료",
          });
          grantedAmount = outcome.grantedAmount;
        }
      }

      return { wish, grantedAmount };
    });

    const dto = toWishDto(result.wish as unknown as WishRow, auth.userId);
    return NextResponse.json(
      { success: true, data: { ...dto, grantedAmount: result.grantedAmount } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 작성에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
