"use server";

// AI 프롬프트 템플릿 관리 Server Actions
// 05_Admin_System_Design.md §3.2 "프롬프트 템플릿 관리" + §4.3 "AI 프롬프트 배포 워크플로우"
// 09_AI_System_Design.md §4: 새 버전 저장 시 version+1로 새 row 생성(덮어쓰기 금지),
//                             배포 시 is_active 토글로 활성 버전 전환.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";

function canWriteAiContent(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "ai_content")) return false;
  return !!RBAC_MATRIX.ai_content[roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;
}

// ── 새 버전 저장 (덮어쓰기 금지, version+1 새 row 생성) ──
const SaveVersionSchema = z.object({
  domain: z.string().min(1),
  templateBody: z.string().min(1, "템플릿 내용을 입력해주세요."),
});

export interface SaveVersionFormState {
  error?: string;
  success?: boolean;
}

export async function saveNewPromptVersion(
  _prevState: SaveVersionFormState,
  formData: FormData
): Promise<SaveVersionFormState> {
  const session = await verifyAdminSession();

  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = SaveVersionSchema.safeParse({
    domain: formData.get("domain"),
    templateBody: formData.get("templateBody"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { domain, templateBody } = parsed.data;

  // 09§4 버전 증가 패턴: 해당 domain의 최신 버전을 찾아 +1로 새 row 생성 (덮어쓰기 금지)
  const latest = await prisma.aiPromptTemplate.findFirst({
    where: { fortuneTypeOrDomain: domain },
    orderBy: { version: "desc" },
  });

  const newVersion = (latest?.version ?? 0) + 1;

  const created = await prisma.aiPromptTemplate.create({
    data: {
      fortuneTypeOrDomain: domain,
      version: newVersion,
      templateBody,
      isActive: false, // 신규 저장 버전은 기본 비활성 — 별도 "배포" 액션으로 활성화
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "ai_prompt_template",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ domain, version: newVersion }),
    },
  });

  revalidatePath(`/ai-content/prompts/${domain}`);
  revalidatePath("/ai-content/prompts");

  return { success: true };
}

// ── 배포 (is_active 토글: 대상 버전만 활성화, 같은 domain의 나머지는 비활성화) ──
const DeploySchema = z.object({
  domain: z.string().min(1),
  templateId: z.coerce.number().int().positive(),
});

export interface DeployFormState {
  error?: string;
  success?: boolean;
}

export async function deployPromptVersion(
  _prevState: DeployFormState,
  formData: FormData
): Promise<DeployFormState> {
  const session = await verifyAdminSession();

  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = DeploySchema.safeParse({
    domain: formData.get("domain"),
    templateId: formData.get("templateId"),
  });

  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const { domain, templateId } = parsed.data;

  const target = await prisma.aiPromptTemplate.findUnique({ where: { id: templateId } });
  if (!target || target.fortuneTypeOrDomain !== domain) {
    return { error: "대상 템플릿을 찾을 수 없습니다." };
  }
  if (target.isActive) {
    return { error: "이미 배포(활성)된 버전입니다." };
  }

  // 트랜잭션: 같은 domain의 기존 활성 버전을 비활성화하고, 대상 버전을 활성화
  const previousActive = await prisma.aiPromptTemplate.findFirst({
    where: { fortuneTypeOrDomain: domain, isActive: true },
  });

  await prisma.$transaction([
    prisma.aiPromptTemplate.updateMany({
      where: { fortuneTypeOrDomain: domain, isActive: true },
      data: { isActive: false, updatedBy: session.email },
    }),
    prisma.aiPromptTemplate.update({
      where: { id: templateId },
      data: { isActive: true, updatedBy: session.email },
    }),
  ]);

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "deploy",
      targetType: "ai_prompt_template",
      targetId: templateId,
      before: JSON.stringify({
        activeVersion: previousActive?.version ?? null,
        activeTemplateId: previousActive?.id ?? null,
      }),
      after: JSON.stringify({ activeVersion: target.version, activeTemplateId: target.id }),
    },
  });

  revalidatePath(`/ai-content/prompts/${domain}`);
  revalidatePath("/ai-content/prompts");

  return { success: true };
}
