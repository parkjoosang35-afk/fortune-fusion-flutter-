// [메인화면 관리자 편집기] Admin API 라우트 공용 헬퍼.
// - requireAdminOrResponse(): 인증 체크(비인증 시 401 NextResponse 즉시 반환용)
// - getPageConfigOrCreate/getDraftVersionOrThrow: page_configs/page_versions 조회 공용화
// - serializeSection: Prisma row -> JSON 응답 형태(Date -> ISO, platformTargets JSON 파싱)
// - writeAuditLog: page_audit_logs 기록 공용화(모든 변경 액션에서 재사용)
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import type { PageSection } from "@/generated/prisma/client";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export function jsonError(message: string, status = 400) {
  return NextResponse.json({ success: false, error: message }, { status, headers: CORS_HEADERS });
}

export function jsonOk<T>(data: T, status = 200) {
  return NextResponse.json({ success: true, data }, { status, headers: CORS_HEADERS });
}

export interface AdminActor {
  adminId: string;
  roleCode: string;
}

// API Route Handler 컨텍스트에서는 verifyAdminSession()의 redirect()가 의미 없으므로
// (upload/route.ts와 동일 패턴) try/catch로 감싸 401 응답으로 변환한다.
export async function requireAdminOrResponse(): Promise<AdminActor | NextResponse> {
  try {
    const session = await verifyAdminSession();
    return { adminId: String(session.adminUserId), roleCode: session.roleCode };
  } catch {
    return jsonError("인증이 필요합니다.", 401);
  }
}

export function isAdminActor(v: AdminActor | NextResponse): v is AdminActor {
  return !(v instanceof NextResponse);
}

export async function getOrCreatePageConfig(pageKey: string) {
  const existing = await prisma.pageConfig.findUnique({ where: { pageKey } });
  if (existing) return existing;
  return prisma.pageConfig.create({ data: { pageKey } });
}

// 현재 draft PageVersion을 반환한다. draft가 없으면(운영 중 손실 등 예외 상황)
// 현재 published 버전을 복제해 새 draft를 즉시 생성한다(운영 안정성 우선).
export async function getOrCreateDraftVersion(pageKey: string) {
  const config = await getOrCreatePageConfig(pageKey);
  if (config.currentDraftVersionId) {
    const draft = await prisma.pageVersion.findUnique({ where: { id: config.currentDraftVersionId } });
    if (draft) return draft;
  }

  // fallback: published 버전을 복제하거나, 그것도 없으면 빈 draft를 만든다.
  const latestVersionNumber = await prisma.pageVersion.aggregate({
    where: { pageKey },
    _max: { versionNumber: true },
  });
  const nextVersionNumber = (latestVersionNumber._max.versionNumber ?? 0) + 1;

  const newDraft = await prisma.pageVersion.create({
    data: { pageKey, versionNumber: nextVersionNumber, status: "draft", createdBy: "system" },
  });

  if (config.currentPublishedVersionId) {
    const publishedSections = await prisma.pageSection.findMany({
      where: { pageVersionId: config.currentPublishedVersionId, deletedAt: null },
      include: { attachments: true, displayRules: true },
      orderBy: { sortOrder: "asc" },
    });
    for (const s of publishedSections) {
      await cloneSectionIntoVersion(s, newDraft.id);
    }
  }

  await prisma.pageConfig.update({
    where: { id: config.id },
    data: { currentDraftVersionId: newDraft.id },
  });

  return newDraft;
}

// 섹션 1개를 attachments/displayRules까지 포함해 다른 PageVersion으로 복제한다.
// (draft 자동 복구, publish 시 draft->새published 스냅샷, duplicate 액션에서 재사용)
export async function cloneSectionIntoVersion(
  source: PageSection & {
    attachments?: { attachmentUrl: string; usageType: string; isPrimary: boolean; displayOrder: number }[];
    displayRules?: { ruleType: string; ruleOperator: string; ruleValue: string; isActive: boolean }[];
  },
  targetVersionId: number,
  overrides?: { sectionKey?: string; sortOrder?: number },
) {
  const created = await prisma.pageSection.create({
    data: {
      pageVersionId: targetVersionId,
      sectionKey: overrides?.sectionKey ?? source.sectionKey,
      blockType: source.blockType,
      title: source.title,
      subtitle: source.subtitle,
      description: source.description,
      buttonText: source.buttonText,
      buttonLink: source.buttonLink,
      badgeText: source.badgeText,
      emptyStateText: source.emptyStateText,
      stylePreset: source.stylePreset,
      backgroundPreset: source.backgroundPreset,
      alignmentPreset: source.alignmentPreset,
      densityPreset: source.densityPreset,
      isVisible: source.isVisible,
      status: source.status,
      isPinned: source.isPinned,
      isRequired: source.isRequired,
      sortOrder: overrides?.sortOrder ?? source.sortOrder,
      platformTargets: source.platformTargets,
      scheduleEnabled: source.scheduleEnabled,
      startAt: source.startAt,
      endAt: source.endAt,
      linkedAssetType: source.linkedAssetType,
      linkedFeatureScope: source.linkedFeatureScope,
      linkedCampaignId: source.linkedCampaignId,
      linkedProductId: source.linkedProductId,
      createdBy: "system",
      updatedBy: "system",
    },
  });

  if (source.attachments?.length) {
    for (const a of source.attachments) {
      await prisma.sectionAttachmentBinding.create({
        data: {
          sectionId: created.id,
          attachmentUrl: a.attachmentUrl,
          usageType: a.usageType,
          isPrimary: a.isPrimary,
          displayOrder: a.displayOrder,
        },
      });
    }
  }
  if (source.displayRules?.length) {
    for (const r of source.displayRules) {
      await prisma.sectionDisplayRule.create({
        data: {
          sectionId: created.id,
          ruleType: r.ruleType,
          ruleOperator: r.ruleOperator,
          ruleValue: r.ruleValue,
          isActive: r.isActive,
        },
      });
    }
  }

  return created;
}

export async function writeAuditLog(params: {
  adminId: string | null;
  pageKey: string;
  sectionId?: number | null;
  actionType: string;
  summary: string;
  payload?: unknown;
}) {
  await prisma.pageAuditLog.create({
    data: {
      adminId: params.adminId,
      pageKey: params.pageKey,
      sectionId: params.sectionId ?? null,
      actionType: params.actionType,
      summary: params.summary,
      payload: params.payload !== undefined ? JSON.stringify(params.payload) : null,
    },
  });
}

export function serializeSection(
  s: PageSection & {
    attachments?: { id: number; attachmentUrl: string; usageType: string; isPrimary: boolean; displayOrder: number }[];
    displayRules?: {
      id: number;
      ruleType: string;
      ruleOperator: string;
      ruleValue: string;
      isActive: boolean;
    }[];
  },
) {
  let platformTargets: string[] | null = null;
  if (s.platformTargets) {
    try {
      platformTargets = JSON.parse(s.platformTargets);
    } catch {
      platformTargets = null;
    }
  }

  return {
    id: s.id,
    pageVersionId: s.pageVersionId,
    sectionKey: s.sectionKey,
    blockType: s.blockType,
    title: s.title,
    subtitle: s.subtitle,
    description: s.description,
    buttonText: s.buttonText,
    buttonLink: s.buttonLink,
    badgeText: s.badgeText,
    emptyStateText: s.emptyStateText,
    stylePreset: s.stylePreset,
    backgroundPreset: s.backgroundPreset,
    alignmentPreset: s.alignmentPreset,
    densityPreset: s.densityPreset,
    isVisible: s.isVisible,
    status: s.status,
    isPinned: s.isPinned,
    isRequired: s.isRequired,
    sortOrder: s.sortOrder,
    platformTargets,
    scheduleEnabled: s.scheduleEnabled,
    startAt: s.startAt ? s.startAt.toISOString() : null,
    endAt: s.endAt ? s.endAt.toISOString() : null,
    linkedAssetType: s.linkedAssetType,
    linkedFeatureScope: s.linkedFeatureScope,
    linkedCampaignId: s.linkedCampaignId,
    linkedProductId: s.linkedProductId,
    createdAt: s.createdAt.toISOString(),
    updatedAt: s.updatedAt.toISOString(),
    attachments: (s.attachments ?? []).map((a) => ({
      id: a.id,
      attachmentUrl: a.attachmentUrl,
      usageType: a.usageType,
      isPrimary: a.isPrimary,
      displayOrder: a.displayOrder,
    })),
    displayRules: (s.displayRules ?? []).map((r) => ({
      id: r.id,
      ruleType: r.ruleType,
      ruleOperator: r.ruleOperator,
      ruleValue: r.ruleValue,
      isActive: r.isActive,
    })),
  };
}
