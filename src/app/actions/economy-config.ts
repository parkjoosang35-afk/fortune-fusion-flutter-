"use server";

// 복(福) 경제 설정(economy_config) Server Action
// [배경] "Fortune Fusion 마스터 개발 프롬프트" 2부(복주머니 경제 엔진) 철학 이식
// (옵션B: 기존 Provider/Next.js/Prisma 스택 유지, 경제 로직만 이식) — Phase4(관리자 대시보드).
//
// economy_config는 key-value 구조이며, wallet/send·spend API가 이미
//   sendRefundConfig?.value ?? 0.5 / dailyLimitConfig?.value ?? 200
// 형태로 "값이 없으면 하드코딩 기본값" fallback을 쓰고 있으므로, 이 액션은
// upsert(없으면 생성, 있으면 갱신) 방식으로 저장한다. 05§1 원칙2에 따라
// 모든 CUD 작업은 operation_logs에 기록한다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";
import { ECONOMY_CONFIG_KEYS } from "@/lib/economy-config-meta";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}

const UpdateSchema = z.object({
  key: z.enum(ECONOMY_CONFIG_KEYS.map((k) => k.key) as [string, ...string[]]),
  value: z.coerce.number().finite(),
});

export interface EconomyConfigFormState {
  error?: string;
  success?: boolean;
}

export async function updateEconomyConfig(
  _prevState: EconomyConfigFormState,
  formData: FormData
): Promise<EconomyConfigFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateSchema.safeParse({
    key: formData.get("key"),
    value: formData.get("value"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { key, value } = parsed.data;

  const meta = ECONOMY_CONFIG_KEYS.find((k) => k.key === key);
  if (!meta) {
    return { error: "알 수 없는 설정 키입니다." };
  }
  if (value < meta.min || value > meta.max) {
    return { error: `${meta.label}은 ${meta.min}~${meta.max} 범위여야 합니다.` };
  }

  const before = await prisma.economyConfig.findUnique({ where: { key } });

  const updated = await prisma.economyConfig.upsert({
    where: { key },
    create: { key, value, description: meta.description, updatedBy: session.email },
    update: { value, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "economy_config_update",
      targetType: "economy_config",
      targetId: null,
      before: JSON.stringify({ key, value: before?.value ?? meta.defaultValue }),
      after: JSON.stringify({ key, value: updated.value }),
    },
  });

  revalidatePath("/reward/policies");
  return { success: true };
}
