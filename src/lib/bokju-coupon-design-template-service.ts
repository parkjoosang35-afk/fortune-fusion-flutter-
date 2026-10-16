// ══════════════════════════════════════════════════════════════════
// BokjuCouponDesignTemplateService — [신통방통 AI 쿠폰 디자인 표시·숨김 기능 §6/§9]
// "저장된 쿠폰 디자인(배경+표시설정)" 템플릿의 CRUD + 재사용/보관/기본지정/
// 삭제보호 로직 단일 소스.
//
// [핵심 원칙 — 반드시 지킬 것]
//   1. 이 서비스는 BokjuCouponDesignAsset(배경 이미지)와
//      BokjuCouponDesignTemplate(배경+표시설정) 두 테이블만 다루며,
//      실제 쿠폰 데이터(BokjuCoupon/BokjuCouponCampaign)는 절대 쓰지도
//      읽어서 복사하지도 않는다 — §6 "템플릿에는 배경 이미지와 설정만 저장".
//   2. 템플릿 삭제는 그 템플릿을 customTemplateId로 쓰는 캠페인이 있으면
//      차단한다(§9 "사용 중인 템플릿은 삭제 전 연결된 쿠폰을 확인해야
//      합니다"). 대신 archiveTemplate()으로 "발행 화면 목록에서만 숨기고"
//      이미 캠페인이 쓰는 렌더링은 그대로 유지하는 방식을 권장한다.
//   3. 템플릿을 삭제/보관해도 이미 지급된 복주머니·사용 기록(PointHistory,
//      BokjuCouponRedemption)에는 전혀 영향이 없다 — 애초에 이 서비스가
//      그 테이블들을 전혀 건드리지 않으므로 구조적으로 안전하다.
//   4. 쓰기 작업(생성/수정/삭제/기본지정)은 호출부(API 라우트)에서 기존
//      RBAC(canWrite, page-config-helpers.ts의 requireAdminOrResponse +
//      RBAC_MATRIX.bokju_coupon)를 통과한 관리자만 호출할 수 있어야 한다
//      — 이 서비스 자체는 권한 검사를 하지 않는다(다른 bokju-coupon-*
//      서비스 파일들과 동일한 관례: 권한은 API 라우트 레이어 책임).
// ══════════════════════════════════════════════════════════════════
import { prisma } from "@/lib/db";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";
import {
  type CouponVisibilityConfig,
  DEFAULT_VISIBILITY,
  normalizeVisibility,
  parseVisibilityJson,
  serializeVisibility,
} from "@/lib/bokju-coupon-visibility";

export class BokjuDesignTemplateError extends Error {
  code: string;
  details?: unknown;
  constructor(code: string, message: string, details?: unknown) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

export interface DesignTemplateView {
  id: number;
  name: string;
  designAssetId: number | null;
  backgroundImagePath: string | null;
  visibility: CouponVisibilityConfig;
  isDefault: boolean;
  isArchived: boolean;
  createdAt: Date;
  updatedAt: Date;
  campaignCount: number; // 이 템플릿을 현재 쓰고 있는 캠페인 수(삭제 가능 여부 UI 표시용)
}

function toView(
  row: {
    id: number;
    name: string;
    designAssetId: number | null;
    visibility: string;
    isDefault: boolean;
    isArchived: boolean;
    createdAt: Date;
    updatedAt: Date;
    designAsset?: { imagePath: string } | null;
    _count?: { campaigns: number };
  }
): DesignTemplateView {
  return {
    id: row.id,
    name: row.name,
    designAssetId: row.designAssetId,
    backgroundImagePath: row.designAsset?.imagePath ?? null,
    visibility: parseVisibilityJson(row.visibility),
    isDefault: row.isDefault,
    isArchived: row.isArchived,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    campaignCount: row._count?.campaigns ?? 0,
  };
}

/** [§6 "쿠폰 발행 화면에서 선택 가능"] 목록 조회. includeArchived=false(기본)면
 * "사용 중지"된 템플릿은 발행 화면 선택지에서 제외하되, 상세/관리 화면에서는
 * includeArchived=true로 전체를 볼 수 있어야 한다. */
export async function listDesignTemplates(options?: {
  includeArchived?: boolean;
}): Promise<DesignTemplateView[]> {
  const rows = await prisma.bokjuCouponDesignTemplate.findMany({
    where: options?.includeArchived ? undefined : { isArchived: false },
    include: { designAsset: true, _count: { select: { campaigns: true } } },
    orderBy: [{ isDefault: "desc" }, { updatedAt: "desc" }],
  });
  return rows.map(toView);
}

export async function getDesignTemplate(id: number): Promise<DesignTemplateView | null> {
  const row = await prisma.bokjuCouponDesignTemplate.findUnique({
    where: { id },
    include: { designAsset: true, _count: { select: { campaigns: true } } },
  });
  return row ? toView(row) : null;
}

/** [§6 "새로 저장"] 새 템플릿 생성. isDefault=true로 생성하면 기존 기본
 * 템플릿의 isDefault를 자동으로 false로 내린다(항상 1개만 기본). */
export async function createDesignTemplate(params: {
  name: string;
  designAssetId?: number | null;
  visibility: Partial<CouponVisibilityConfig>;
  isDefault?: boolean;
  actorId: string;
}): Promise<DesignTemplateView> {
  const name = params.name.trim();
  if (!name) throw new BokjuDesignTemplateError("INVALID_NAME", "템플릿 이름을 입력해 주세요.");

  if (params.designAssetId) {
    const asset = await prisma.bokjuCouponDesignAsset.findUnique({ where: { id: params.designAssetId } });
    if (!asset) throw new BokjuDesignTemplateError("ASSET_NOT_FOUND", "선택한 AI 배경 이미지를 찾을 수 없습니다.");
    if (asset.status !== "READY") {
      throw new BokjuDesignTemplateError(
        "ASSET_NOT_READY",
        "아직 생성이 완료되지 않았거나 실패한 배경 이미지입니다. 생성이 끝난 배경만 템플릿에 연결할 수 있습니다."
      );
    }
  }

  const visibility = normalizeVisibility(params.visibility ?? DEFAULT_VISIBILITY);

  const created = await prisma.$transaction(async (tx) => {
    if (params.isDefault) {
      await tx.bokjuCouponDesignTemplate.updateMany({ where: { isDefault: true }, data: { isDefault: false } });
    }
    return tx.bokjuCouponDesignTemplate.create({
      data: {
        name,
        designAssetId: params.designAssetId ?? null,
        visibility: serializeVisibility(visibility),
        isDefault: !!params.isDefault,
        createdBy: params.actorId,
      },
      include: { designAsset: true, _count: { select: { campaigns: true } } },
    });
  });

  await writeCouponAuditLog({
    actorId: params.actorId,
    targetType: "DESIGN_TEMPLATE",
    targetId: created.id,
    actionType: "DESIGN_TEMPLATE_CREATE",
    summary: `쿠폰 디자인 템플릿 "${name}" 생성`,
    payload: { designAssetId: params.designAssetId ?? null, visibility },
  });

  return toView(created);
}

/** [§6 "기존 것을 복사해서 새로 저장"] 템플릿 복사. 이름 뒤에 " (복사본)"을
 * 붙이고, isDefault는 항상 false로 시작한다(기본 템플릿이 실수로 중복 지정
 * 되는 것을 방지). */
export async function duplicateDesignTemplate(params: {
  sourceId: number;
  newName?: string;
  actorId: string;
}): Promise<DesignTemplateView> {
  const source = await prisma.bokjuCouponDesignTemplate.findUnique({ where: { id: params.sourceId } });
  if (!source) throw new BokjuDesignTemplateError("TEMPLATE_NOT_FOUND", "복사할 템플릿을 찾을 수 없습니다.");

  const created = await prisma.bokjuCouponDesignTemplate.create({
    data: {
      name: (params.newName?.trim() || `${source.name} (복사본)`).slice(0, 100),
      designAssetId: source.designAssetId,
      visibility: source.visibility,
      isDefault: false,
      createdBy: params.actorId,
    },
    include: { designAsset: true, _count: { select: { campaigns: true } } },
  });

  await writeCouponAuditLog({
    actorId: params.actorId,
    targetType: "DESIGN_TEMPLATE",
    targetId: created.id,
    actionType: "DESIGN_TEMPLATE_DUPLICATE",
    summary: `쿠폰 디자인 템플릿 "${source.name}" → "${created.name}" 복사`,
    payload: { sourceId: source.id },
  });

  return toView(created);
}

/** [§6 "템플릿 수정"] 이름/배경/표시설정/기본여부를 수정한다. 이미 이 템플릿을
 * 쓰는 캠페인이 있어도 수정은 허용한다(§6 "템플릿을 수정해도 이미 발행된
 * 쿠폰 이미지는 소급 변경되지 않습니다" — 그 이미지들은 이미 디스크에 PNG로
 * 저장돼 있어 이 수정과 무관하다. 앞으로 "재생성" 버튼을 누를 때만 새
 * 설정이 반영된다). */
export async function updateDesignTemplate(params: {
  id: number;
  name?: string;
  designAssetId?: number | null;
  visibility?: Partial<CouponVisibilityConfig>;
  isDefault?: boolean;
  actorId: string;
}): Promise<DesignTemplateView> {
  const existing = await prisma.bokjuCouponDesignTemplate.findUnique({ where: { id: params.id } });
  if (!existing) throw new BokjuDesignTemplateError("TEMPLATE_NOT_FOUND", "템플릿을 찾을 수 없습니다.");

  if (params.designAssetId) {
    const asset = await prisma.bokjuCouponDesignAsset.findUnique({ where: { id: params.designAssetId } });
    if (!asset) throw new BokjuDesignTemplateError("ASSET_NOT_FOUND", "선택한 AI 배경 이미지를 찾을 수 없습니다.");
  }

  const nextVisibility = params.visibility
    ? normalizeVisibility({ ...parseVisibilityJson(existing.visibility), ...params.visibility })
    : undefined;

  const updated = await prisma.$transaction(async (tx) => {
    if (params.isDefault) {
      await tx.bokjuCouponDesignTemplate.updateMany({
        where: { isDefault: true, id: { not: params.id } },
        data: { isDefault: false },
      });
    }
    return tx.bokjuCouponDesignTemplate.update({
      where: { id: params.id },
      data: {
        name: params.name?.trim() || undefined,
        designAssetId: params.designAssetId === undefined ? undefined : params.designAssetId,
        visibility: nextVisibility ? serializeVisibility(nextVisibility) : undefined,
        isDefault: params.isDefault === undefined ? undefined : params.isDefault,
      },
      include: { designAsset: true, _count: { select: { campaigns: true } } },
    });
  });

  await writeCouponAuditLog({
    actorId: params.actorId,
    targetType: "DESIGN_TEMPLATE",
    targetId: params.id,
    actionType: "DESIGN_TEMPLATE_UPDATE",
    summary: `쿠폰 디자인 템플릿 "${updated.name}" 수정`,
    payload: { visibility: nextVisibility, designAssetId: params.designAssetId },
  });

  return toView(updated);
}

/** [§6 "사용 중지(archive)"] 발행 화면 선택 목록에서만 숨긴다. 이미 이
 * 템플릿을 쓰는 캠페인의 렌더링에는 전혀 영향 없음(customTemplateId는
 * 그대로 유지되고, runImageJob()은 isArchived 여부를 보지 않음). */
export async function setDesignTemplateArchived(params: {
  id: number;
  archived: boolean;
  actorId: string;
}): Promise<DesignTemplateView> {
  const existing = await prisma.bokjuCouponDesignTemplate.findUnique({ where: { id: params.id } });
  if (!existing) throw new BokjuDesignTemplateError("TEMPLATE_NOT_FOUND", "템플릿을 찾을 수 없습니다.");
  if (params.archived && existing.isDefault) {
    throw new BokjuDesignTemplateError(
      "CANNOT_ARCHIVE_DEFAULT",
      "기본 템플릿은 보관할 수 없습니다. 먼저 다른 템플릿을 기본으로 지정해 주세요."
    );
  }

  const updated = await prisma.bokjuCouponDesignTemplate.update({
    where: { id: params.id },
    data: { isArchived: params.archived },
    include: { designAsset: true, _count: { select: { campaigns: true } } },
  });

  await writeCouponAuditLog({
    actorId: params.actorId,
    targetType: "DESIGN_TEMPLATE",
    targetId: params.id,
    actionType: params.archived ? "DESIGN_TEMPLATE_ARCHIVE" : "DESIGN_TEMPLATE_UNARCHIVE",
    summary: `쿠폰 디자인 템플릿 "${updated.name}" ${params.archived ? "사용 중지" : "사용 재개"}`,
  });

  return toView(updated);
}

/** [§6 "기본 템플릿으로 지정"] "쿠폰 만들기" 화면의 기본 선택값으로 지정한다.
 * 보관된(isArchived) 템플릿은 기본으로 지정할 수 없다(발행 화면에서 보이지도
 * 않는 템플릿이 기본값이면 관리자가 혼란스러우므로). */
export async function setDefaultDesignTemplate(params: {
  id: number;
  actorId: string;
}): Promise<DesignTemplateView> {
  const existing = await prisma.bokjuCouponDesignTemplate.findUnique({ where: { id: params.id } });
  if (!existing) throw new BokjuDesignTemplateError("TEMPLATE_NOT_FOUND", "템플릿을 찾을 수 없습니다.");
  if (existing.isArchived) {
    throw new BokjuDesignTemplateError(
      "ARCHIVED_CANNOT_BE_DEFAULT",
      "사용 중지된 템플릿은 기본으로 지정할 수 없습니다. 먼저 사용 재개해 주세요."
    );
  }

  const updated = await prisma.$transaction(async (tx) => {
    await tx.bokjuCouponDesignTemplate.updateMany({ where: { isDefault: true }, data: { isDefault: false } });
    return tx.bokjuCouponDesignTemplate.update({
      where: { id: params.id },
      data: { isDefault: true },
      include: { designAsset: true, _count: { select: { campaigns: true } } },
    });
  });

  await writeCouponAuditLog({
    actorId: params.actorId,
    targetType: "DESIGN_TEMPLATE",
    targetId: params.id,
    actionType: "DESIGN_TEMPLATE_SET_DEFAULT",
    summary: `쿠폰 디자인 템플릿 "${updated.name}"을(를) 기본값으로 지정`,
  });

  return toView(updated);
}

/** [§9 "사용 중인 템플릿은 삭제 전 연결된 쿠폰을 확인"] 이 템플릿을
 * customTemplateId로 쓰는 캠페인이 하나라도 있으면 삭제를 차단한다. 대신
 * setDesignTemplateArchived()를 안내한다. 삭제 자체는 BokjuCouponDesignAsset
 * 를 건드리지 않는다(여러 템플릿이 같은 배경을 공유할 수 있으므로 템플릿
 * 삭제가 배경까지 지우면 다른 템플릿이 깨질 수 있다). */
export async function deleteDesignTemplate(params: { id: number; actorId: string }): Promise<{ id: number; name: string }> {
  const existing = await prisma.bokjuCouponDesignTemplate.findUnique({
    where: { id: params.id },
    include: { _count: { select: { campaigns: true } } },
  });
  if (!existing) throw new BokjuDesignTemplateError("TEMPLATE_NOT_FOUND", "템플릿을 찾을 수 없습니다.");

  if (existing._count.campaigns > 0) {
    throw new BokjuDesignTemplateError(
      "TEMPLATE_IN_USE",
      `이 템플릿을 사용 중인 캠페인이 ${existing._count.campaigns}개 있어 삭제할 수 없습니다. ` +
        `삭제 대신 "사용 중지"를 이용하면 발행 화면 목록에서만 숨기고 기존 캠페인은 그대로 유지됩니다.`,
      { campaignCount: existing._count.campaigns }
    );
  }
  if (existing.isDefault) {
    throw new BokjuDesignTemplateError(
      "CANNOT_DELETE_DEFAULT",
      "기본 템플릿은 삭제할 수 없습니다. 먼저 다른 템플릿을 기본으로 지정해 주세요."
    );
  }

  await prisma.bokjuCouponDesignTemplate.delete({ where: { id: params.id } });

  await writeCouponAuditLog({
    actorId: params.actorId,
    targetType: "DESIGN_TEMPLATE",
    targetId: params.id,
    actionType: "DESIGN_TEMPLATE_DELETE",
    summary: `쿠폰 디자인 템플릿 "${existing.name}" 삭제`,
  });

  return { id: existing.id, name: existing.name };
}

// ────────────────────────────────────────────────────────────────
// Design Asset (AI 배경 이미지) 조회 — 생성은 bokju-coupon-ai-background-client.ts
// + 아래 API 라우트가 담당하고, 이 서비스는 "이미 생성된 배경 목록 조회/연결"만
// 다룬다(관심사 분리).
// ────────────────────────────────────────────────────────────────

export interface DesignAssetView {
  id: number;
  prompt: string;
  imagePath: string;
  status: string;
  failReason: string | null;
  createdAt: Date;
}

export async function listDesignAssets(): Promise<DesignAssetView[]> {
  const rows = await prisma.bokjuCouponDesignAsset.findMany({
    orderBy: { createdAt: "desc" },
    take: 100, // 과도한 누적 방지 — 최근 100개만 선택 목록에 노출
  });
  return rows.map((r) => ({
    id: r.id,
    prompt: r.prompt,
    imagePath: r.imagePath,
    status: r.status,
    failReason: r.failReason,
    createdAt: r.createdAt,
  }));
}
