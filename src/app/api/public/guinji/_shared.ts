// 귀인지도(Guinji Map) 공개 API 공용 헬퍼 — DTO 변환 + 인증 + 토큰 발급.
//
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6] API 계약 10종이 공유하는
// 유틸을 모은다. wishes/_shared.ts와 동일하게 requireUser()는 JWT
// Bearer 인증(서버최종판단 원칙)을 강제한다 — luckybag/attendance 등
// 구버전 라우트의 `body.userId` 신뢰 패턴은 채택하지 않는다.
import { randomBytes } from "crypto";
import { NextResponse } from "next/server";
import { authenticateRequest } from "@/lib/user-auth";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export const CORS_HEADERS_WITH_AUTH = {
  "Access-Control-Allow-Origin": "*",
  // [2026-11 멤버 삭제 기능] DELETE 메서드 추가 — 소유자가 잘못 입력된
  // 멤버를 지우는 DELETE /guinji/maps/{mapId}/members/{memberId} API용.
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/**
 * `Authorization: Bearer <JWT>` 헤더로 로그인 사용자를 확정한다.
 * 귀인지도는 "내 지도" 소유 개념이 핵심이라 모든 엔드포인트가 로그인을
 * 요구한다(wishes GET처럼 비로그인 허용하는 케이스 없음).
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

/** Flutter GuinjiMapMember.id 공개 포맷 — wishes의 `w_${id}` 패턴을 따른다. */
export function toGuinjiMemberPublicId(dbId: number): string {
  return `m_${dbId}`;
}

export function parseGuinjiMemberDbId(publicId: string): number | null {
  const match = /^m_(\d+)$/.exec(publicId);
  if (!match) return null;
  return Number(match[1]);
}

export function toGuinjiMapPublicId(dbId: number): string {
  return `gm_${dbId}`;
}

export function parseGuinjiMapDbId(publicId: string): number | null {
  const match = /^gm_(\d+)$/.exec(publicId);
  if (!match) return null;
  return Number(match[1]);
}

/**
 * 공유 초대 토큰 발급. `crypto.randomBytes` 기반 URL-safe 임의 문자열(12
 * bytes → 16자 base64url, 충돌 가능성 사실상 0에 가까움 — 만약 unique
 * 제약에 걸리면 호출부에서 재시도한다).
 */
export function generateGuinjiToken(): string {
  return randomBytes(12).toString("base64url");
}

/**
 * KST 기준 "오늘" 날짜 키("YYYY-MM-DD") — open-pass-service.ts의 todayKstKey()와
 * 동일한 절단 규칙(절대원칙: KST 자정 기준). unlock_record.dateKey(일 5회 한도
 * 집계 기준)에 사용한다.
 */
export function todayKstDateKey(): string {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/**
 * [DEAD CODE — 귀인지도 초대링크 재발급 v1.1, 2026 Phase] 더 이상 호출되지
 * 않는다. 삭제하지 말고 미사용 상태로 보존한다(롤백 여지 확보 — 지시서
 * v1.1 §D1 C2 합의사항).
 *
 * [폐기 경위] 원래 이 값은 7일이었는데, Flutter 앱 공유 화면
 * (`guinji_map_share_screen.dart`)의 안내 문구는 처음부터 "링크는 30일간
 * 유효해요"로 표시되고 있었다 — 즉 서버와 클라이언트 문구가 불일치하는
 * 라이브 버그였다(2026-09 실사용자 리포트로 발견, 임시조치로 서버값을
 * 30일로 맞춘 적이 있었음). v1.1 지시서는 이 불일치를 근본적으로
 * 해소하기 위해 "만료" 개념 자체를 제거하기로 결정했다 — 링크는 소유자가
 * `revoked` 상태로 명시적으로 중단하지 않는 한 무기한 유효하다
 * (`GuinjiMap.inviteStatus` 참고). 화면 카피도 숫자(N일) 없이
 * "만료 없음"으로 통일했다(카피/상수 불일치 재발 방지).
 */
export const GUINJI_INVITE_EXPIRY_DAYS = 30;

export function isGuinjiInviteExpired(mapCreatedAt: Date): boolean {
  const expiresAt = new Date(mapCreatedAt.getTime() + GUINJI_INVITE_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
  return new Date() > expiresAt;
}
