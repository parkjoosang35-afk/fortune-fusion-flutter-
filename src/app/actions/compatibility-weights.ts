"use server";

// 매칭/궁합 관리 — 궁합 요소 가중치 설정 Server Actions
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 04A F-3 compatibility_factor_weights.
// 스펙: "궁합 요소 가중치 설정 | compatibility_factor_weights(사주/MBTI/취미/가치관/
//   활동패턴 다차원 가중치) — 정책 수치를 관리자가 직접 조정 가능, 04A F도메인
//   설계 취지 반영" — §3.6 6개 화면 중 유일하게 write가 필요한 화면.
// [범위 결정] 04A F-3은 factor_type이 UQ이며 5종 화이트리스트(saju/mbti/
//   interest/value/activity_pattern)로 고정되어 있어, 신규 생성/삭제 UI는
//   불필요하다(초기 시딩으로 5건 고정, 이후 weight 수치 조정과 is_active
//   토글만 관리자가 수행). 따라서 updateFactorWeight(수치 조정) +
//   toggleFactorWeightActive(활성/비활성, banners.ts 토글 패턴 재사용)
//   2개 Server Action만 구현한다.
// [weight "합 1.00 권장" 검증] 04A 원문이 "권장"(hard constraint 아님)이므로
//   서버 액션에서 강제 거부하지 않는다. 단, 저장 후 활성 항목 합계가 1.00에서
//   벗어나면 FormState.warning으로 경고 메시지를 반환하여 관리자에게 알린다
//   (원칙② 설계충돌 방지 — 04A 원문 "권장" 표현을 그대로 존중).
// [RBAC] matching.ts의 canWriteMatching과 동일 원칙(cs 제외, super_admin/operator만 write).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

export interface CompatibilityWeightFormState {
  error?: string;
  success?: boolean;
  warning?: string;
}

const REVALIDATE_PATH = "/matching/compatibility-weights";

function canWriteMatching(roleCode: string): boolean {
  return canWriteMenu(roleCode, "matching");
}

async function buildWeightSumWarning(): Promise<string | undefined> {
  const activeWeights = await prisma.compatibilityFactorWeight.findMany({
    where: { isActive: true, deletedAt: null },
  });
  const sum = activeWeights.reduce((acc, w) => acc + w.weight, 0);
  // 부동소수점 오차 감안(0.01 이내 허용)
  if (Math.abs(sum - 1.0) > 0.01) {
    return `활성 요소 가중치 합계가 ${sum.toFixed(2)}로 04A 권장값(1.00)에서 벗어났습니다. 확인해주세요.`;
  }
  return undefined;
}

const UpdateWeightSchema = z.object({
  id: z.coerce.number().int().positive(),
  weight: z.coerce.number().min(0, "가중치는 0 이상이어야 합니다.").max(1, "가중치는 1 이하여야 합니다."),
});

export async function updateFactorWeight(
  _prevState: CompatibilityWeightFormState,
  formData: FormData
): Promise<CompatibilityWeightFormState> {
  const session = await verifyAdminSession();
  if (!canWriteMatching(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateWeightSchema.safeParse({
    id: formData.get("id"),
    weight: formData.get("weight"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, weight } = parsed.data;

  const before = await prisma.compatibilityFactorWeight.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 궁합 요소입니다." };
  }

  await prisma.compatibilityFactorWeight.update({
    where: { id },
    data: { weight, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "compatibility_factor_weight",
      targetId: id,
      before: JSON.stringify({ weight: before.weight }),
      after: JSON.stringify({ weight }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  const warning = await buildWeightSumWarning();
  return { success: true, warning };
}

const ToggleActiveSchema = z.object({
  id: z.coerce.number().int().positive(),
  isActive: z.coerce.boolean(),
});

export async function toggleFactorWeightActive(
  _prevState: CompatibilityWeightFormState,
  formData: FormData
): Promise<CompatibilityWeightFormState> {
  const session = await verifyAdminSession();
  if (!canWriteMatching(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleActiveSchema.safeParse({
    id: formData.get("id"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id, isActive } = parsed.data;

  const before = await prisma.compatibilityFactorWeight.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 궁합 요소입니다." };
  }

  await prisma.compatibilityFactorWeight.update({
    where: { id },
    data: { isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: isActive ? "activate" : "deactivate",
      targetType: "compatibility_factor_weight",
      targetId: id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  const warning = await buildWeightSumWarning();
  return { success: true, warning };
}
