// [메인화면 관리자 편집기] GET /admin/block-types
// §7 블록 시스템 화이트리스트 + §8 스타일 프리셋 + §9 노출조건 타입을 그대로 반환한다.
// 관리자 UI의 select box 옵션과 서버 validation이 동일한 소스를 공유(§7,8,9 원칙).
import {
  ALIGNMENT_PRESETS,
  ATTACHMENT_USAGE_TYPES,
  BACKGROUND_PRESETS,
  BLOCK_TYPES,
  BLOCK_TYPE_LABELS,
  DENSITY_PRESETS,
  LINKED_ASSET_TYPES,
  PLATFORM_TARGETS,
  RULE_OPERATORS,
  RULE_TYPES,
  RULE_TYPE_LABELS,
  RULE_TYPE_ALLOWED_OPERATORS,
  SECTION_STATUSES,
  STYLE_PRESETS,
  TEXT_LIMITS,
} from "@/lib/page-config-constants";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    return jsonOk({
      blockTypes: BLOCK_TYPES.map((v) => ({ value: v, label: BLOCK_TYPE_LABELS[v] })),
      stylePresets: STYLE_PRESETS,
      backgroundPresets: BACKGROUND_PRESETS,
      alignmentPresets: ALIGNMENT_PRESETS,
      densityPresets: DENSITY_PRESETS,
      sectionStatuses: SECTION_STATUSES,
      platformTargets: PLATFORM_TARGETS,
      attachmentUsageTypes: ATTACHMENT_USAGE_TYPES,
      ruleTypes: RULE_TYPES.map((v) => ({
        value: v,
        label: RULE_TYPE_LABELS[v],
        allowedOperators: RULE_TYPE_ALLOWED_OPERATORS[v],
      })),
      ruleOperators: RULE_OPERATORS,
      linkedAssetTypes: LINKED_ASSET_TYPES,
      textLimits: TEXT_LIMITS,
    });
  } catch (e) {
    console.error("[GET /api/admin/page-configs/home/block-types] 실패:", e);
    return jsonError("블록 타입 조회 중 오류가 발생했습니다.", 500);
  }
}
