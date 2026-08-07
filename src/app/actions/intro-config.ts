"use server";

// 인트로(첫 진입 4단계: 스플래시/카드1/카드2/시작화면) 설정 Server Action.
// [인트로 전면 개편] IntroConfig는 싱글턴 row(id=1)이며, "자유 배치/좌표/애니메이션
// 수치"는 제공하지 않고 운영에 필요한 최소 항목(on/off, 문구, 이미지 URL, 보상 수량)만
// 수정 가능하게 한다. 회원가입 보상 "수량"은 PointPolicy(sourceType="signup_reward")가
// 실제 지급 기준의 단일 소스이므로, 저장 시 두 값을 함께 갱신해 정합성을 유지한다
// (§자동 정합성 처리 — "관리자에서 문구 수정이 안 먹으면 API/상태 연결").
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canWriteCms(roleCode: string): boolean {
  return canWriteMenu(roleCode, "cms");
}

const UpdateSchema = z.object({
  isEnabled: z.boolean(),
  showOnlyFirstLaunch: z.boolean(),
  showSkipButton: z.boolean(),
  showGuestHint: z.boolean(),
  splashTitle: z.string().min(1).max(30),
  splashSubtitle: z.string().max(60).optional().nullable(),
  card1Title: z.string().min(1).max(60),
  card1Description: z.string().min(1).max(200),
  card1ImageUrl: z.string().max(500).optional().nullable(),
  card2Title: z.string().min(1).max(60),
  card2Description: z.string().min(1).max(200),
  card2ImageUrl: z.string().max(500).optional().nullable(),
  ctaTitle: z.string().min(1).max(60),
  ctaSubtitle: z.string().min(1).max(120),
  signupRewardText: z.string().min(1).max(80),
  signupRewardAmount: z.coerce.number().int().min(0).max(100000),
});

export interface IntroConfigFormState {
  error?: string;
  success?: boolean;
}

function s(v: FormDataEntryValue | null): string | undefined {
  if (v == null) return undefined;
  const str = String(v).trim();
  return str.length > 0 ? str : undefined;
}

export async function updateIntroConfig(
  _prevState: IntroConfigFormState,
  formData: FormData
): Promise<IntroConfigFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateSchema.safeParse({
    isEnabled: formData.get("isEnabled") === "on",
    showOnlyFirstLaunch: formData.get("showOnlyFirstLaunch") === "on",
    showSkipButton: formData.get("showSkipButton") === "on",
    showGuestHint: formData.get("showGuestHint") === "on",
    splashTitle: s(formData.get("splashTitle")) ?? "",
    splashSubtitle: s(formData.get("splashSubtitle")),
    card1Title: s(formData.get("card1Title")) ?? "",
    card1Description: s(formData.get("card1Description")) ?? "",
    card1ImageUrl: s(formData.get("card1ImageUrl")),
    card2Title: s(formData.get("card2Title")) ?? "",
    card2Description: s(formData.get("card2Description")) ?? "",
    card2ImageUrl: s(formData.get("card2ImageUrl")),
    ctaTitle: s(formData.get("ctaTitle")) ?? "",
    ctaSubtitle: s(formData.get("ctaSubtitle")) ?? "",
    signupRewardText: s(formData.get("signupRewardText")) ?? "",
    signupRewardAmount: formData.get("signupRewardAmount"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;

  const before = await prisma.introConfig.findUnique({ where: { id: 1 } });

  const updated = await prisma.introConfig.upsert({
    where: { id: 1 },
    create: { id: 1, ...data, updatedBy: session.email },
    update: { ...data, updatedBy: session.email },
  });

  // [정합성] 인트로 화면에 노출되는 가입 보상 수량과 실제 지급 정책(PointPolicy)을
  // 항상 동일하게 유지한다 — 문구만 바꾸고 실제 지급액이 안 바뀌는 불일치 방지.
  await prisma.pointPolicy.upsert({
    where: { sourceType: "signup_reward" },
    create: { sourceType: "signup_reward", amount: data.signupRewardAmount, dailyLimit: 1, isActive: true },
    update: { amount: data.signupRewardAmount, updatedBy: session.email },
  });

  await prisma.pageAuditLog.create({
    data: {
      adminId: session.email,
      pageKey: "intro_config",
      actionType: "update",
      summary: "인트로(첫 진입) 설정 수정",
      payload: JSON.stringify({ before, after: updated }),
    },
  });

  revalidatePath("/cms/intro-config");
  return { success: true };
}
