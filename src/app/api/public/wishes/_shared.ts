// 소원방(Wish Wall) 공개 API 공용 헬퍼 — DTO 변환 + 인증 유틸.
//
// [작업6-1] 소원방 실제 API/서버 구축. Flutter WishWallRepository의
// fetchFeed/fetchDetail/createWish/support/incrementPouch/fetchMyWishes에
// 대응하는 8개 엔드포인트가 이 파일의 toWishDto()/requireUser()를 공유한다.
//
// [사용자 확정 원칙]
// - Wish/WishBokju/WishConfig/WishReview 기존 Prisma 모델 그대로 사용(재설계 금지).
// - 작성자(userId)는 반드시 서버가 JWT(Authorization: Bearer)로 결정한다.
//   클라이언트가 body/query로 보낸 userId는 절대 신뢰하지 않는다.
// - pray(기도)는 이번 단계에서 DB 저장/전용 API 없음(Flutter UI 피드백만).
// - support 중복 방지는 이번 단계에서 구현하지 않는다(근거 테이블 없음 확인됨).
import { NextResponse } from "next/server";
import { authenticateRequest } from "@/lib/user-auth";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** Flutter WishPost.id 포맷 — 기존 community posts의 `cp_${id}` 패턴을 따른다. */
export function toWishPublicId(dbId: number): string {
  return `w_${dbId}`;
}

export function parseWishDbId(publicId: string): number | null {
  const match = /^w_(\d+)$/.exec(publicId);
  if (!match) return null;
  return Number(match[1]);
}

/**
 * `Authorization: Bearer <JWT>` 헤더로 로그인 사용자를 확정한다.
 * 실패 시 null을 반환하며, 호출부가 401 응답 여부를 결정한다(GET 계열은
 * 비로그인 열람을 허용하므로 null이어도 계속 진행 가능).
 */
export async function requireUser(
  request: Request
): Promise<{ userId: number; nickname: string } | null> {
  const payload = await authenticateRequest(request);
  if (!payload) return null;
  return { userId: payload.userId, nickname: payload.nickname };
}

export function unauthorizedResponse() {
  return NextResponse.json(
    { success: false, error: "로그인이 필요합니다." },
    { status: 401, headers: CORS_HEADERS }
  );
}

/** WishPost.glassLevel(0.0~1.0, 클라이언트 표시용)을 Wish.candleLevel(Int 0~4)로 근사 매핑한다.
 * candleLevel 필드는 schema 주석상 "서버 계산 캐시"이나 현재 admin_web 어디서도 실제
 * 계산 로직이 없어(전체 코드 검색 결과 0건) 이 매핑이 유일한 활용처가 된다.
 * 스키마 변경 없이 기존 Int 필드 의미 안에서 사용한다.
 */
export function glassLevelToCandleLevel(glassLevel: number): number {
  const clamped = Math.max(0, Math.min(1, glassLevel));
  return Math.round(clamped * 4);
}

/** candleLevel(Int 0~4)을 Flutter glassLevel(double 0.0~1.0)로 역매핑한다. */
export function candleLevelToGlassLevel(candleLevel: number): number {
  return Math.max(0, Math.min(4, candleLevel)) / 4;
}

export interface WishRow {
  id: number;
  userId: number;
  content: string;
  category: string;
  isAnonymous: boolean;
  supportCount: number;
  goalTag: string | null;
  status: string;
  candleLevel: number;
  bokjuCount: number;
  isMilestoneShown: boolean;
  achievedAt: Date | null;
  highlightedUntil: Date | null;
  boostedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
  user: { nickname: string };
}

/**
 * Wish(Prisma row) → Flutter WishPost 대응 DTO.
 *
 * [주의] Flutter WishPost는 prayerCount 필드를 갖지만, 이번 단계에서 기도는
 * DB에 저장하지 않기로 확정되었으므로 항상 0을 반환한다(추후 정식 정책 확정 시
 * 필드를 추가하지 않고 이 DTO 매핑만 갱신하면 되도록 설계).
 * visibility(anonymous/public/private)는 Prisma에 별도 필드가 없어
 * isAnonymous + status로 근사 매핑한다(private 소원은 status='private_only'로
 * 구분 — 신규 필드/스키마 변경 없이 기존 status 문자열 컬럼의 값 종류만 확장).
 */
export function toWishDto(w: WishRow, currentUserId: number | null) {
  const visibility =
    w.status === "private_only"
      ? "private"
      : w.isAnonymous
        ? "anonymous"
        : "public";
  return {
    id: toWishPublicId(w.id),
    authorId: String(w.userId),
    authorName: w.isAnonymous ? "익명" : w.user.nickname,
    isAnonymous: w.isAnonymous,
    categoryId: w.category,
    text: w.content,
    glassLevel: candleLevelToGlassLevel(w.candleLevel),
    visibility,
    // [매핑 근거] Prisma achievedAt(최종레벨 도달 시각)이 있으면 "감사 기록"으로
    // 간주한다. isMilestoneShown(연출 1회 노출 플래그)은 의미가 달라 사용하지 않는다.
    isGratitude: w.achievedAt != null,
    createdAt: w.createdAt.toISOString(),
    supportCount: w.supportCount,
    prayerCount: 0,
    pouchCount: w.bokjuCount,
    isMine: currentUserId != null && w.userId === currentUserId,
    goalTag: w.goalTag,
  };
}

export const WISH_VISIBLE_WHERE = {
  status: { in: ["visible", "gratitude"] },
  deletedAt: null,
} as const;
