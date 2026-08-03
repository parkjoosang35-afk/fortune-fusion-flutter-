// [메인화면 관리자 편집기] PUT /admin/page-configs/home/sections/{id}/schedule
// §13 예약 노출 — scheduleEnabled/startAt/endAt. timezone은 서버가 UTC(ISO)로
// 저장하고 표시 시점(Flutter/Admin UI)에서 기기 타임존으로 변환하는 방식을 채택
// (별도 timezone 컬럼을 두지 않음 — 다중 타임존 저장은 이번 1차 범위 밖).
import { prisma } from "@/lib/db";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, serializeSection, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isInteger(id)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const existing = await prisma.pageSection.findFirst({ where: { id, deletedAt: null } });
    if (!existing) return jsonError("섹션을 찾을 수 없습니다.", 404);

    const body = await request.json();
    const scheduleEnabled = typeof body.scheduleEnabled === "boolean" ? body.scheduleEnabled : existing.scheduleEnabled;

    let startAt: Date | null = existing.startAt;
    let endAt: Date | null = existing.endAt;
    if (body.startAt !== undefined) {
      startAt = body.startAt ? new Date(body.startAt) : null;
      if (startAt && Number.isNaN(startAt.getTime())) return jsonError("startAt 형식이 올바르지 않습니다.");
    }
    if (body.endAt !== undefined) {
      endAt = body.endAt ? new Date(body.endAt) : null;
      if (endAt && Number.isNaN(endAt.getTime())) return jsonError("endAt 형식이 올바르지 않습니다.");
    }
    if (scheduleEnabled && startAt && endAt && startAt.getTime() > endAt.getTime()) {
      return jsonError("시작 시각이 종료 시각보다 늦을 수 없습니다.");
    }

    const updated = await prisma.pageSection.update({
      where: { id },
      data: { scheduleEnabled, startAt, endAt, updatedBy: actor.adminId },
      include: { attachments: true, displayRules: true },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: id,
      actionType: "update",
      summary: `섹션 예약노출 설정: ${existing.sectionKey} (enabled=${scheduleEnabled})`,
      payload: { scheduleEnabled, startAt, endAt },
    });

    return jsonOk(serializeSection(updated));
  } catch (e) {
    console.error("[PUT .../schedule] 실패:", e);
    return jsonError("예약 노출 설정 중 오류가 발생했습니다.", 500);
  }
}
