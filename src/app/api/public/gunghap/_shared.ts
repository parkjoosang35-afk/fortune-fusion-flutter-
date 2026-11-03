// 궁합지도(Gunghap Map) 공개 API 공용 헬퍼.
//
// [신통방통 궁합지도 개발 지시서 §6-2 "귀인지도 및 회원·복주머니 시스템과의
// 충돌 여부 확인" 통과 후 진행] 이 파일은 귀인지도 `guinji/_shared.ts`의
// 검증된 패턴(JWT Bearer 인증, CORS 헤더, 공개ID 인코딩, 토큰 발급)을
// "그대로 복사해 동일 로직으로 재사용"한다 — 기존 `guinji/_shared.ts`는
// 1바이트도 수정하지 않는다(개발 원칙 "기존 서비스 기능을 임의로 변경하지
// 않는다", 이번 단계 금지사항 "기존 귀인지도 API 수정").
//
// [토큰 추측 불가능성] `generateGunghapToken()`은 귀인지도와 동일하게
// `crypto.randomBytes(12)` → base64url(16자)을 사용한다. Node.js
// crypto.randomBytes는 CSPRNG(암호학적으로 안전한 난수 생성기)이므로
// 추측이 사실상 불가능하다(16자 base64url ≈ 96bit 엔트로피).
import { randomBytes } from "crypto";
import { NextResponse } from "next/server";
import { authenticateRequest } from "@/lib/user-auth";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export const CORS_HEADERS_WITH_AUTH = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/** `Authorization: Bearer <JWT>` 헤더로 로그인 사용자를 확정한다. */
export async function requireUser(
  request: Request,
): Promise<{ userId: number; nickname: string } | null> {
  const payload = await authenticateRequest(request);
  if (!payload) return null;
  return { userId: payload.userId, nickname: payload.nickname };
}

export function unauthorizedResponse() {
  return NextResponse.json(
    { success: false, error: "로그인이 필요합니다." },
    { status: 401, headers: CORS_HEADERS },
  );
}

/** Flutter 공개 ID 포맷 — 귀인지도 `gm_${id}`/`m_${id}` 패턴과 동일 원칙. */
export function toGunghapResultPublicId(dbId: number): string {
  return `gr_${dbId}`;
}

export function parseGunghapResultDbId(publicId: string): number | null {
  const match = /^gr_(\d+)$/.exec(publicId);
  if (!match) return null;
  return Number(match[1]);
}

/**
 * 궁합지도 초대 토큰 발급 — `crypto.randomBytes(12)` → base64url(16자).
 * 귀인지도 `generateGuinjiToken()`과 완전히 동일한 방식(추측 불가능한
 * CSPRNG 기반)이다. 별도 파일로 복제하는 이유는 "기존 귀인지도 파일 수정
 * 금지" 원칙 때문이며, 로직 자체의 차이는 없다.
 */
export function generateGunghapToken(): string {
  return randomBytes(12).toString("base64url");
}

/** KST 기준 "오늘" 날짜 키 — 귀인지도 `todayKstDateKey()`와 동일 규칙. */
export function todayKstDateKey(): string {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}
