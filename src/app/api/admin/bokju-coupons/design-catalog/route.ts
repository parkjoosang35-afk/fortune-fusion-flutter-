// [쿠폰 디자인 스튜디오 4단계 — 엔드포인트 5종 중 5] GET
// /api/admin/bokju-coupons/design-catalog
//
// 팔레트 12종 · 템플릿 7종 · 부품 17종(5그룹)을 React 에디터에 내려준다.
// [02e §0-G 필수 3] 값은 전부 theme.ts/templates.ts 모듈에서 가져온다
// (studio-api.ts의 getDesignCatalog() — 이 라우트는 값을 손으로 적지
// 않는다). 캠페인 단위가 아닌 전역 카탈로그이므로 campaigns/:id 하위가
// 아니라 최상위에 둔다.
import { jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { getDesignCatalog } from "@/lib/bokju-coupon-design/studio-api";

export const dynamic = "force-dynamic";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const catalog = getDesignCatalog();
  return jsonOk(catalog);
}
