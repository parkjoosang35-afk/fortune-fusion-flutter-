"use server";

// [관리자 2.0 전면 재설계 - Task 12b] 프리미엄사주 PDF 섹션 템플릿 관리 Server Actions.
//
// [RBAC] rbac.ts 주석(신규 리프 화면의 RBAC 코드 재사용 결정)에 따라 "ai_content"
// 코드를 재사용한다. ai-prompts.ts와 완전히 동일한 RBAC 체크 패턴.
//
// [버전 관리] ai-prompts.ts의 09_AI_System_Design.md §4 패턴을 그대로 재사용:
// 새 버전 저장 = 덮어쓰기 금지, 항상 version+1로 새 row 생성. 배포 = 같은
// sectionKey의 기존 활성 버전을 비활성화하고 대상 버전만 활성화(트랜잭션).
// 차이점은 ai_prompt_templates는 "도메인"이 고정 목록(DOMAIN_ORDER)인 반면,
// premium_saju_sections는 "섹션"을 관리자가 직접 추가(createSection)할 수
// 있다는 점 — PDF 섹션 구성 자체가 아직 확정되지 않은 1차 설계 단계이기 때문.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWritePremiumSaju(roleCode: string): boolean {
  return canWriteMenu(roleCode, "ai_content");
}

const LIST_PATH = "/ai-content/premium-saju";

export interface PremiumSajuFormState {
  error?: string;
  success?: boolean;
}

// ── 신규 섹션 추가(section_key 최초 생성, version=1) ──
const CreateSectionSchema = z.object({
  sectionKey: z
    .string()
    .trim()
    .min(1, "섹션 키를 입력해주세요.")
    .max(50)
    .regex(/^[a-z0-9_]+$/, "섹션 키는 영문 소문자/숫자/언더스코어만 사용 가능합니다."),
  sectionLabel: z.string().trim().min(1, "섹션 이름을 입력해주세요.").max(100),
  sortOrder: z.coerce.number().int().min(0),
  templateBody: z.string().trim().min(1, "템플릿 내용을 입력해주세요."),
});

export async function createPremiumSajuSection(
  _prevState: PremiumSajuFormState,
  formData: FormData
): Promise<PremiumSajuFormState> {
  const session = await verifyAdminSession();
  if (!canWritePremiumSaju(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = CreateSectionSchema.safeParse({
    sectionKey: formData.get("sectionKey"),
    sectionLabel: formData.get("sectionLabel"),
    sortOrder: formData.get("sortOrder") || 0,
    templateBody: formData.get("templateBody"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { sectionKey, sectionLabel, sortOrder, templateBody } = parsed.data;

  const existing = await prisma.premiumSajuSection.findFirst({ where: { sectionKey } });
  if (existing) {
    return { error: "이미 존재하는 섹션 키입니다. 버전 추가는 섹션 상세에서 해주세요." };
  }

  const created = await prisma.premiumSajuSection.create({
    data: {
      sectionKey,
      sectionLabel,
      sortOrder,
      version: 1,
      templateBody,
      isActive: false,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "premium_saju_section",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ sectionKey, sectionLabel, version: 1 }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}

// ── 새 버전 저장(기존 섹션키에 version+1 새 row 생성, 덮어쓰기 금지) ──
const SaveVersionSchema = z.object({
  sectionKey: z.string().min(1),
  templateBody: z.string().trim().min(1, "템플릿 내용을 입력해주세요."),
});

export async function savePremiumSajuVersion(
  _prevState: PremiumSajuFormState,
  formData: FormData
): Promise<PremiumSajuFormState> {
  const session = await verifyAdminSession();
  if (!canWritePremiumSaju(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = SaveVersionSchema.safeParse({
    sectionKey: formData.get("sectionKey"),
    templateBody: formData.get("templateBody"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { sectionKey, templateBody } = parsed.data;

  const latest = await prisma.premiumSajuSection.findFirst({
    where: { sectionKey },
    orderBy: { version: "desc" },
  });
  if (!latest) {
    return { error: "존재하지 않는 섹션입니다." };
  }

  const newVersion = latest.version + 1;
  const created = await prisma.premiumSajuSection.create({
    data: {
      sectionKey,
      sectionLabel: latest.sectionLabel,
      sortOrder: latest.sortOrder,
      version: newVersion,
      templateBody,
      isActive: false,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "premium_saju_section",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ sectionKey, version: newVersion }),
    },
  });

  revalidatePath(`${LIST_PATH}/${sectionKey}`);
  revalidatePath(LIST_PATH);
  return { success: true };
}

// ── 배포(is_active 토글: 대상 버전만 활성화, 같은 sectionKey의 나머지는 비활성화) ──
const DeploySchema = z.object({
  sectionKey: z.string().min(1),
  templateId: z.coerce.number().int().positive(),
});

export async function deployPremiumSajuVersion(
  _prevState: PremiumSajuFormState,
  formData: FormData
): Promise<PremiumSajuFormState> {
  const session = await verifyAdminSession();
  if (!canWritePremiumSaju(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = DeploySchema.safeParse({
    sectionKey: formData.get("sectionKey"),
    templateId: formData.get("templateId"),
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { sectionKey, templateId } = parsed.data;

  const target = await prisma.premiumSajuSection.findUnique({ where: { id: templateId } });
  if (!target || target.sectionKey !== sectionKey) {
    return { error: "대상 템플릿을 찾을 수 없습니다." };
  }
  if (target.isActive) {
    return { error: "이미 배포(활성)된 버전입니다." };
  }

  const previousActive = await prisma.premiumSajuSection.findFirst({
    where: { sectionKey, isActive: true },
  });

  await prisma.$transaction([
    prisma.premiumSajuSection.updateMany({
      where: { sectionKey, isActive: true },
      data: { isActive: false, updatedBy: session.email },
    }),
    prisma.premiumSajuSection.update({
      where: { id: templateId },
      data: { isActive: true, updatedBy: session.email },
    }),
  ]);

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "deploy",
      targetType: "premium_saju_section",
      targetId: templateId,
      before: JSON.stringify({
        activeVersion: previousActive?.version ?? null,
        activeTemplateId: previousActive?.id ?? null,
      }),
      after: JSON.stringify({ activeVersion: target.version, activeTemplateId: target.id }),
    },
  });

  revalidatePath(`${LIST_PATH}/${sectionKey}`);
  revalidatePath(LIST_PATH);
  return { success: true };
}

// ── 섹션 전체 삭제(soft delete, super_admin만) ──
const DeleteSectionSchema = z.object({ sectionKey: z.string().min(1) });

export async function deletePremiumSajuSection(
  _prevState: PremiumSajuFormState,
  formData: FormData
): Promise<PremiumSajuFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteMenu(session.roleCode, "ai_content")) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = DeleteSectionSchema.safeParse({ sectionKey: formData.get("sectionKey") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { sectionKey } = parsed.data;

  const versions = await prisma.premiumSajuSection.findMany({ where: { sectionKey } });
  if (versions.length === 0) {
    return { error: "존재하지 않는 섹션입니다." };
  }

  await prisma.premiumSajuSection.updateMany({
    where: { sectionKey },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "premium_saju_section",
      targetId: versions[0].id,
      before: JSON.stringify({ sectionKey, versionCount: versions.length }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}
