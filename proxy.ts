// Next.js 16 Proxy (구 Middleware) — 낙관적 인증 체크
// 05_Admin_System_Design.md §3.1 "전면 CSR + 인증 게이트" 반영
// 08_Web_Design.md §3.5 관리자 인증(HttpOnly Cookie) 반영
//
// 주의: Proxy는 매 요청(프리페치 포함)마다 실행되므로 DB 조회 없이
// 쿠키의 세션 유효성만 낙관적으로 확인한다(Next.js 공식 가이드 패턴).
// 실제 권한(RBAC) 검증은 각 페이지/서버액션에서 verifyAdminSession()으로 재검증한다.
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { decryptSession, SESSION_COOKIE_NAME } from "@/lib/session";

const PUBLIC_ROUTES = ["/login"];

export default async function proxy(req: NextRequest) {
  const path = req.nextUrl.pathname;
  const isPublicRoute = PUBLIC_ROUTES.includes(path);

  const cookie = req.cookies.get(SESSION_COOKIE_NAME)?.value;
  const session = await decryptSession(cookie);

  if (!isPublicRoute && !session?.adminUserId) {
    return NextResponse.redirect(new URL("/login", req.nextUrl));
  }

  if (isPublicRoute && session?.adminUserId) {
    return NextResponse.redirect(new URL("/dashboard", req.nextUrl));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
