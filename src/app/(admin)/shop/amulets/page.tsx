import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// 05_Admin_System_Design.md §3.4 "상점 관리"
// [과거 구현] 1차 소단위: 디지털부적 상품 관리 — 04A H-1 amulet_items +
// H-2 amulet_grades(마스터) CRUD. 2차 소단위: 부적 지급/보유 이력 조회 —
// 04A H-3 user_amulets, H-4 amulet_usage_logs, H-5 amulet_gifts,
// H-6 amulet_collections(조회 전용, missions 화면의 user_missions 패턴과 동일).
//
// [신통방통 관리자 최종 간소화 실행 지시서 §3 "그 밖에 현재 사용하지 않는 메뉴"]
// [전수조사 재확인] Flutter 앱의 부적 상점 화면(talisman_shop_screen.dart)은 이
// 화면이 다루는 AmuletItem/UserAmulet 모델이 아니라 별도의 ShopCatalogItem
// (itemType="talisman") + UserInventoryItem 모델을 사용한다(shop_api_repository.dart
// → /api/public/shop/talismans, /api/public/inventory). /api/public/amulets/*
// (shop/my/purchase/use/generate/gift) 공개 API 6개가 구현되어 있지만 Flutter
// 코드 전체(lib/)에서 이 경로를 호출하는 곳이 0건 — API는 존재하되 현재
// 실제로 사용되지 않는 레거시 상점 체계다. 이 화면으로 진입하는 사이드바/탭
// 링크도 전혀 없어(URL 직접 입력으로만 도달 가능) 운영자가 실수로 들어올
// 경로조차 없었다.
// [메뉴 비노출 — 코드/DB 보존] "off" 원칙에 따라 원본 UI 구현(폼/테이블)은
// 제거하되, 서버 액션(actions/amulets.ts)과 Prisma 모델(AmuletGrade/AmuletItem/
// UserAmulet/AmuletUsageLog/AmuletGift/AmuletCollection)은 전혀 건드리지 않고
// 그대로 둔다. 이 페이지는 접근 시 /shop/luckybag(실제 운영 중인 상점 관리
// 진입점)로 즉시 리다이렉트만 한다. redirect()가 never를 반환해 그 아래 코드가
// typescript상 unreachable이 되므로, 원본 UI 코드는 git 히스토리(이 커밋 이전
// 버전)에서 그대로 복원 가능하며 여기서는 최소 리다이렉트만 남긴다.
export const dynamic = "force-dynamic";

export default async function ShopAmuletsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "shop")) {
    redirect("/dashboard");
  }
  redirect("/shop/luckybag");
}
