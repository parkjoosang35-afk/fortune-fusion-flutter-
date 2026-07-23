"use server";

// 05_Admin_System_Design.md §3.9 "알림 관리" — 3차 소단위: 세그먼트 발송
// "전체/조건별(가입일/등급/활동패턴) 발송 실행 화면"
// 관련 04A 테이블: notification_templates(N-1)/notifications(N-2)
//
// [설계 결정 메모 — 원칙②(설계충돌금지) 준수]
// 04A에는 "세그먼트 발송" 전용 테이블이 없다. 이 화면은 CRUD가 아닌 "실행형" 액션
// (선택한 템플릿을 조건에 맞는 회원들에게 일괄 발송 → notifications 테이블에 대량 insert)이다.
// 조건 매핑은 04A 확장 없이 기존 A-1 users 필드만 사용한다:
//   - 가입일   → users.created_at (기간 범위)
//   - 등급     → users.grade_id → user_grades.code (다중 선택)
//   - 활동패턴 → users.last_login_at (최근 로그인 N일 이내 / N일 이상 미접속)
// 수신 대상은 status='active' 회원으로 한정한다(탈퇴/정지 회원 제외 — 04A와 충돌하지
// 않는 상식적 발송 정책이며, N-2에 명시된 제약은 아니므로 향후 논의 시 변경 가능).
// title/body는 04A N-2 명시대로 "발송 시점 스냅샷"으로 템플릿에서 복사하여 저장한다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canWriteNotifications(roleCode: string): boolean {
  return canWriteMenu(roleCode, "notifications");
}

export interface SegmentSendFormState {
  error?: string;
  success?: boolean;
  sentCount?: number;
}

const ACTIVITY_PATTERNS = [
  "",
  "recent_login_7d",
  "recent_login_30d",
  "dormant_30d",
  "dormant_90d",
] as const;

const SegmentSendSchema = z.object({
  templateId: z.coerce.number().int().positive("발송할 템플릿을 선택해주세요."),
  targetType: z.enum(["all", "condition"], { message: "발송 대상 유형을 선택해주세요." }),
  gradeCodes: z.array(z.string()).optional().default([]),
  joinedFrom: z
    .string()
    .optional()
    .transform((v) => (v && v.trim().length > 0 ? v.trim() : null)),
  joinedTo: z
    .string()
    .optional()
    .transform((v) => (v && v.trim().length > 0 ? v.trim() : null)),
  activityPattern: z.enum(ACTIVITY_PATTERNS).optional().default(""),
});

export async function sendSegmentNotification(
  _prevState: SegmentSendFormState,
  formData: FormData
): Promise<SegmentSendFormState> {
  const session = await verifyAdminSession();
  if (!canWriteNotifications(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = SegmentSendSchema.safeParse({
    templateId: formData.get("templateId"),
    targetType: formData.get("targetType"),
    gradeCodes: formData.getAll("gradeCodes"),
    joinedFrom: formData.get("joinedFrom"),
    joinedTo: formData.get("joinedTo"),
    activityPattern: formData.get("activityPattern"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const template = await prisma.notificationTemplate.findUnique({
    where: { id: parsed.data.templateId },
  });
  if (!template || template.deletedAt) {
    return { error: "존재하지 않는 템플릿입니다." };
  }

  // ── 대상 회원 필터링 ──
  const where: Record<string, unknown> = { deletedAt: null, status: "active" };

  if (parsed.data.targetType === "condition") {
    // 등급 필터
    if (parsed.data.gradeCodes.length > 0) {
      const grades = await prisma.userGrade.findMany({
        where: { code: { in: parsed.data.gradeCodes } },
        select: { id: true },
      });
      if (grades.length === 0) {
        return { error: "선택한 등급을 찾을 수 없습니다." };
      }
      where.gradeId = { in: grades.map((g) => g.id) };
    }

    // 가입일 필터(users.created_at)
    if (parsed.data.joinedFrom || parsed.data.joinedTo) {
      const createdAt: Record<string, Date> = {};
      if (parsed.data.joinedFrom) createdAt.gte = new Date(parsed.data.joinedFrom);
      if (parsed.data.joinedTo) createdAt.lte = new Date(parsed.data.joinedTo);
      where.createdAt = createdAt;
    }

    // 활동패턴 필터(users.last_login_at)
    if (parsed.data.activityPattern) {
      const now = Date.now();
      const days = (n: number) => new Date(now - n * 24 * 60 * 60 * 1000);
      switch (parsed.data.activityPattern) {
        case "recent_login_7d":
          where.lastLoginAt = { gte: days(7) };
          break;
        case "recent_login_30d":
          where.lastLoginAt = { gte: days(30) };
          break;
        case "dormant_30d":
          where.lastLoginAt = { lt: days(30) };
          break;
        case "dormant_90d":
          where.lastLoginAt = { lt: days(90) };
          break;
      }
    }
  }

  const targets = await prisma.user.findMany({ where, select: { id: true } });

  if (targets.length === 0) {
    return { error: "발송 대상 조건에 해당하는 회원이 없습니다." };
  }

  // 발송 시점 스냅샷(04A N-2 명시: 템플릿 변경과 무관하게 불변)으로 대량 insert
  const now = new Date();
  await prisma.notification.createMany({
    data: targets.map((u) => ({
      userId: u.id,
      templateId: template.id,
      title: template.title,
      body: template.body,
      isRead: false,
      sentAt: now,
      createdBy: session.email,
      updatedBy: session.email,
    })),
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "segment_send",
      targetType: "notification",
      targetId: null,
      before: null,
      after: JSON.stringify({
        templateCode: template.code,
        targetType: parsed.data.targetType,
        gradeCodes: parsed.data.gradeCodes,
        joinedFrom: parsed.data.joinedFrom,
        joinedTo: parsed.data.joinedTo,
        activityPattern: parsed.data.activityPattern,
        sentCount: targets.length,
      }),
    },
  });

  revalidatePath("/notifications/segment-send");
  revalidatePath("/notifications/history");
  return { success: true, sentCount: targets.length };
}
