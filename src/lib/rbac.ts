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
//
// [무료 광고형 구조 재정비 §8단계 - 관리자 축소] "유지→수정→통합→off→삭제" 원칙에 따라
// 사이드바 노출 목록에서만 아래 최상위 메뉴를 제거한다(라우트 파일/RBAC_MATRIX 엔트리/
// DB 테이블은 전부 보존 — URL을 직접 입력하면 페이지 자체의 canAccessMenu 가드는 여전히
// 그대로 작동한다. 데이터가 필요해지면 이 배열에 다시 추가하기만 하면 즉시 복원됨):
//   - matching(매칭/궁합 관리): "프리패스+복주머니" 2-자산 구조 확정 이후 앱에 매칭/궁합
//     기능 진입점이 없어(consultation_type_screen 등에서 이미 정리됨) 관리할 실사용 데이터가
//     없다. api/public/matching/like, api/public/compatibility/request 라우트도 이미
//     §3단계에서 완전 무료화되어 포인트 정책 연동이 끊어진 상태. (단, compatibility —
//     궁합 — 자체는 Flutter에 실사용 화면이 있어 삭제 대상이 아니다. [task 7 완료]
//     compatibility-weights/compatibility-stats 2개 화면은 matching 디렉터리에서
//     ai-content(6개콘텐츠관리) 아래로 실제 이동했다 — canAccessMenu 가드를
//     matching→ai_content로 전환, 경로를 /ai-content/compatibility-weights,
//     /ai-content/compatibility-stats로 변경, actions/compatibility-weights.ts의
//     write 권한도 ai_content 기준으로 전환. "매칭 삭제, 궁합은 콘텐츠관리로 이전"
//     원칙을 실제 라우트/권한 구조에 반영 완료.)
//   - payments(결제/구독 관리): 행복머니/구독/결제를 비활성화하는 재화구조 원칙(§2단계)에
//     따라 실제 결제 플로우가 앱에 없다.
//   - community(커뮤니티 관리): [신통방통 관리자 통합 간소화 실행 지시서] 전수조사 결과
//     posts/comments/reports/likes/files 5개 하위 화면 전부 Flutter 앱에서 참조하는
//     api/public 엔드포인트가 없고(community API 자체는 /api/public/community가 아닌
//     구버전 흔적만 존재), 앱 어디서도 커뮤니티 진입점이 없어 완전 미사용 확정.
//     matching/payments와 동일한 전례(유지→수정→통합→off→삭제 중 "off") 적용.
//
// [신통방통 관리자 통합 간소화 실행 지시서 - 목표 6+1 구조 1단계] 사장님 운영 실체(콘텐츠6개
// /프리패스/복주머니/광고/회원)에 맞춰 최상위 메뉴를 재편한다:
//   - "리워드 관리(reward)" 1개 메뉴를 "프리패스관리"/"복주머니관리" 2개로 분리 노출한다.
//     하위 14개 페이지 파일은 전부 canAccessMenu(roleCode,"reward")로 가드되어 있어 그대로
//     두고(회귀 위험 최소화), 사이드바 전용 신규 코드 pass/pouch는 RBAC_MATRIX에서 reward와
//     동일 권한을 미러링한다(실제 접근 제어는 각 페이지의 "reward" 가드가 최종 담당).
//   - "광고관리(ad_management)" 신규: 기존 실동작 중인 쿠팡/AdMob 리워드 광고 관리 화면
//     (/reward/fortune-ads, FortuneAd 테이블)을 1차 진입점으로 연결한다. 앱 AdMob 광고단위/
//     웹 AdSense 설정 화면은 DB 모델이 아직 없어(task 4) 별도로 신설해 이 메뉴에 통합할
//     예정이다.
//   - "AI 콘텐츠 관리" → "6개콘텐츠관리"로 라벨만 변경(코드/경로 불변). 귀인지도/소원방/
//     궁합을 이 허브로 통합하는 작업은 신규 admin 화면 구현이 필요해 task 5~8에서 진행한다.
//   - "회원 관리" → "회원·이용내역"으로 라벨 변경(회원 상세 페이지에 이미 프리패스·카테고리별
//     이용현황이 포함되어 있어 코드 변경 없이 명칭만 실태에 맞춘다). [task 9 완료] 다만
//     전수조사 결과 회원 상세 화면에 복주머니(Wallet POINT) 잔액/내역이 전혀 없어
//     "이용내역"이라는 라벨과 실제 내용이 불일치했다 — 회원 상세에 복주머니 잔액 +
//     최근 PointHistory 10건 섹션을 신규 추가하고, /reward/operation-logs(복주머니관리
//     하위)의 회원 닉네임을 /users/[id]로, 회원 상세의 "전체 내역 조회"를
//     /reward/operation-logs?historyUserId=로 서로 연결해 "복주머니관리"와
//     "회원·이용내역" 두 메뉴를 양방향 링크로 통합했다(별도 메뉴 신설/삭제 없음 —
//     기존 두 화면 사이의 누락된 연결고리만 보강).
export const ADMIN_MENU_GROUPS: AdminMenuGroup[] = [
  { code: "dashboard", label: "대시보드", path: "/dashboard", icon: "LayoutDashboard" },
  { code: "pass", label: "프리패스관리", path: "/reward/pass-policies", icon: "Ticket" },
  { code: "pouch", label: "복주머니관리", path: "/reward/luck-pouch-rules", icon: "Gift" },
  { code: "ai_content", label: "6개콘텐츠관리", path: "/ai-content/prompts", icon: "Sparkles" },
  // [신통방통 관리자 통합 간소화 실행 지시서 task 6] 소원방(WishRoom) 운영 관리 —
  // 신고 처리함(wish_room/wish_room_comment/wish_room_review)과 어뷰징 의심 후기
  // 승인 큐 2개 화면을 신설. task 8에서 6개콘텐츠관리 허브로 통합 예정이지만,
  // 그 전까지는 ai_content와 분리된 전용 메뉴코드로 가드해 책임 범위를 명확히 한다.
  { code: "wishroom", label: "소원방 운영", path: "/wishroom/reports", icon: "Heart" },
  { code: "ad_management", label: "광고관리", path: "/reward/fortune-ads", icon: "Megaphone" },
  { code: "users", label: "회원·이용내역", path: "/users", icon: "Users" },
  // [§8단계] 상점 관리 진입점을 부적(amulets, 앱 진입경로 없는 죽은 기능)에서
  // 복주머니뽑기(luckybag, 실제 앱에서 라이브 사용 중)로 변경한다.
  // [task 9 예고] luckybag은 "복주머니를 써서 뽑는" 기능이라 추후 복주머니관리로 통합 검토 대상.
  { code: "shop", label: "상점 관리", path: "/shop/luckybag", icon: "Store" },
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
  // [task 6] 소원방 운영(신고처리/어뷰징후기승인) — community(신고처리함)와 동일하게
  // cs도 write(조치/반려) 가능해야 하므로 community와 동일한 권한셋을 사용한다.
  wishroom: { super_admin: RWD, operator: RW, cs: RW, content_manager: R },
  reward: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  // [관리자 통합 간소화 - 목표 6+1 구조] 사이드바 전용 신규 메뉴코드. 실제 하위 페이지는
  // 전부 canAccessMenu(roleCode,"reward") 가드를 그대로 쓰므로, 여기서는 "reward"와
  // 동일 권한을 미러링해 사이드바 노출 여부만 "reward" 접근 가능 역할과 일치시킨다
  // (권한 소스를 이원화하지 않기 위해 값도 reward와 동일하게 유지).
  pass: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  pouch: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  // [관리자 통합 간소화] 광고관리 허브 — 1차 진입점은 기존 reward/fortune-ads(이미
  // canAccessMenu(roleCode,"reward")로 가드됨)이므로 reward와 동일 권한.
  ad_management: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
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
