// RBAC 권한 매트릭스 — 05_Admin_System_Design.md §2(메뉴구조), §5.1(역할정의), §5.2(메뉴별권한매트릭스)
// 04A B-2/B-3 admin_roles/admin_permissions와 동일한 개념을 코드 레벨에서도 참조 가능하도록 상수화.
// 실제 권한 판정은 DB(admin_permissions 테이블, seed 데이터)를 기준으로 하며,
// 이 상수는 사이드바 메뉴 렌더링 및 라우트 가드의 "메뉴 코드 정의" 용도로 사용한다.

export const ADMIN_ROLE_CODES = [
  "super_admin",
  "operator",
  "cs",
  "content_manager",
] as const;
export type AdminRoleCode = (typeof ADMIN_ROLE_CODES)[number];

export interface AdminMenuItem {
  code: string; // menu_code (admin_permissions.menu_code와 매칭)
  label: string;
  path: string; // 08_Web_Design.md §3.2 라우트 매핑표 기준
  icon: string; // lucide-react 아이콘명
}

export interface AdminMenuGroup {
  code: string;
  label: string;
  path: string;
  icon: string;
  children?: AdminMenuItem[];
}

// 05_Admin_System_Design.md §2 "전체 메뉴 구조 (좌측 사이드바)" — 0~11번, 11개 메뉴 그룹
export const ADMIN_MENU_GROUPS: AdminMenuGroup[] = [
  { code: "dashboard", label: "대시보드", path: "/dashboard", icon: "LayoutDashboard" },
  { code: "users", label: "회원 관리", path: "/users", icon: "Users" },
  { code: "ai_content", label: "AI 콘텐츠 관리", path: "/ai-content/prompts", icon: "Sparkles" },
  { code: "reward", label: "리워드 관리", path: "/reward/policies", icon: "Gift" },
  { code: "shop", label: "상점 관리", path: "/shop/amulets", icon: "Store" },
  { code: "community", label: "커뮤니티 관리", path: "/community/posts", icon: "MessageSquare" },
  { code: "matching", label: "매칭/궁합 관리", path: "/matching/profiles", icon: "Heart" },
  { code: "payments", label: "결제/구독 관리", path: "/payments", icon: "CreditCard" },
  { code: "cms", label: "CMS", path: "/cms/banners", icon: "FileText" },
  { code: "notifications", label: "알림 관리", path: "/notifications/templates", icon: "Bell" },
  { code: "ops_security", label: "운영/보안", path: "/admin-users", icon: "ShieldCheck" },
  { code: "system_settings", label: "시스템 설정", path: "/system-settings", icon: "Settings" },
];

// 05_Admin_System_Design.md §5.2 메뉴별 권한 매트릭스 (요약표 그대로 반영)
// R=조회, W=생성/수정, D=삭제, X=접근불가
type Perm = { read: boolean; write: boolean; delete: boolean };
const R: Perm = { read: true, write: false, delete: false };
const RW: Perm = { read: true, write: true, delete: false };
const RWD: Perm = { read: true, write: true, delete: true };
const X: Perm = { read: false, write: false, delete: false };

export const RBAC_MATRIX: Record<string, Record<AdminRoleCode, Perm>> = {
  dashboard: { super_admin: RWD, operator: R, cs: R, content_manager: R },
  users: { super_admin: RWD, operator: RW, cs: RW, content_manager: R },
  ai_content: { super_admin: RWD, operator: R, cs: R, content_manager: RW },
  reward: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  shop: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  community: { super_admin: RWD, operator: RW, cs: RW, content_manager: R },
  matching: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  payments: { super_admin: RWD, operator: R, cs: R, content_manager: X },
  cms: { super_admin: RWD, operator: RW, cs: R, content_manager: RW },
  notifications: { super_admin: RWD, operator: RW, cs: R, content_manager: RW },
  ops_security: { super_admin: RWD, operator: X, cs: X, content_manager: X },
  system_settings: { super_admin: RWD, operator: R, cs: X, content_manager: X },
};

export function canAccessMenu(roleCode: string, menuCode: string): boolean {
  const perm = RBAC_MATRIX[menuCode]?.[roleCode as AdminRoleCode];
  return !!perm?.read;
}

export function getVisibleMenusForRole(roleCode: string): AdminMenuGroup[] {
  return ADMIN_MENU_GROUPS.filter((menu) => canAccessMenu(roleCode, menu.code));
}

// 범용 write/delete 권한 체크 헬퍼(메뉴 공통) — "use server" 액션 파일에서는
// export되는 모든 함수가 async여야 하므로, 이런 동기 헬퍼는 여기(rbac.ts)에 둔다.
export function canWriteMenu(roleCode: string, menuCode: string): boolean {
  if (!canAccessMenu(roleCode, menuCode)) return false;
  return !!RBAC_MATRIX[menuCode]?.[roleCode as AdminRoleCode]?.write;
}

export function canDeleteMenu(roleCode: string, menuCode: string): boolean {
  if (!canAccessMenu(roleCode, menuCode)) return false;
  return !!RBAC_MATRIX[menuCode]?.[roleCode as AdminRoleCode]?.delete;
}
