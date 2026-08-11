"use server";

// 소원방(Wish Room) 관리자 설정(wish_room_config) Server Action.
// wish-config.ts(소원성/Wish Castle)와 동일한 upsert 패턴을 재사용하되,
// wish_room_config는 값 타입이 number/boolean으로 구성되어 있어 valueType에
// 따라 검증 방식을 분기한다. RBAC는 신규 권한 항목을 추가하지 않고 기존
// community 매트릭스를 그대로 재사용한다(기존 시스템 미침해 원칙).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";
import { WISH_ROOM_CONFIG_KEYS } from "@/lib/wish-room-config-meta";

function canWriteCommunity(roleCode: string): boolean {
  return canWriteMenu(roleCode, "community");
}

const UpdateSchema = z.object({
  key: z.enum(WISH_ROOM_CONFIG_KEYS.map((k) => k.key) as [string, ...string[]]),
  value: z.string(),
});

export interface WishRoomConfigFormState {
  error?: string;
  success?: boolean;
}

function validateValue(
  meta: (typeof WISH_ROOM_CONFIG_KEYS)[number],
  raw: string
): { ok: true; value: string } | { ok: false; error: string } {
  if (meta.valueType === "number") {
    const n = Number(raw);
    if (!Number.isFinite(n)) return { ok: false, error: `${meta.label}은 숫자여야 합니다.` };
    if (meta.min !== undefined && n < meta.min)
      return { ok: false, error: `${meta.label}은 ${meta.min} 이상이어야 합니다.` };
    if (meta.max !== undefined && n > meta.max)
      return { ok: false, error: `${meta.label}은 ${meta.max} 이하여야 합니다.` };
    return { ok: true, value: String(n) };
  }
  if (meta.valueType === "boolean") {
    if (raw !== "true" && raw !== "false")
      return { ok: false, error: `${meta.label}은 true/false여야 합니다.` };
    return { ok: true, value: raw };
  }
  return { ok: true, value: raw };
}

export async function updateWishRoomConfig(
  _prevState: WishRoomConfigFormState,
  formData: FormData
): Promise<WishRoomConfigFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCommunity(session.roleCode)) {
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

  const meta = WISH_ROOM_CONFIG_KEYS.find((k) => k.key === key);
  if (!meta) {
    return { error: "알 수 없는 설정 키입니다." };
  }

  const validated = validateValue(meta, value);
  if (!validated.ok) {
    return { error: validated.error };
  }

  const before = await prisma.wishRoomConfig.findUnique({ where: { key } });

  const updated = await prisma.wishRoomConfig.upsert({
    where: { key },
    create: { key, value: validated.value, description: meta.description, updatedBy: session.email },
    update: { value: validated.value, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "wish_room_config_update",
      targetType: "wish_room_config",
      targetId: null,
      before: JSON.stringify({ key, value: before?.value ?? meta.defaultValue }),
      after: JSON.stringify({ key, value: updated.value }),
    },
  });

  revalidatePath("/community/wish-room");
  return { success: true };
}
