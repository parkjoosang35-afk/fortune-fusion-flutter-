// 일반 회원(Flutter 앱) 인증 유틸 — 관리자 세션(src/lib/session.ts, HttpOnly Cookie)과는
// 별도 체계다. Flutter 모바일 앱은 쿠키가 아닌 Bearer 토큰(JWT)을 SharedPreferences에
// 저장해 매 요청 Authorization 헤더로 전달하는 방식이 적합하다(03단계/06단계 §4.1 대응).
//
// [설계결정 - 로드맵④] 정공법(실제 서버 검증) 구축. 리프레시 토큰 없이 access token만
// 발급하고 만료(30일) 시 재로그인을 유도한다(03§9.2 과설계 방지 원칙, MVP 범위).
import "server-only";
import bcrypt from "bcryptjs";
import { SignJWT, jwtVerify } from "jose";

const USER_TOKEN_EXPIRES = "30d";

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) {
  throw new Error("SESSION_SECRET 환경변수가 설정되지 않았습니다.");
}
const encodedKey = new TextEncoder().encode(secretKey);

export interface UserTokenPayload {
  userId: number;
  nickname: string;
  [key: string]: unknown;
}

export async function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, 10);
}

export async function verifyPassword(
  plain: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}

export async function signUserToken(payload: UserTokenPayload): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(USER_TOKEN_EXPIRES)
    .sign(encodedKey);
}

export async function verifyUserToken(
  token: string | undefined | null
): Promise<UserTokenPayload | null> {
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, encodedKey, {
      algorithms: ["HS256"],
    });
    return payload as UserTokenPayload;
  } catch {
    return null;
  }
}

/** `Authorization: Bearer <token>` 헤더에서 유저를 인증한다. 실패 시 null. */
export async function authenticateRequest(
  request: Request
): Promise<UserTokenPayload | null> {
  const header = request.headers.get("authorization") ?? request.headers.get("Authorization");
  if (!header || !header.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length).trim();
  return verifyUserToken(token);
}

/** UserModel(Flutter) DTO 변환 — users + user_profiles(1:1) + user_grades(마스터) 매핑 */
export function toUserDto(user: {
  id: number;
  nickname: string;
  email: string | null;
  gender: string | null;
  grade: { code: string } | null;
  profile: { birthDate: string | null; birthTime: string | null; isLunar: boolean } | null;
}) {
  return {
    id: String(user.id),
    nickname: user.nickname,
    email: user.email,
    birth_date: user.profile?.birthDate ?? null,
    birth_time: user.profile?.birthTime ?? null,
    is_lunar: user.profile?.isLunar ?? false,
    gender: user.gender,
    grade: user.grade?.code ?? "bronze",
  };
}

/**
 * Prisma P2002(unique 제약 위반) 에러에서 어떤 필드가 중복인지 추출한다.
 * 이 프로젝트는 SQLite + driver adapter(better-sqlite3)를 사용하므로 표준 `meta.target`이
 * 아니라 `meta.driverAdapterError.cause.constraint.fields`에 필드명이 담긴다.
 */
export function extractUniqueConstraintFields(e: {
  meta?: Record<string, unknown>;
}): string[] {
  const meta = e.meta as
    | {
        target?: string[];
        driverAdapterError?: { cause?: { constraint?: { fields?: string[] } } };
      }
    | undefined;
  if (meta?.target) return meta.target;
  const fields = meta?.driverAdapterError?.cause?.constraint?.fields;
  return fields ?? [];
}

export function clientIp(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0].trim();
  return "sandbox-dev";
}
