"use server";

// 열림패스 첨부파일(이미지/영상/문서/외부링크/HTML) 관리 Server Actions
// [사용자 요청: 열림패스 관리자 첨부파일 업로드/광고소스 연동] §3/§6-2/§8-2
// 파일 자체는 /api/upload(기존 공용 업로드 라우트, category="open-pass")로 이미 저장된
// 상태에서 이 액션이 호출되며(클라이언트가 먼저 업로드 → URL을 hidden input에 채움),
// 여기서는 "그 URL이 어떤 용도(purpose)의 첨부파일인지"를 OpenPassAttachment로 저장한다.
// pass-policies.ts와 동일한 CRUD/RBAC/OperationLog 컨벤션을 따른다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";
// [주의] "use server" 파일은 async 함수만 export할 수 있어 상수 배열은 여기서 export하지 않는다.
// 클라이언트 폼 등에서 동일한 값이 필요하면 반드시 이 공용 상수 모듈을 import한다.
import { ATTACHMENT_FILE_TYPES, ATTACHMENT_PURPOSES } from "@/lib/open-pass-constants";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}
function canDeleteReward(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "reward");
}

const REVALIDATE_PATH = "/reward/open-pass-attachments";

function revalidateAll() {
  revalidatePath(REVALIDATE_PATH);
  revalidatePath("/reward/pass-policies");
  revalidatePath("/reward/open-pass-bindings");
  revalidatePath("/reward/test-lab");
}

const AttachmentSchema = z.object({
  fileName: z.string().min(1, "파일명(제목)을 입력해주세요."),
  fileType: z.enum(ATTACHMENT_FILE_TYPES, { message: "지원하지 않는 첨부파일 유형입니다." }),
  purpose: z.enum(ATTACHMENT_PURPOSES, { message: "용도를 선택해주세요." }),
  fileUrl: z.string().optional().nullable(),
  thumbnailUrl: z.string().optional().nullable(),
  mimeType: z.string().optional().nullable(),
  fileSize: z.coerce.number().int().min(0).optional().nullable(),
  htmlContent: z.string().optional().nullable(),
  displayOrder: z.coerce.number().int().min(0).optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface AttachmentFormState {
  error?: string;
  success?: boolean;
}

function readAttachmentFormData(formData: FormData) {
  const fileType = formData.get("fileType");
  const isHtml = fileType === "rich_text_html";
  return {
    fileName: formData.get("fileName"),
    fileType,
    purpose: formData.get("purpose"),
    fileUrl: formData.get("fileUrl") || null,
    thumbnailUrl: formData.get("thumbnailUrl") || null,
    mimeType: formData.get("mimeType") || null,
    fileSize: formData.get("fileSize") || null,
    htmlContent: isHtml ? formData.get("htmlContent") || null : null,
    displayOrder: formData.get("displayOrder") || 0,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  };
}

export async function createOpenPassAttachment(
  _prevState: AttachmentFormState,
  formData: FormData
): Promise<AttachmentFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = AttachmentSchema.safeParse(readAttachmentFormData(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;

  // 실질 소재(external_link/rich_text_html이 아닌 이상)는 fileUrl이 필수.
  if (data.fileType !== "rich_text_html" && !data.fileUrl) {
    return { error: "파일을 업로드하거나 링크 URL을 입력해주세요." };
  }
  if (data.fileType === "external_link" && data.fileUrl && !/^https?:\/\//.test(data.fileUrl)) {
    return { error: "외부 링크는 http(s):// 형식의 URL이어야 합니다." };
  }

  const created = await prisma.openPassAttachment.create({
    data: {
      fileName: data.fileName,
      fileType: data.fileType,
      purpose: data.purpose,
      fileUrl: data.fileUrl,
      thumbnailUrl: data.thumbnailUrl ?? (data.fileType === "image" ? data.fileUrl : null),
      mimeType: data.mimeType,
      fileSize: data.fileSize,
      htmlContent: data.htmlContent,
      displayOrder: data.displayOrder,
      isActive: data.isActive,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "open_pass_attachment",
      targetId: created.id,
      after: JSON.stringify(created),
    },
  });

  revalidateAll();
  return { success: true };
}

export async function updateOpenPassAttachment(
  _prevState: AttachmentFormState,
  formData: FormData
): Promise<AttachmentFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const idRaw = formData.get("id");
  const id = Number(idRaw);
  if (!id || Number.isNaN(id)) {
    return { error: "잘못된 요청입니다." };
  }

  const before = await prisma.openPassAttachment.findUnique({ where: { id } });
  if (!before || before.deletedAt) {
    return { error: "존재하지 않는 첨부파일입니다." };
  }

  const parsed = AttachmentSchema.safeParse(readAttachmentFormData(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;
  if (data.fileType !== "rich_text_html" && !data.fileUrl) {
    return { error: "파일을 업로드하거나 링크 URL을 입력해주세요." };
  }

  const after = await prisma.openPassAttachment.update({
    where: { id },
    data: {
      fileName: data.fileName,
      fileType: data.fileType,
      purpose: data.purpose,
      fileUrl: data.fileUrl,
      thumbnailUrl: data.thumbnailUrl ?? (data.fileType === "image" ? data.fileUrl : before.thumbnailUrl),
      mimeType: data.mimeType,
      fileSize: data.fileSize,
      htmlContent: data.htmlContent,
      displayOrder: data.displayOrder,
      isActive: data.isActive,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "open_pass_attachment",
      targetId: id,
      before: JSON.stringify(before),
      after: JSON.stringify(after),
    },
  });

  revalidateAll();
  return { success: true };
}

export async function deleteOpenPassAttachment(
  _prevState: AttachmentFormState,
  formData: FormData
): Promise<AttachmentFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const id = Number(formData.get("id"));
  if (!id || Number.isNaN(id)) {
    return { error: "잘못된 요청입니다." };
  }

  const before = await prisma.openPassAttachment.findUnique({ where: { id } });
  if (!before || before.deletedAt) {
    return { error: "존재하지 않는 첨부파일입니다." };
  }

  // [§13 QA: "파일 삭제 시 바인딩 보호"] 활성 상태로 상품에 바인딩되어 있으면 삭제를 막는다.
  // (참조 무결성이 FK로 강제되지 않으므로 애플리케이션 레벨에서 직접 체크)
  const activeBindingCount = await prisma.openPassProductAttachment.count({
    where: { attachmentId: id, isActive: true },
  });
  if (activeBindingCount > 0) {
    return {
      error: `이 첨부파일은 ${activeBindingCount}개의 열림패스 상품에 연결되어 있어 삭제할 수 없습니다. 먼저 상품 연결을 해제해주세요.`,
    };
  }
  // 대표/fallback 첨부파일로 지정된 상품이 있는지도 확인.
  const referencedByPolicyCount = await prisma.passPolicy.count({
    where: {
      deletedAt: null,
      OR: [{ heroAttachmentId: id }, { promoAttachmentId: id }, { fallbackAttachmentId: id }],
    },
  });
  if (referencedByPolicyCount > 0) {
    return {
      error: `이 첨부파일은 ${referencedByPolicyCount}개의 열림패스 상품에서 대표/안내/fallback 소재로 지정되어 있어 삭제할 수 없습니다.`,
    };
  }

  await prisma.openPassAttachment.update({
    where: { id },
    data: { status: "deleted", isActive: false, deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "open_pass_attachment",
      targetId: id,
      before: JSON.stringify(before),
    },
  });

  revalidateAll();
  return { success: true };
}
