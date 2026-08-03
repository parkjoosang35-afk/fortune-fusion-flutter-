// [메인화면 관리자 편집기] GET/POST /admin/page-configs/home/sections/{id}/conditions
// §9 노출조건 시스템 — ruleType/ruleOperator/ruleValue triple만 허용(개발자 표현식 금지).
import { prisma } from "@/lib/db";
import { isValidRuleOperator, isValidRuleType, RULE_TYPE_ALLOWED_OPERATORS, type RuleType } from "@/lib/page-config-constants";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const sectionId = Number(idParam);
  if (!Number.isInteger(sectionId)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const rules = await prisma.sectionDisplayRule.findMany({ where: { sectionId } });
    return jsonOk(
      rules.map((r) => ({
        id: r.id,
        ruleType: r.ruleType,
        ruleOperator: r.ruleOperator,
        ruleValue: r.ruleValue,
        isActive: r.isActive,
      })),
    );
  } catch (e) {
    console.error("[GET .../conditions] 실패:", e);
    return jsonError("노출 조건 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const sectionId = Number(idParam);
  if (!Number.isInteger(sectionId)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const section = await prisma.pageSection.findFirst({ where: { id: sectionId, deletedAt: null } });
    if (!section) return jsonError("섹션을 찾을 수 없습니다.", 404);

    const body = await request.json();
    const ruleType = typeof body.ruleType === "string" ? body.ruleType : "";
    const ruleOperator = typeof body.ruleOperator === "string" ? body.ruleOperator : "";
    const ruleValue = typeof body.ruleValue === "string" ? body.ruleValue : "";

    if (!isValidRuleType(ruleType)) return jsonError("ruleType이 노출조건 화이트리스트에 없습니다.");
    if (!isValidRuleOperator(ruleOperator)) return jsonError("ruleOperator가 올바르지 않습니다.");
    if (!RULE_TYPE_ALLOWED_OPERATORS[ruleType as RuleType].includes(ruleOperator)) {
      return jsonError(
        `"${ruleType}" 조건 타입에는 [${RULE_TYPE_ALLOWED_OPERATORS[ruleType as RuleType].join(", ")}] 연산자만 허용됩니다.`,
      );
    }
    if (!ruleValue) return jsonError("ruleValue는 필수입니다.");

    const created = await prisma.sectionDisplayRule.create({
      data: { sectionId, ruleType, ruleOperator, ruleValue, isActive: body.isActive !== false },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId,
      actionType: "update",
      summary: `노출 조건 추가: ${section.sectionKey} - ${ruleType} ${ruleOperator} ${ruleValue}`,
    });

    return jsonOk(
      {
        id: created.id,
        ruleType: created.ruleType,
        ruleOperator: created.ruleOperator,
        ruleValue: created.ruleValue,
        isActive: created.isActive,
      },
      201,
    );
  } catch (e) {
    console.error("[POST .../conditions] 실패:", e);
    return jsonError("노출 조건 추가 중 오류가 발생했습니다.", 500);
  }
}
