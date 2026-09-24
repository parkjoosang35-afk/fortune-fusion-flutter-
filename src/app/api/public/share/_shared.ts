// 결과 공유(Share) 공개 API 공용 헬퍼 — sintong-share-proposal.pdf 대응.
//
// [설계 원칙] guinji/_shared.ts, wishes/_shared.ts와 동일한 프로젝트 컨벤션을
// 따른다: requireUser()는 JWT Bearer 인증(서버최종판단), CORS_HEADERS는
// 공개 API 공통, publicId 포맷은 접두사+숫자(`sr_${id}`류)가 아니라 이
// 도메인 특성상 곧 shareId 자체가 공개 식별자이므로 별도 인코딩이 필요
// 없다(shareId는 이미 crypto 랜덤 문자열).
import { NextResponse } from "next/server";
import { randomBytes } from "crypto";
import { authenticateRequest } from "@/lib/user-auth";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export const CORS_HEADERS_WITH_AUTH = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/** 5종 결과 타입 화이트리스트. 이 외 값은 400으로 거부한다. */
export const SHARE_RESULT_TYPES = [
  "fortune",
  "tarot",
  "face",
  "palm",
  "wish",
] as const;
export type ShareResultType = (typeof SHARE_RESULT_TYPES)[number];

export function isValidResultType(v: unknown): v is ShareResultType {
  return typeof v === "string" && (SHARE_RESULT_TYPES as readonly string[]).includes(v);
}

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

/**
 * [보안 원칙 — NFR-03] shareId는 이 링크에 대한 유일한 접근 통제 수단이므로
 * 비순차·추측 불가능해야 한다. 혼동되기 쉬운 문자(0/O, 1/l/I)를 제외한
 * 32자 알파벳으로 10자리를 생성한다(62^10 조합에 준하는 충돌 저항성).
 * crypto.randomBytes 기반이라 guinji generateGuinjiToken()과 동일한
 * 신뢰 수준을 가진다.
 */
const SHARE_ID_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ";
export function generateShareId(length = 10): string {
  const bytes = randomBytes(length);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += SHARE_ID_ALPHABET[bytes[i] % SHARE_ID_ALPHABET.length];
  }
  return out;
}

/**
 * [개인정보 원칙] payload에 대한 문자열 길이 상한. 과도하게 큰 payload를
 * 막아 DB 부하 및 실수로 원본 민감정보(사진 base64 등)가 통째로 들어가는
 * 사고를 1차 방어한다(가벼운 화이트리스트 표시값만 들어와야 정상).
 */
export const SHARE_PAYLOAD_MAX_LENGTH = 4000;
export const SHARE_TITLE_MAX_LENGTH = 60;
export const SHARE_DESCRIPTION_MAX_LENGTH = 120;
