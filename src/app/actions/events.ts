"use server";

// CMS 이벤트 관리 Server Actions
// 05_Admin_System_Design.md §3.8 "이벤트 관리" — 04A N-5 events CRUD
// (event_type별 config JSON 설정). notices.ts/faqs.ts 패턴을 재사용한다.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
// event_participations은 조회 전용(참여 현황)이므로 CUD 액션을 두지 않는다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteCms(roleCode: string): boolean {
  return canWriteMenu(roleCode, "cms");
}

function canDeleteCms(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "cms");
}

export interface EventFormState {
  error?: string;
  success?: boolean;
}

// 04A N-5 명시: event_type VARCHAR(30) NN — attendance_bonus/roulette/special_mission
const EVENT_TYPES = ["attendance_bonus", "roulette", "special_mission"] as const;

const EventSchema = z.object({
  title: z.string().min(1, "제목을 입력해주세요."),
  imageUrl: z
    .string()
    .optional()
    .transform((v) => (v && v.trim().length > 0 ? v.trim() : null)),
  eventType: z.enum(EVENT_TYPES, { message: "이벤트 타입을 선택해주세요." }),
  config: z.string().min(1, "설정(config)을 입력해주세요.(04A N-5 명시: NOT NULL)").refine(
    (v) => {
      try {
        JSON.parse(v);
        return true;
      } catch {
        return false;
      }
    },
    { message: "설정(config)은 올바른 JSON 형식이어야 합니다." }
  ),
  startAt: z.string().min(1, "시작일시를 입력해주세요.(04A N-5 명시: NOT NULL)"),
  endAt: z.string().min(1, "종료일시를 입력해주세요.(04A N-5 명시: NOT NULL)"),
  isActive: z.coerce.boolean().optional().default(true),
});

// ── 생성 ──
export async function createEvent(
  _prevState: EventFormState,
  formData: FormData
): Promise<EventFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = EventSchema.safeParse({
    title: formData.get("title"),
    imageUrl: formData.get("imageUrl"),
    eventType: formData.get("eventType"),
    config: formData.get("config"),
    startAt: formData.get("startAt"),
    endAt: formData.get("endAt"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.event.create({
    data: {
      title: parsed.data.title,
      imageUrl: parsed.data.imageUrl,
      eventType: parsed.data.eventType,
      config: parsed.data.config,
      startAt: new Date(parsed.data.startAt),
      endAt: new Date(parsed.data.endAt),
      isActive: parsed.data.isActive,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "event",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ title: created.title, eventType: created.eventType }),
    },
  });

  revalidatePath("/cms/events");
  return { success: true };
}

// ── 수정 ──
const UpdateEventSchema = EventSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateEvent(
  _prevState: EventFormState,
  formData: FormData
): Promise<EventFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateEventSchema.safeParse({
    id: formData.get("id"),
    title: formData.get("title"),
    imageUrl: formData.get("imageUrl"),
    eventType: formData.get("eventType"),
    config: formData.get("config"),
    startAt: formData.get("startAt"),
    endAt: formData.get("endAt"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.event.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 이벤트입니다." };
  }

  const after = await prisma.event.update({
    where: { id: parsed.data.id },
    data: {
      title: parsed.data.title,
      imageUrl: parsed.data.imageUrl,
      eventType: parsed.data.eventType,
      config: parsed.data.config,
      startAt: new Date(parsed.data.startAt),
      endAt: new Date(parsed.data.endAt),
      isActive: parsed.data.isActive,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "event",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title, eventType: before.eventType }),
      after: JSON.stringify({ title: after.title, eventType: after.eventType }),
    },
  });

  revalidatePath("/cms/events");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteEventSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteEvent(
  _prevState: EventFormState,
  formData: FormData
): Promise<EventFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteEventSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.event.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 이벤트입니다." };
  }

  await prisma.event.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "event",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/cms/events");
  return { success: true };
}

// ── 활성/비활성 토글 ──
const ToggleActiveSchema = z.object({
  id: z.coerce.number().int().positive(),
  isActive: z.coerce.boolean(),
});

export async function toggleEventActive(
  _prevState: EventFormState,
  formData: FormData
): Promise<EventFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleActiveSchema.safeParse({
    id: formData.get("id"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.event.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 이벤트입니다." };
  }

  await prisma.event.update({
    where: { id: parsed.data.id },
    data: { isActive: parsed.data.isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.isActive ? "activate" : "deactivate",
      targetType: "event",
      targetId: parsed.data.id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive: parsed.data.isActive }),
    },
  });

  revalidatePath("/cms/events");
  return { success: true };
}
