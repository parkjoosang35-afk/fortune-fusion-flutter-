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
  // [신통방통 관리자 통합 간소화 실행 지시서 task 10] 사이드바 "표시 전용"
  // 다중 경로 활성(active) 판정 필드. AdminSidebar.tsx가 ops_security+
  // system_settings 2개 메뉴 코드를 "운영·시스템관리" 1개 사이드바 행으로
  // 시각적으로 병합할 때만 사용한다(RBAC_MATRIX/canAccessMenu/getVisibleMenusForRole
  // 등 실제 권한 판정 로직에는 전혀 관여하지 않음 — 순수 하이라이트 표시용).
  matchPrefixes?: string[];
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
//     [신통방통 관리자 통합 간소화 실행 지시서 — 승인 지시 §2, 2단계 진행]
//     위 "off"(사이드바 노출만 제거) 조치에서 한 단계 더 나아가, 전수조사로
//     실사용 0건임을 재확인한 뒤 matching/profiles·likes-pairs·friends-follows·
//     chats 4개 page.tsx와 전용 컴포넌트/서버 액션을 실제로 삭제했다("off"→
//     "삭제" 전환). RBAC_MATRIX.matching 엔트리도 더는 참조하는 화면이 없어
//     함께 삭제. MatchingProfile/MatchingLike/MatchingPair/Friend/ChatRoom/
//     ChatMessage 등 Prisma 모델·테이블은 전혀 건드리지 않았다 — 특히
//     MatchingProfile은 lib/account-purge.ts(회원탈퇴 개인정보 파기)가 실제
//     참조 중이라 데이터 보존이 필수다.
//   - payments(결제/구독 관리): [신통방통 관리자 최종 간소화 실행 지시서 §3
//     "결제·구독 관리: 현재 구독 서비스를 운영하지 않으므로 노출하지 말 것"]
//     지시에 따라 비노출을 유지한다. [재확인 메모 — 과거 "실제 결제 플로우가
//     앱에 없다"는 기록은 부정확했다. 전수조사 결과 Flutter 앱에 /my/subscription,
//     /my/subscription/plans 화면과 SubscriptionRepository(→/api/public/subscription/
//     plans·my·subscribe·cancel·payments 5개 라이브 API)가 실제로 존재하고,
//     payments 14건·user_subscriptions 10건의 결제/구독 데이터도 DB에 있다.
//     즉 코드·API·DB는 전부 살아있는 기능이지만, 사용자가 "현재 구독 서비스를
//     운영하지 않는다"고 명시적으로 판단해 메뉴 노출 여부만 별도로 결정한
//     것이다(코드/DB 보존 ≠ 메뉴 노출). payments/list·plans·refunds·
//     revenue-report·subscriptions 5개 page.tsx와 RBAC_MATRIX.payments 엔트리는
//     전혀 수정하지 않았다 — URL을 알면 super_admin/operator가 여전히 접근
//     가능하고, 필요해지면 ADMIN_MENU_GROUPS에 1줄만 추가하면 즉시 복원된다.
//   - community(커뮤니티 관리): [신통방통 관리자 통합 간소화 실행 지시서] 전수조사 결과
//     boards/posts/comments/reports/likes/files 6개 하위 화면 전부 Flutter 앱에서
//     참조하는 api/public 엔드포인트가 없음을 재확인(ReportTargetType enum,
//     POST /api/public/reports, community/posts 등 레거시 커뮤니티 API 호출 코드가
//     lib 전체에 0건 — grep 전수 검색). community_posts(129건)/comments(wish 제외
//     127건)/reports(wish 제외 14건) 데이터도 전부 2026-05~09월 과거 흔적으로,
//     현재 라이브인 wish_room은 1건뿐이라 운영 중 데이터가 아님을 확인했다.
//     [승인 지시 §3, 2단계 진행] 위 "off"(사이드바 노출만 제거) 조치에서 한 단계
//     더 나아가, boards/posts/comments/reports/likes/files 6개 page.tsx와 전용
//     서버 액션(actions/community.ts, actions/comments.ts, actions/files.ts) +
//     전용 컴포넌트(CommunityBoardCreateForm/CommunityBoardRow/CommunityPostRow/
//     CommentRow/FileRow)를 실제로 삭제했다("off"→"삭제" 전환, 화면 코드 한정).
//     [DB/공용 코드 보존 — 절대 삭제 금지] Comment/Like/Report/File 4개 Prisma
//     모델·테이블은 wishroom(소원방, 현재 라이브)의 신고·댓글·응원 기능과
//     polymorphic(targetType/ownerType) 테이블을 공유하므로 데이터는 전혀
//     건드리지 않았다. actions/reports.ts(assignReportToMe/actionReport/
//     rejectReport)와 components/ReportRow.tsx도 wishroom/reports 화면이 동일
//     코드를 재사용 중이라 그대로 보존했다 — RBAC_MATRIX.community 엔트리 역시
//     이 파일의 canWriteReports()가 "community 또는 wishroom 둘 중 하나만
//     접근 가능해도 허용"하는 판정에 실제로 참조하므로 삭제하지 않는다(고아
//     권한코드가 아니라 wishroom 신고처리 권한 판정 로직의 일부로 계속 필요).
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
//   - "AI 콘텐츠 관리" → "6개콘텐츠관리"로 라벨만 변경(코드/경로 불변). 소원방/궁합은
//     task 5~8에서 허브로 통합 완료. [신통방통 관리자 최종 간소화 실행 지시서 §2]
//     귀인지도는 관리 화면이 전혀 없는 공백이었던 것을 재확인해 /ai-content/guinji
//     (조회 전용 — 지도/멤버/관계판정/바이럴 공유 현황)를 신설하고 AiContentSubNav에
//     탭을 추가했다(ai_content 권한코드 그대로 재사용, RBAC_MATRIX 변경 없음).
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
  // [신통방통 관리자 최종 간소화 실행 지시서 §3 "실제 사용하는 상품 기능만"]
  // [재확인] /shop/amulets는 사이드바/서브탭 어디에도 연결되어 있지 않은
  // 독립 URL이었고, Flutter 앱의 부적 상점 화면(talisman_shop_screen.dart)은
  // 이 화면이 다루는 AmuletItem/UserAmulet이 아니라 별도 모델(ShopCatalogItem
  // itemType="talisman" + UserInventoryItem)을 쓴다 — /api/public/amulets/*
  // 6개 API가 구현되어 있지만 Flutter 코드 전체에서 호출 0건. shop/amulets/
  // page.tsx 진입 시 /shop/luckybag로 리다이렉트하도록 처리했다(라우트/서버
  // 액션/Prisma 모델은 전부 보존). shop 메뉴 자체는 luckybag+giftcards 2개
  // 하위 화면이 각각 실사용 데이터와 Flutter 연동이 확인되어 그대로 유지한다.
  { code: "shop", label: "상점 관리", path: "/shop/luckybag", icon: "Store" },
  // [신통방통 관리자 최종 간소화 실행 지시서 §3 "공지사항·FAQ·이벤트·팝업 비노출"]
  // [재확인] Flutter 앱에 /api/public/notices, /api/public/faqs,
  // /api/public/events, /api/public/popups를 호출하는 코드가 전혀 없어(0건)
  // 4개 화면 모두 도달 불가능한 CMS였다. CMS 서브탭(각 page.tsx의 <nav>)에서
  // 공지사항/FAQ/이벤트 3개 링크를 제거하고(popups는 이미 이전 작업에서
  // 제거되어 있었음), notices/faqs/events 3개 page.tsx는 URL 직접 접근 시에도
  // /cms/banners로 리다이렉트하도록 처리했다 — 라우트 파일/서버 액션/Prisma
  // 모델(Notice/Faq/Event/EventParticipation/Popup)은 전혀 삭제하지 않았다.
  // 배너/행운숫자/힐링문구/인트로설정/메인화면편집 5개는 전부 대응 공개 API와
  // Flutter 실소비 코드가 확인되어 그대로 유지한다.
  { code: "cms", label: "CMS", path: "/cms/banners", icon: "FileText" },
  { code: "notifications", label: "알림 관리", path: "/notifications/templates", icon: "Bell" },
  // [신통방통 관리자 통합 간소화 실행 지시서 task 10 "운영/보안+시스템설정 최소
  // 메뉴로 통합"] 기존 "운영/보안"(ops_security, super_admin 전용)과 "시스템 설정"
  // (system_settings, super_admin+operator 열람 가능) 2개 최상위 사이드바 항목을
  // "운영·시스템관리" 1개 행으로 합친다.
  // [주의 — 권한 레벨 불일치 회귀 방지] 두 메뉴는 RBAC 권한 레벨이 다르다
  // (ops_security는 operator가 X, system_settings는 operator가 R). 사이드바 code를
  // 그대로 "ops_security"로 두면 operator가 system_settings 3개 화면으로 가는
  // 사이드바 진입점 자체를 완전히 잃는 회귀가 발생한다. 이를 막기 위해 "pass"/
  // "pouch"/"ad_management"가 "reward" 권한을 미러링하는 기존 패턴과 동일하게,
  // 사이드바 전용 신규 가상 코드 "ops_system"을 RBAC_MATRIX에 추가해 두 메뉴의
  // 열람 권한 합집합(super_admin: 전체, operator: system_settings만)을 미러링한다.
  // 랜딩 경로는 "/ops"(신규, 역할별로 /admin-users 또는 /system-settings로 즉시
  // 리다이렉트하는 서버 컴포넌트 — src/app/(admin)/ops/page.tsx 참고)로 설정해
  // super_admin/operator 모두 권한이 있는 첫 화면으로 바로 떨어지게 한다.
  // 7개 하위 page.tsx의 실제 접근 가드(canAccessMenu(roleCode,"ops_security"|
  // "system_settings"))와 RBAC_MATRIX.ops_security/system_settings 엔트리는 전혀
  // 변경하지 않았다(회귀 위험 제로 — 권한 소스는 기존 두 코드 그대로 유지).
  {
    code: "ops_system",
    label: "운영·시스템관리",
    path: "/ops",
    icon: "ShieldCheck",
    matchPrefixes: ["/admin-users", "/audit-logs", "/system-settings", "/ops"],
  },
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
  // [§8단계] 쿠폰 관리 화면을 삭제하며 RBAC_MATRIX.coupons 같은 별도 엔트리는
  // 애초에 없었다(쿠폰은 "shop" 메뉴코드 하위 화면이었음 — shop은 amulets/
  // luckybag/giftcards 3개 화면이 여전히 쓰므로 그대로 유지).
  shop: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  community: { super_admin: RWD, operator: RW, cs: RW, content_manager: R },
  // [신통방통 관리자 통합 간소화 실행 지시서 — 승인 지시 §2 "매칭 관리"]
  // matching_profiles/likes-pairs/friends-follows/chats 4개 관리자 화면(및
  // 전용 컴포넌트 MatchingProfileRow.tsx, 서버 액션 actions/matching.ts)을
  // 완전 삭제했다(Flutter 앱에 매칭 진입점이 없어 관리할 실사용 데이터가
  // 없음을 전수조사로 재확인, api/public/matching/* 라우트도 이미 §3단계에서
  // 무료화되어 사용되지 않음). "matching" RBAC_MATRIX 엔트리를 참조하는
  // 화면이 더는 없으므로 이 엔트리 자체도 함께 제거한다(고아 권한코드 방지).
  // [DB 보존] MatchingProfile 모델/테이블은 lib/account-purge.ts의 회원탈퇴
  // 개인정보 파기 로직(prisma.matchingProfile.updateMany)이 실제로 참조하므로
  // prisma/schema.prisma에서 절대 삭제하지 않는다 — 관리자 "화면"만 제거했다.
  payments: { super_admin: RWD, operator: R, cs: R, content_manager: X },
  cms: { super_admin: RWD, operator: RW, cs: R, content_manager: RW },
  notifications: { super_admin: RWD, operator: RW, cs: R, content_manager: RW },
  ops_security: { super_admin: RWD, operator: X, cs: X, content_manager: X },
  system_settings: { super_admin: RWD, operator: R, cs: X, content_manager: X },
  // [task 10] 사이드바 전용 신규 메뉴코드 — ops_security(super_admin만 R)와
  // system_settings(super_admin+operator R)의 합집합을 미러링한다("pass"/"pouch"/
  // "ad_management"가 "reward"를 미러링하는 기존 패턴과 동일). 실제 7개 하위
  // page.tsx의 접근 가드는 전부 canAccessMenu(roleCode,"ops_security") 또는
  // canAccessMenu(roleCode,"system_settings")를 그대로 쓰므로, 이 값은 사이드바
  // 노출 여부에만 영향을 준다(권한 소스 이원화 없음).
  ops_system: { super_admin: RWD, operator: R, cs: X, content_manager: X },
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
