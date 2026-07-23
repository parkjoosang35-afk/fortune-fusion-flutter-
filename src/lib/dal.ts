// Data Access Layer — 관리자 세션 검증 공용 함수
// Next.js 공식 가이드 패턴(app/lib/dal.ts) 준수: 데이터 요청 직전 항상 verifySession() 호출
import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { getAdminSession } from "@/lib/session";

export const verifyAdminSession = cache(async () => {
  const session = await getAdminSession();
  if (!session?.adminUserId) {
    redirect("/login");
  }
  return session;
});
