// 복주머니 쿠폰 "제휴업체" 전용 세션 관리 (Stateless Session, HttpOnly Cookie 기반).
// 기존 admin 세션(src/lib/session.ts)과 완전히 별개 체계다 — 제휴업체는 회원도
// 관리자도 아니므로 AdminUser/User 인증 경로를 그대로 쓰면 권한 경계가 섞인다.
// 패턴은 session.ts를 그대로 따른다(동일 SESSION_SECRET 재사용 — 신규 env 추가 없이
// "정책 불일치 금지" 원칙 유지).
import "server-only";
import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const PARTNER_SESSION_COOKIE_NAME = "bokju_partner_session";
const PARTNER_SESSION_IDLE_TIMEOUT_MINUTES = 30;

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) {
  throw new Error("SESSION_SECRET 환경변수가 설정되지 않았습니다.");
}
const encodedKey = new TextEncoder().encode(secretKey);

export interface PartnerSessionPayload {
  partnerId: number;
  accountId: number;
  loginId: string;
  role: "PARTNER_ADMIN" | "PARTNER_STAFF";
  [key: string]: unknown;
}

export async function encryptPartnerSession(payload: PartnerSessionPayload) {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${PARTNER_SESSION_IDLE_TIMEOUT_MINUTES}m`)
    .sign(encodedKey);
}

export async function decryptPartnerSession(
  session: string | undefined = ""
): Promise<PartnerSessionPayload | null> {
  if (!session) return null;
  try {
    const { payload } = await jwtVerify(session, encodedKey, { algorithms: ["HS256"] });
    return payload as PartnerSessionPayload;
  } catch {
    return null;
  }
}

export async function createPartnerSession(payload: PartnerSessionPayload) {
  const session = await encryptPartnerSession(payload);
  const cookieStore = await cookies();
  cookieStore.set(PARTNER_SESSION_COOKIE_NAME, session, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: PARTNER_SESSION_IDLE_TIMEOUT_MINUTES * 60,
    path: "/",
  });
}

export async function getPartnerSession(): Promise<PartnerSessionPayload | null> {
  const cookieStore = await cookies();
  const raw = cookieStore.get(PARTNER_SESSION_COOKIE_NAME)?.value;
  return decryptPartnerSession(raw);
}

export async function deletePartnerSession() {
  const cookieStore = await cookies();
  cookieStore.delete(PARTNER_SESSION_COOKIE_NAME);
}

/** API Route Handler에서 바로 쓰는 401 변환 버전(admin의 requireAdminOrResponse와 동일 패턴). */
export async function requirePartnerOrResponse(): Promise<PartnerSessionPayload | NextResponse> {
  const session = await getPartnerSession();
  if (!session) {
    return NextResponse.json(
      { success: false, error: "업체 로그인이 필요합니다." },
      { status: 401, headers: { "Access-Control-Allow-Origin": "*" } }
    );
  }
  return session;
}

export function isPartnerSession(v: PartnerSessionPayload | NextResponse): v is PartnerSessionPayload {
  return !(v instanceof NextResponse);
}

export { PARTNER_SESSION_COOKIE_NAME };
