// [메인화면 관리자 편집기] PUT /admin/page-configs/home/sections/reorder
// §5 "세로 스택형 섹션 reorder" — 좌표 자유배치가 아니라 순서 배열만 받는다.
// body: { order: number[] } (섹션 id 배열, 배열의 인덱스가 곧 새 sortOrder)
// 고정(isPinned) 섹션이 배열 순서상 이동해도 막지는 않지만(관리자가 명시적으로
// 재배열한 것이므로 허용), 응답에 pinned 섹션 목록을 안내 정보로 함께 반환한다.
import { prisma } from "@/lib/db";
import {
  getOrCreateDraftVersion,
  isAdminActor,
  jsonError,
  jsonOk,
  requireAdminOrResponse,
  writeAuditLog,
} from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function PUT(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const order: unknown = body.order;
    if (!Array.isArray(order) || order.some((id) => typeof id !== "number")) {
      return jsonError("order는 섹션 id의 숫자 배열이어야 합니다.");
    }

    const draft = await getOrCreateDraftVersion(PAGE_KEY);
    const existingSections = await prisma.pageSection.findMany({
      where: { pageVersionId: draft.id, deletedAt: null },
    });
    const existingIds = new Set(existingSections.map((s) => s.id));

    if (order.length !== existingSections.length || order.some((id) => !existingIds.has(id))) {
      return jsonError("order 배열이 현재 draft의 섹션 집합과 일치하지 않습니다.");
    }

    await prisma.$transaction(
      order.map((id, index) =>
        prisma.pageSection.update({ where: { id }, data: { sortOrder: index, updatedBy: actor.adminId } }),
      ),
    );

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      actionType: "reorder",
      summary: `섹션 순서 변경 (${order.length}개)`,
      payload: { order },
    });

    const pinnedStillPresent = existingSections.filter((s) => s.isPinned).map((s) => s.sectionKey);

    return jsonOk({ order, pinnedSectionKeys: pinnedStillPresent });
  } catch (e) {
    console.error("[PUT /api/admin/page-configs/home/sections/reorder] 실패:", e);
    return jsonError("순서 변경 중 오류가 발생했습니다.", 500);
  }
}
