"use server";

// 관리자 로그인/로그아웃 Server Action
// 05_Admin_System_Design.md §3.10 admin_login_logs 기록, §6 세션 관리 반영
import { z } from "zod";
import { redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import bcrypt from "bcryptjs";
import { createAdminSession, deleteAdminSession } from "@/lib/session";

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
    await prisma.adminLoginLog.create({
      data: {
        adminUserId: adminUser.id,
        ipAddress: "sandbox-dev", // 실제 배포 환경에서는 요청 헤더에서 추출 필요
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
