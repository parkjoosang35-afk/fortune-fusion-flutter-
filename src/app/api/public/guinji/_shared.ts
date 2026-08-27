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
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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
