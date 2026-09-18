"use server";

// 관리자 로그인/로그아웃 Server Action
// 05_Admin_System_Design.md §3.10 admin_login_logs 기록, §6 세션 관리 반영
import { z } from "zod";
import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { prisma } from "@/lib/db";
import bcrypt from "bcryptjs";
import { createAdminSession, deleteAdminSession } from "@/lib/session";

/**
 * [Stage2 결함수정 — 결함-H08-01] admin_login_logs.ip_address가 "sandbox-dev"로
 * 하드코딩되어 추적성이 훼손되어 있던 문제를 수정한다. Next.js Server Action에서는
 * Request 객체에 직접 접근할 수 없으므로 `next/headers`의 `headers()`로 프록시가
 * 전달하는 표준 헤더(x-forwarded-for가 최우선, 없으면 x-real-ip)에서 클라이언트
 * IP를 추출한다. 두 헤더 모두 없는 로컬 개발 환경에서는 "unknown"으로 폴백한다
 * (과거처럼 임의 문자열로 위장하지 않고, 정보가 없음을 명시적으로 드러낸다).
 */
async function extractClientIp(): Promise<string> {
  const headerList = await headers();
  const forwardedFor = headerList.get("x-forwarded-for");
  if (forwardedFor) return forwardedFor.split(",")[0].trim();
  const realIp = headerList.get("x-real-ip");
  if (realIp) return realIp.trim();
  return "unknown";
}

const LoginSchema = z.object({
  email: z.string().min(1, { message: "이메일(ID)을 입력해주세요." }),
  password: z.string().min(1, { message: "비밀번호를 입력해주세요." }),
});

export interface LoginFormState {
  error?: string;
}

export async function login(
  _prevState: LoginFormState,
  formData: FormData
): Promise<LoginFormState> {
  const parsed = LoginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!parsed.success) {
    return { error: "이메일과 비밀번호를 모두 입력해주세요." };
  }

  const { email, password } = parsed.data;

  const adminUser = await prisma.adminUser.findUnique({
    where: { email },
    include: { role: true },
  });

  const passwordOk = adminUser
    ? await bcrypt.compare(password, adminUser.passwordHash)
    : false;

  // 04A B-4 admin_login_logs: 성공/실패 모두 기록 (Append-only)
  if (adminUser) {
    const clientIp = await extractClientIp();
    await prisma.adminLoginLog.create({
      data: {
        adminUserId: adminUser.id,
        ipAddress: clientIp,
        successFlag: passwordOk,
      },
    });
  }

  if (!adminUser || !passwordOk) {
    return { error: "이메일 또는 비밀번호가 올바르지 않습니다." };
  }

  if (adminUser.status !== "active") {
    return { error: "비활성화된 계정입니다. 관리자에게 문의해주세요." };
  }

  await prisma.adminUser.update({
    where: { id: adminUser.id },
    data: { lastLoginAt: new Date() },
  });

  await createAdminSession({
    adminUserId: adminUser.id,
    email: adminUser.email,
    name: adminUser.name,
    roleCode: adminUser.role.code,
  });

  redirect("/dashboard");
}

export async function logout() {
  await deleteAdminSession();
  redirect("/login");
}
