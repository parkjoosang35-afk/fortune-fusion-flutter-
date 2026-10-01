// 소원방(WishRoom) v2.6 공개 API 공용 헬퍼 — 인증/CORS/ID 변환/에러 응답.
//
// [재사용 원칙] 인증(requireUser)과 CORS_HEADERS, unauthorizedResponse는 기존
// wishes/_shared.ts(소원성 "Wish Wall" 도메인)의 것을 그대로 재사용한다 — JWT 인증
// 로직은 도메인과 무관하므로 중복 구현하지 않는다(shop/purchase/route.ts가 이미
// 같은 방식으로 재사용하고 있는 기존 관례를 따름).
//
// [에러 계약] Flutter wr_api.dart의 ApiRepository._req()는 다음을 기대한다:
//   decoded['success'] === false 이면 throw ApiError(status, code, error|message, decoded)
//   성공 시 decoded['data'] ?? decoded 를 그대로 사용.
// 따라서 모든 wishroom 라우트는 성공 시 { success: true, data: {...} },
// 실패 시 { success: false, error: "...", code: "...", ...extra } 형태로 응답해야 한다.
// wishroom-engine.ts의 WishRoomError(status, code, message, extra)를 toErrorResponse()로
// 그대로 변환하면 이 계약이 자동으로 맞춰진다.
import { NextResponse } from "next/server";
import type { Prisma } from "@/generated/prisma/client";
import { WishRoomError, checkRateLimit } from "@/lib/wishroom-engine";

type Tx = Prisma.TransactionClient;

export {
  requireUser,
  unauthorizedResponse,
  CORS_HEADERS,
} from "../wishes/_shared";

/** Flutter WishRoom.id 포맷 — `wr_{dbId}` (기존 Wish 도메인의 `w_{dbId}`와 구분, PK 충돌 방지). */
export function toWishRoomPublicId(dbId: number): string {
  return `wr_${dbId}`;
}

export function parseWishRoomDbId(publicId: string): number | null {
  const match = /^wr_(\d+)$/.exec(publicId);
  if (!match) return null;
  return Number(match[1]);
}

/** OPTIONS 프리플라이트 공용 응답(shop/purchase/route.ts 패턴과 동일). */
export function wishroomOptionsResponse() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}

/**
 * WishRoomError를 Flutter ApiError 계약에 맞는 NextResponse로 변환한다.
 * WishRoomError가 아닌 예외(예상치 못한 버그)는 500/UNKNOWN으로 감싸되,
 * 서버 로그에는 원본 스택을 남긴다.
 */
export function toErrorResponse(e: unknown) {
  if (e instanceof WishRoomError) {
    return NextResponse.json(
      { success: false, error: e.message, code: e.code, ...e.extra },
      { status: e.status, headers: CORS_HEADERS_LOCAL }
    );
  }
  // eslint-disable-next-line no-console
  console.error("[wishroom] unexpected error:", e);
  return NextResponse.json(
    { success: false, error: "잠시 후 다시 시도해주세요", code: "UNKNOWN" },
    { status: 500, headers: CORS_HEADERS_LOCAL }
  );
}

// _shared.ts 재export와 별개로 로컬에서도 값이 필요해 동일 리터럴을 유지한다
// (순환 import 방지를 위해 상수 값만 복제 — wishes/_shared.ts와 항상 동일하게 유지할 것).
const CORS_HEADERS_LOCAL = { "Access-Control-Allow-Origin": "*" };

/**
 * 분당 요청 제한(rateLimit, app/api.js 포팅) — WishRoomActionLog에 영속 기록하고
 * 최근 60초 이내 건수를 검사한다. 트랜잭션 안에서 호출하는 것을 전제로 한다.
 * 초과 시 WishRoomError(429, 'RATE_LIMIT', ...)를 throw한다(호출부는 그대로
 * toErrorResponse로 변환하면 됨).
 */
export async function enforceRateLimitAndLog(
  tx: Tx,
  userId: number,
  action: string,
  nowMs: number = Date.now()
): Promise<void> {
  const since = new Date(nowMs - 60_000);
  const recent = await tx.wishRoomActionLog.findMany({
    where: { userId, action, createdAt: { gte: since } },
    select: { createdAt: true },
  });
  checkRateLimit(
    recent.map((r) => r.createdAt.getTime()),
    nowMs
  );
  await tx.wishRoomActionLog.create({ data: { userId, action } });
}

/**
 * 내가 차단한 상대 / 나를 차단한 상대의 id 목록을 조회한다.
 * explore·comments 등에서 숨김 처리할 때 사용(양방향 차단 — 04A 04B 일반 관례).
 */
export async function getBlockedUserIds(tx: Tx, userId: number): Promise<Set<number>> {
  const [blockedByMe, blockedMe] = await Promise.all([
    tx.wishRoomBlock.findMany({ where: { blockerId: userId }, select: { blockedId: true } }),
    tx.wishRoomBlock.findMany({ where: { blockedId: userId }, select: { blockerId: true } }),
  ]);
  const set = new Set<number>();
  blockedByMe.forEach((b) => set.add(b.blockedId));
  blockedMe.forEach((b) => set.add(b.blockerId));
  return set;
}
