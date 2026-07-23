// 관리자 세션 관리 (Stateless Session, HttpOnly Cookie 기반)
// 기준: 05_Admin_System_Design.md §3.5 "HttpOnly Cookie, 30분 idle timeout"
// 08_Web_Design.md §3.5 관리자 인증 방식
import "server-only";
import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

const SESSION_COOKIE_NAME = "admin_session";
// 05_Admin_System_Design.md §6: "관리자 세션 타임아웃: 30분 비활동 시 자동 로그아웃"
const SESSION_IDLE_TIMEOUT_MINUTES = 30;

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) {
  throw new Error("SESSION_SECRET 환경변수가 설정되지 않았습니다.");
}
const encodedKey = new TextEncoder().encode(secretKey);

export interface AdminSessionPayload {
  adminUserId: number;
  email: string;
  name: string;
  roleCode: string; // super_admin / operator / cs / content_manager
  [key: string]: unknown;
}

export async function encryptSession(payload: AdminSessionPayload) {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${SESSION_IDLE_TIMEOUT_MINUTES}m`)
    .sign(encodedKey);
}

export async function decryptSession(
  session: string | undefined = ""
): Promise<AdminSessionPayload | null> {
  if (!session) return null;
  try {
    const { payload } = await jwtVerify(session, encodedKey, {
      algorithms: ["HS256"],
    });
    return payload as AdminSessionPayload;
  } catch {
    return null;
  }
}

/**
 * 로그인 성공 시 세션 쿠키 생성.
 * 30분 idle timeout을 위해 매 요청마다 updateSession()으로 만료시간을 갱신한다.
 */
export async function createAdminSession(payload: AdminSessionPayload) {
  const session = await encryptSession(payload);
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE_NAME, session, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: SESSION_IDLE_TIMEOUT_MINUTES * 60,
    path: "/",
  });
}

/** 비활동 타임아웃 갱신(활동이 있을 때마다 만료시간을 뒤로 미룸) */
export async function refreshAdminSession() {
  const cookieStore = await cookies();
  const raw = cookieStore.get(SESSION_COOKIE_NAME)?.value;
  const payload = await decryptSession(raw);
  if (!payload) return null;

  const refreshed = await encryptSession({
    adminUserId: payload.adminUserId,
    email: payload.email,
    name: payload.name,
    roleCode: payload.roleCode,
  });

  cookieStore.set(SESSION_COOKIE_NAME, refreshed, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: SESSION_IDLE_TIMEOUT_MINUTES * 60,
    path: "/",
  });

  return payload;
}

export async function getAdminSession(): Promise<AdminSessionPayload | null> {
  const cookieStore = await cookies();
  const raw = cookieStore.get(SESSION_COOKIE_NAME)?.value;
  return decryptSession(raw);
}

export async function deleteAdminSession() {
  const cookieStore = await cookies();
  cookieStore.delete(SESSION_COOKIE_NAME);
}

export { SESSION_COOKIE_NAME };
