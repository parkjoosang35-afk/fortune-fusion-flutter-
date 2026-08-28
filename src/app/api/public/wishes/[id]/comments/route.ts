// 소원 댓글 목록/작성 API — WishWallRepository.fetchComments()/createComment() 대응.
//
// [작업6-1-F 최종 결정] 댓글은 이번 6-1 범위에 포함하되, 기존 Prisma `Comment`
// 모델(targetType='wish')을 그대로 재사용한다. 새로운 댓글 테이블은 만들지 않는다.
// community/posts/[id]/comments/route.ts와 동일한 폴리모픽 패턴을 따르되,
// 다음 두 가지를 이번 소원방 원칙에 맞게 다르게 처리한다:
//   1) 작성자(userId)는 body가 아니라 반드시 authenticateRequest()의 JWT로 결정한다
//      (community 댓글 API처럼 body.userId를 신뢰하지 않는다).
//   2) [소원방 마무리 - Phase A] 복주머니 보상 지급을 이번에 추가한다. bokjumeoni-plan
//      §06 COMMENTS + §02 EARN 정책표에 wish_comment(amount=2, dailyLimit=3, scope=daily)가
//      명시되어 있고, PointPolicy 테이블에도 이미 시딩되어 있었다(seed_pouch_expansion_phase02.ts
//      "선등록 대기" 항목). "같은 소원엔 1회" 제약은 sourceId=wishId 기반
//      checkPolicyEligibility 중복 판정으로, "1일 3회" 제약은 scope='daily'로 함께
//      강제한다(두 판정 모두 sourceId를 넘기면 자동으로 같이 체크됨 — luck-pouch-engine.ts
//      checkPolicyEligibility 구현 참고).
//
// [글자 수 제한] bokjumeoni-plan §06: "응원 한 마디"는 60자 제한(SNS 댓글이 아님).
// 기존 500자 제한을 60자로 하향한다.
//
// [느낌표/물음표 자동 정리] §06: "!!! → ." — 브랜드 톤 규칙(느낌표 금지 원칙)에 따라
// 저장 전 정규화한다(연속 !/? 를 마침표 하나로 치환).
//
// [15자 미만 무지급] §06: "화이팅"류 저품질 방지 — 댓글 작성 자체는 허용하되 15자
// 미만이면 지급 자체를 스킵한다(checkPolicyEligibility 호출 이전에 길이로 분기).
//
// [지역+연령대 마스킹 관련] §06이 "익명 · 지역 + 연령대 마스킹"을 요구하지만 User
// 모델에 region/ageBand 필드가 존재하지 않아(schema.prisma 확인) 구현할 수 없다
// (발명 금지 원칙). 기존 authorName(닉네임) 표시 방식을 그대로 유지한다.
//
// [주의] Wish 모델에는 community_posts.comment_count 같은 캐시 필드가 없으므로
// (schema.prisma 확인 완료) 댓글 생성 시 Wish 레코드를 갱신하지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { checkPolicyEligibility, earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  CORS_HEADERS,
  parseWishDbId,
  requireUser,
  unauthorizedResponse,
} from "../../_shared";

const COMMENT_MAX_LENGTH = 60;
const COMMENT_MIN_LENGTH_FOR_REWARD = 15;
const WISH_COMMENT_SOURCE_TYPE = "wish_comment";

/** bokjumeoni-plan §06: "느낌표 · 물음표 자동 정리 — !!! → ." 연속된 !/?를 마침표
 * 하나로 치환한다(단독 1개도 포함 — UI 느낌표 금지 절대 원칙과 일치시키기 위해). */
function normalizePunctuation(text: string): string {
  return text.replace(/[!?]+/g, ".");
}

export const dynamic = "force-dynamic";

/** 댓글 열람/작성 가능 여부 — 상세 조회(route.ts)와 동일한 기준.
 * visible/gratitude는 누구나, private_only는 작성자 본인만 허용한다. */
function canAccessWish(
  wish: { status: string; userId: number },
  currentUserId: number | null
): boolean {
  if (wish.status === "visible" || wish.status === "gratitude") return true;
  if (wish.status === "private_only") return wish.userId === currentUserId;
  return false;
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const dbId = parseWishDbId(id);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "wishId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // 댓글 목록 조회는 상세 조회처럼 비로그인 열람을 허용한다(단, private_only는 제외).
  const auth = await requireUser(request);

  try {
    const wish = await prisma.wish.findUnique({ where: { id: dbId } });
    if (!wish || wish.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (!canAccessWish(wish, auth?.userId ?? null)) {
      return NextResponse.json(
        { success: false, error: "비공개 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    const comments = await prisma.comment.findMany({
      where: {
        targetType: "wish",
        targetId: dbId,
        status: "active",
        deletedAt: null,
      },
      include: { user: { select: { nickname: true } } },
      orderBy: { createdAt: "asc" },
    });

    const data = comments.map((c) => ({
      id: `wc_${c.id}`,
      wishId: id,
      authorName: c.user.nickname,
      text: c.content,
      createdAt: c.createdAt.toISOString(),
      isMine: auth != null && c.userId === auth.userId,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/:id/comments] 실패:", e);
    return NextResponse.json(
      { success: false, error: "댓글을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { id } = await params;
  const dbId = parseWishDbId(id);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "wishId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { text?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const rawContent = (body.text ?? "").trim();
  if (!rawContent) {
    return NextResponse.json(
      { success: false, error: "댓글 내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (rawContent.length > COMMENT_MAX_LENGTH) {
    return NextResponse.json(
      { success: false, error: `응원 한 마디는 ${COMMENT_MAX_LENGTH}자 이하로 남겨 주세요.` },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  // 정규화(느낌표/물음표 정리) 이후 길이가 바뀌지 않으므로 원문 기준 검증 후 정규화한다.
  const content = normalizePunctuation(rawContent);

  try {
    const wish = await prisma.wish.findUnique({ where: { id: dbId } });
    if (!wish || wish.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (!canAccessWish(wish, auth.userId)) {
      return NextResponse.json(
        { success: false, error: "댓글을 남길 수 없는 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // [절대 원칙] 지급 + 생성은 반드시 하나의 $transaction으로 처리한다
    // (fulfilled/route.ts와 동일한 패턴).
    const { comment, grantedAmount } = await prisma.$transaction(async (tx) => {
      // userId는 오직 authenticateRequest()가 결정한 auth.userId만 사용한다.
      const created = await tx.comment.create({
        data: { targetType: "wish", targetId: dbId, userId: auth.userId, content },
        include: { user: { select: { nickname: true } } },
      });

      // 15자 미만은 지급 자체를 스킵한다(작성은 이미 허용됨).
      let granted = 0;
      if (content.length >= COMMENT_MIN_LENGTH_FOR_REWARD) {
        // sourceId=wishId → "같은 소원엔 1회"(ALREADY_GRANTED)와 "1일 3회"
        // (scope=daily, DAILY_LIMIT_REACHED)를 동시에 판정한다.
        const eligibility = await checkPolicyEligibility(tx, auth.userId, WISH_COMMENT_SOURCE_TYPE, {
          scope: "daily",
          sourceId: dbId,
        });
        if (eligibility.eligible) {
          const policy = await tx.pointPolicy.findUnique({
            where: { sourceType: WISH_COMMENT_SOURCE_TYPE },
          });
          const amount = policy?.amount ?? 0;
          if (amount > 0) {
            const outcome = await earnLuckPouch(tx, {
              userId: auth.userId,
              amount,
              sourceType: WISH_COMMENT_SOURCE_TYPE,
              sourceId: dbId,
              memo: "응원 한 마디",
            });
            granted = outcome.grantedAmount;
          }
        }
      }

      return { comment: created, grantedAmount: granted };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wc_${comment.id}`,
          wishId: id,
          authorName: comment.user.nickname,
          text: comment.content,
          createdAt: comment.createdAt.toISOString(),
          isMine: true,
          grantedAmount,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/wishes/:id/comments] 실패:", e);
    return NextResponse.json(
      { success: false, error: "댓글 작성에 실패했습니다." },
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
