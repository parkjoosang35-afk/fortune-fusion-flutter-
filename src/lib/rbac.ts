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
  icon?: string; // lucide-react 아이콘명(최상위 전용, 하위항목은 생략 가능)
  // [관리자 2.0 전면 재설계 - 6메뉴 구조] 하위 항목 자체가 다른 RBAC 메뉴코드로
  // 가드되는 "외부 화면"으로 가는 링크인 경우 true. 사이드바에는 그대로 노출하되,
  // 실제 read 가능 여부는 각 page.tsx가 자신의 canAccessMenu(원래 코드)로 최종 판정한다
  // (이 필드는 순수 UI용 — "↗" 표시 등. 접근 제어에는 관여하지 않음).
  external?: boolean;
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
// [2026-11-11 신통방통 관리자 2.0 전면 재설계 - 6메뉴 구조 전환]
// 사용자 확정 지시("보고서⑩ 신규 관리자 설계 제안" 기반, 승인 지시 전달)에 따라
// 기존 12개 최상위 사이드바 항목을 아래 6개 그룹으로 재편한다:
//   통합대시보드 / 콘텐츠관리 / 복주머니결제쿠폰 / 회원운영관리 / 광고외부연동 / AI시스템관리
//
// [핵심 원칙 — 회귀 위험 최소화] 기존 12개 실제 RBAC 코드(ai_content/wishroom/cms/
// pouch/bokju_coupon/shop/payments/users/notifications/ad_management/ops_security/
// system_settings)는 단 1개도 변경/삭제하지 않는다. 모든 하위 page.tsx의
// canAccessMenu(roleCode, "기존코드") 가드는 그대로 유지되며, 실제 접근 제어의
// 유일한 소스로 계속 기능한다. 이번 재편은 "어떤 코드가 어느 사이드바 그룹
// 아래에 보이는지"라는 순수 UI 트리 재배치일 뿐이다(기존 pass/pouch/
// ad_management가 "reward" 권한을 미러링하던 패턴과 동일한 설계 철학).
//
// [신규 6개 최상위 가상 코드] 아래 6개는 전부 사이드바 그룹 "펼침" 여부만
// 판정하는 신규 가상 코드다(RBAC_MATRIX에 하위 자식 코드들의 권한 합집합(OR)을
// 미러링해 등록 — 아래 §RBAC_MATRIX 주석에 그룹별 합집합 산출 근거 명시).
// 실제로 사이드바에 보이는 "자식" 항목들은 getVisibleMenusForRole()에서
// 자기 자신의 진짜 코드로 다시 한번 개별 필터링되므로(각 child.code가 바로
// 기존 real RBAC 코드), 접근 불가능한 하위 화면 링크가 노출되는 일은 없다.
//
// [CMS/알림관리 재배치 결정 — 사용자가 명시하지 않은 부분, 직접 결정]
// 사용자가 확정한 6개 그룹명에는 CMS/알림관리가 명시되어 있지 않았으나 둘 다
// 실사용 중인 화면이라 삭제 대상이 아니므로, 성격에 맞춰 아래처럼 재배치한다
// (추후 이견 있으면 그룹만 다시 옮기면 됨 — 코드/권한 변경 없이 그룹 소속만
// 바뀌는 구조이므로 수정 비용이 거의 없다):
//   - CMS(배너/행운숫자/힐링문구/인트로/메인화면편집) → "콘텐츠관리"(사용자에게
//     노출되는 콘텐츠라는 성격이 9개 콘텐츠와 동일)
//   - 알림 관리(템플릿/세그먼트발송/이력/설정) → "회원운영관리"(회원과의
//     커뮤니케이션 채널이라는 성격)
//
// [신규 리프 화면의 RBAC 코드] 프리미엄사주/도완녀상담/1:1고객문의/AI자동진단/
// 외부연동현황/복주머니결제쿠폰 통합현황은 전부 이번에 신설하는 화면이라 전용
// RBAC 코드가 없다. 새 코드를 늘리는 대신 성격이 가장 가까운 기존 코드를
// 재사용한다(실제 read/write 판정은 재사용한 코드가 그대로 담당):
//   - 프리미엄사주 PDF 템플릿 관리, 도완녀상담 상태머신 → "ai_content"(콘텐츠팀 관할)
//   - 1:1 고객문의 → "users"(회원 대응 업무, cs 역할이 RW 가능해야 함과 일치)
//   - AI 자동진단(서버/엔진 상태) → "ops_system"(시스템 관리자 전용)
//   - 광고외부연동 매트릭스(외부서비스 연동현황) → "ad_management"(reward 미러링)
//   - 복주머니결제쿠폰 통합현황 랜딩 → "pouch"(reward 미러링)
export const ADMIN_MENU_GROUPS: AdminMenuGroup[] = [
  { code: "dashboard", label: "통합대시보드", path: "/dashboard", icon: "LayoutDashboard" },

  // ── 2) 콘텐츠관리 ──────────────────────────────────────────────
  {
    code: "content_mgmt",
    label: "콘텐츠관리",
    path: "/ai-content/prompts",
    icon: "Sparkles",
    matchPrefixes: ["/ai-content", "/wishroom", "/cms"],
    children: [
      { code: "ai_content", label: "9개 콘텐츠 운영(AI/프롬프트)", path: "/ai-content/prompts" },
      { code: "wishroom", label: "소원방 운영", path: "/wishroom/reports" },
      { code: "cms", label: "CMS(배너·행운숫자·인트로)", path: "/cms/banners" },
      // [Task12a/12b 신규 서비스] 아직 기획 단계 — "ai_content" 코드를 재사용한
      // 스켈레톤 화면으로 시작(실데이터/워크플로 없이 상태/안내만 표시).
      { code: "ai_content", label: "프리미엄 사주(기획중)", path: "/ai-content/premium-saju" },
      { code: "ai_content", label: "도완녀 상담(기획중)", path: "/ai-content/dowanyeo" },
    ],
  },

  // ── 3) 복주머니결제쿠폰 ────────────────────────────────────────
  {
    code: "pouch_payment",
    label: "복주머니결제쿠폰",
    path: "/pouch-payment",
    icon: "Gift",
    matchPrefixes: ["/pouch-payment", "/reward/luck-pouch-rules", "/reward/policies",
      "/reward/missions", "/reward/ranking", "/reward/operation-logs",
      "/bokju-coupons", "/shop", "/payments"],
    children: [
      { code: "pouch", label: "① 통합 현황", path: "/pouch-payment" },
      { code: "pouch", label: "② 복주머니 규칙/정책", path: "/reward/luck-pouch-rules" },
      { code: "bokju_coupon", label: "③ 마케팅 쿠폰", path: "/bokju-coupons/campaigns" },
      { code: "shop", label: "④ 상점(복주머니뽑기/상품권)", path: "/shop/luckybag" },
      { code: "payments", label: "⑤ 결제/구독(정책준비중)", path: "/payments/plans" },
      { code: "pouch", label: "⑥ 거래내역", path: "/reward/operation-logs" },
    ],
  },

  // ── 4) 회원운영관리 ────────────────────────────────────────────
  {
    code: "member_ops",
    label: "회원운영관리",
    path: "/users",
    icon: "Users",
    matchPrefixes: ["/users", "/wishroom/reports", "/member-ops", "/admin-users/roles",
      "/notifications"],
    children: [
      { code: "users", label: "회원·이용내역", path: "/users" },
      { code: "wishroom", label: "신고 통합 처리함", path: "/wishroom/reports" },
      // [Task9c 신규] 1:1 고객문의 — "users" 코드 재사용(cs 역할 RW 요건과 일치).
      { code: "users", label: "1:1 고객문의", path: "/member-ops/inquiries" },
      // [Task9a] 과거 "역할/권한 매트릭스" 편집 화면을 조회 전용으로 전환.
      // ops_security 코드를 그대로 재사용(super_admin만 read 가능 — 기존과 동일).
      { code: "ops_security", label: "역할/권한 매트릭스(조회전용)", path: "/admin-users/roles" },
      { code: "notifications", label: "알림 관리", path: "/notifications/templates" },
    ],
  },

  // ── 5) 광고외부연동 ────────────────────────────────────────────
  {
    code: "ad_external",
    label: "광고외부연동",
    path: "/reward/fortune-ads",
    icon: "Megaphone",
    matchPrefixes: ["/reward/fortune-ads", "/ad-external"],
    children: [
      { code: "ad_management", label: "쿠팡/AdMob 리워드 광고", path: "/reward/fortune-ads" },
      // [Task10 신규] 바로가기 링크 + 실제 연동상태 표시(AdMob/AdSense/GooglePlay/
      // Kakao/Anthropic/OpenAI 등) — "ad_management" 코드 재사용.
      { code: "ad_management", label: "외부서비스 연동 현황", path: "/ad-external/integrations" },
    ],
  },

  // ── 6) AI시스템관리 ────────────────────────────────────────────
  // [신통방통 관리자 통합 간소화 실행 지시서 task 10에서 신설했던 "운영·
  // 시스템관리"(ops_system, ops_security+system_settings 미러링) 그룹을
  // "AI시스템관리"로 재편입한다. 실제 하위 7개 page.tsx의 canAccessMenu 가드는
  // 전혀 변경하지 않는다(ops_security/system_settings 코드 그대로 유지).
  {
    code: "ai_system",
    label: "AI시스템관리",
    path: "/ops",
    icon: "ShieldCheck",
    matchPrefixes: ["/admin-users", "/audit-logs", "/system-settings", "/ops",
      "/ai-content/logs", "/ai-system"],
    children: [
      { code: "ops_system", label: "서버/시스템 상태", path: "/ops" },
      // [Task11 신규] 3단계 자동진단(탐지→진단→승인게이트 조치) — "ops_system" 재사용.
      { code: "ops_system", label: "AI 자동진단", path: "/ai-system/diagnosis" },
      // [2026-11-12 사주엔진관리 신규] saju_engine_deploy(별도 저장소, FastAPI,
      // 운영서버 systemd "saju-engine.service"로 상시 구동) 전체를 조회·제한적
      // 제어할 수 있는 신규 화면. "ops_system"(서버/시스템 상태와 동일 코드) 재사용 —
      // 신규 RBAC 코드를 늘리지 않고 "시스템 관리자 전용"이라는 성격이 동일하기 때문.
      { code: "ops_system", label: "🔮 사주엔진관리", path: "/ai-system/saju-engine" },
      { code: "ai_content", label: "AI 호출 로그/비용", path: "/ai-content/logs" },
      { code: "ops_security", label: "관리자 계정/역할(RBAC)", path: "/admin-users" },
      { code: "system_settings", label: "전역 설정값/에러로그", path: "/system-settings" },
    ],
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
  // [복주머니 마케팅 쿠폰 최종본] 신규 독립 메뉴. 위 §8단계에서 삭제된 "shop"
  // 하위 구 쿠폰 화면과는 완전히 다른 도메인(BokjuCoupon*)이므로 별도 코드로 분리.
  bokju_coupon: { super_admin: RWD, operator: RW, cs: R, content_manager: R },
  // [§8단계] 쿠폰 관리 화면을 삭제하며 RBAC_MATRIX.coupons 같은 별도 엔트리는
  // 애초에 없었다(쿠폰은 "shop" 메뉴코드 하위 화면이었음 — shop은 amulets/
  // luckybag 2개 화면이 여전히 쓰므로 그대로 유지).
  // [2026-11 정책변경] 상품권(giftcard) 교환 상점 기능 전체 삭제(관리자 화면 포함).
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

  // ════════════════════════════════════════════════════════════════
  // [2026-11-11 관리자 2.0 전면 재설계 - 6개 최상위 사이드바 그룹 가상 코드]
  // 아래 6개는 전부 "그룹 펼침 여부"만 판정하는 사이드바 전용 코드다. 각 그룹의
  // 실제 자식 메뉴 항목은 위 ADMIN_MENU_GROUPS[].children[].code에 적힌 "진짜"
  // RBAC 코드로 개별 가드되므로(getVisibleMenusForRole 참고), 여기 값은 "이 그룹을
  // 최소 1개라도 펼쳐볼 수 있는 역할인가"를 판정하는 합집합(OR)이다 — 자식 코드들의
  // read 권한 중 하나라도 true면 OR 결과도 true로 산출(값을 복붙이 아니라 OR 연산
  // 결과를 그대로 적어 넣었다). 자식 코드의 실제 RBAC_MATRIX 값이 바뀌면 이 합집합도
  // 함께 재계산해야 한다(권한 소스 이원화 금지 원칙 — "pass"/"pouch"가 "reward"를
  // 미러링하던 기존 패턴과 동일한 설계).
  // ════════════════════════════════════════════════════════════════

  // content_mgmt 합집합 = ai_content ∨ wishroom ∨ cms
  //   super_admin: RWD∨RWD∨RWD = RWD
  //   operator:    R∨RW∨RW     = RW
  //   cs:          R∨RW∨R      = RW
  //   content_manager: RW∨R∨RW = RW
  content_mgmt: { super_admin: RWD, operator: RW, cs: RW, content_manager: RW },

  // pouch_payment 합집합 = pouch ∨ bokju_coupon ∨ shop ∨ payments
  //   super_admin: RWD(전부)                     = RWD
  //   operator:    RW∨RW∨RW∨R                    = RW
  //   cs:          R∨R∨R∨R                       = R
  //   content_manager: R∨R∨R∨X                   = R
  pouch_payment: { super_admin: RWD, operator: RW, cs: R, content_manager: R },

  // member_ops 합집합 = users ∨ wishroom ∨ ops_security ∨ notifications
  //   super_admin: RWD(전부)                                = RWD
  //   operator:    RW∨RW∨X∨RW                               = RW
  //   cs:          RW∨RW∨X∨R                                = RW
  //   content_manager: R∨R∨X∨RW                             = RW
  member_ops: { super_admin: RWD, operator: RW, cs: RW, content_manager: RW },

  // ad_external 합집합 = ad_management(단일 자식, 외부연동 현황도 동일 코드 재사용)
  ad_external: { super_admin: RWD, operator: RW, cs: R, content_manager: R },

  // ai_system 합집합 = ops_system ∨ ai_content ∨ ops_security ∨ system_settings
  //   super_admin: RWD(전부)                                      = RWD
  //   operator:    R∨R∨X∨R                                       = R
  //   cs:          X∨R∨X∨X                                       = R(ai_content만 R)
  //   content_manager: X∨RW∨X∨X                                  = RW(ai_content만 RW)
  // [주의] ai_content의 cs=R/content_manager=RW가 섞여 들어와 그룹 자체의 노출
  // 조건은 느슨해지지만, 실제로는 "AI 호출 로그" 자식 항목 1개만 보이고 나머지
  // ops_system/ops_security/system_settings 자식 항목은 각자 코드로 다시
  // 개별 필터링되어 cs/content_manager에게는 보이지 않는다(그룹 레벨 OR과
  // 자식 레벨 AND 필터가 함께 작동 — getVisibleMenusForRole 주석 참고).
  ai_system: { super_admin: RWD, operator: R, cs: R, content_manager: RW },
};

export function canAccessMenu(roleCode: string, menuCode: string): boolean {
  const perm = RBAC_MATRIX[menuCode]?.[roleCode as AdminRoleCode];
  return !!perm?.read;
}

// [2026-11-11 관리자 2.0 전면 재설계] admin-users/roles(역할/권한 매트릭스 조회
// 화면)는 과거 ADMIN_MENU_GROUPS.map(m => m.code)로 "최상위 사이드바 코드 =
// 실제 권한 코드"라고 가정하고 행을 그렸으나, 6메뉴 구조 전환 후에는 최상위
// 6개가 전부 사이드바 전용 가상 코드(content_mgmt 등)라 더는 성립하지 않는다.
// 대신 RBAC_MATRIX에 실제로 등록된 "진짜" 메뉴 코드 전체(사이드바 가상 코드
// 포함, dashboard부터 ai_system까지)를 그대로 노출해 admin_permissions 테이블의
// 모든 menu_code를 빠짐없이 조회/편집할 수 있게 한다(§Task9a 읽기전용 전환과
// 별개로, "어떤 코드가 존재하는지"는 여기서 가져온다).
export function getAllMenuCodes(): string[] {
  return Object.keys(RBAC_MATRIX);
}

// [Task9a] 역할/권한 매트릭스 조회 화면이 menu_code를 한글 라벨로 표시할 때 쓰는
// 매핑. ADMIN_MENU_GROUPS는 이제 최상위 6개(+그 children)만 갖고 있어 모든 실제
// 코드를 담고 있지 않으므로, RBAC_MATRIX의 모든 키에 대응하는 라벨을 별도로
// 유지한다(신규 코드 추가 시 이 테이블에도 함께 추가할 것).
export const MENU_CODE_LABELS: Record<string, string> = {
  dashboard: "통합대시보드",
  users: "회원·이용내역",
  ai_content: "9개 콘텐츠 운영(AI/프롬프트)",
  wishroom: "소원방 운영(신고/후기승인)",
  reward: "(레거시) 리워드 관리",
  pass: "프리패스관리",
  pouch: "복주머니관리",
  ad_management: "광고관리",
  bokju_coupon: "마케팅 쿠폰",
  shop: "상점 관리",
  community: "(레거시) 커뮤니티 관리",
  payments: "결제/구독(정책준비중)",
  cms: "CMS",
  notifications: "알림 관리",
  ops_security: "운영/보안(관리자계정·역할)",
  system_settings: "시스템 설정",
  ops_system: "운영·시스템관리(통합)",
  content_mgmt: "[그룹] 콘텐츠관리",
  pouch_payment: "[그룹] 복주머니결제쿠폰",
  member_ops: "[그룹] 회원운영관리",
  ad_external: "[그룹] 광고외부연동",
  ai_system: "[그룹] AI시스템관리",
};

// [2026-11-11 관리자 2.0 전면 재설계 - 6메뉴 구조] 그룹(최상위) 레벨 필터링 +
// 자식(하위 리프) 레벨 필터링을 이중으로 적용한다.
// 1단계: 그룹 자체의 가상 코드(content_mgmt 등)로 "이 그룹을 펼쳐볼 자격이
//   있는 역할인가"를 먼저 거른다(합집합 OR 판정).
// 2단계: 그룹을 통과했어도, 각 자식 항목은 자신의 "진짜" RBAC 코드(ai_content/
//   wishroom/cms 등 — ADMIN_MENU_GROUPS[].children[].code)로 다시 한번
//   개별 필터링한다. 이 2단계가 있어야 "그룹은 보이지만 그 안의 특정 화면은
//   이 역할에게 안 보여야 하는" 케이스(예: content_manager는 content_mgmt
//   그룹 자체는 보이지만 wishroom 쓰기만 불가, ai_system 그룹에서 cs/
//   content_manager는 ai_content 로그 화면 1개만 보이고 나머지는 숨김)가
//   올바르게 처리된다. children이 없는 평면 그룹(dashboard)은 그대로 통과.
export function getVisibleMenusForRole(roleCode: string): AdminMenuGroup[] {
  return ADMIN_MENU_GROUPS.filter((menu) => canAccessMenu(roleCode, menu.code)).map((menu) => {
    if (!menu.children) return menu;
    return {
      ...menu,
      children: menu.children.filter((child) => canAccessMenu(roleCode, child.code)),
    };
  });
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
