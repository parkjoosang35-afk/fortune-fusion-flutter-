// [2026-11-11 기획_01_콘텐츠운영_화면설계 — "콘텐츠 1개 = 관리 화면 1개"]
// 9개 라이브 콘텐츠 + 신규 2개(프리미엄 사주/도완녀 상담)의 공통 메타데이터.
// Server Component(overview/[contentKey] 페이지)와 Server Action
// (content-ops.ts)이 이 파일을 공유한다(화이트리스트 단일 소스).
//
// [설계 원칙 — 기획서 §6 재확인]
//   탭①기본설정/②프롬프트/③가격·차감 — 기존 FortuneCategory/AiPromptTemplate/
//   코드 하드코딩을 "그대로 보여주고 링크 연결"만 한다(중복 테이블·로직 생성 금지).
//   탭④노출제어 — 이번에 신설한 ContentOpsConfig가 유일하게 실제로 쓰기(CUD)를
//   제공하는 신규 기능이다(기획서가 강조한 "장애 대응을 관리자가 직접 할 수
//   있게"의 핵심).
//   탭⑤통계 — AiRequestLog/각 콘텐츠 전용 테이블에서 조회 전용으로 집계한다.
//
// [Q3 확정값 반영] pricingNote는 "현재 적용 중인 차감 방식/금액이 어디서
// 결정되는지"를 설명하는 조회용 텍스트일 뿐, 이 화면에서 실제 금액을 수정하는
// 기능은 제공하지 않는다(사장님 확정 기본값: "가격은 당분간 고정값 유지").
export interface ContentOpsItem {
  contentKey: string;
  label: string;
  /** 9개 라이브 콘텐츠 그룹("live") vs 신규 기획중 서비스("new")  */
  group: "live" | "new";
  description: string;
  /** 탭② 프롬프트 — 연결할 기존 AiPromptTemplate 도메인 키(없으면 해당 없음 표시) */
  promptDomains: string[];
  /** 탭② 프롬프트 — 도메인이 아예 없을 때(엔진 결정론적 계산 등) 사유 안내 */
  promptNote?: string;
  /** 탭① 기본설정 — 연결할 기존 FortuneCategory 카테고리 키(있으면 노출 설정 링크 제공) */
  categoryKeys: string[];
  /** 탭③ 가격/차감 — 조회 전용 설명(실제 차감 로직 코드 위치 안내 포함) */
  pricingNote: string;
  /** 탭③ 가격/차감 — 현재 적용 방식 라벨(기획서 §4 매핑표 그대로) */
  pricingMethodLabel: string;
  /** 다른 관리 화면이 이미 있으면 안내 링크(중복 구현 방지, 그대로 링크만 연결) */
  existingAdminLink?: { href: string; label: string };
}

export const CONTENT_OPS_ITEMS: ContentOpsItem[] = [
  {
    contentKey: "saju",
    label: "정통사주",
    group: "live",
    description: "생년월일시 기반 사주팔자 종합/오행/직업/연애/건강/월별 운세.",
    promptDomains: ["saju", "saju_wealth", "saju_career", "saju_love", "saju_health", "saju_monthly"],
    categoryKeys: ["saju", "saju_wealth", "saju_career", "saju_love", "saju_health", "saju_monthly"],
    pricingMethodLabel: "결과보기 공용게이트",
    pricingNote:
      "전역 설정값 economy_config.result_access_pouch_price_default(기본 100P)을 공용으로 사용합니다. 프리패스 보유 시 면제, 광고 시청 시 무료 제공(ResultAccessService). 이 화면에서는 금액을 수정하지 않습니다 — 수정은 DB 직접 반영만 가능(Q3 확정: 당분간 고정).",
    existingAdminLink: { href: "/ai-content/categories", label: "운세 카테고리 노출 설정" },
  },
  {
    contentKey: "tarot",
    label: "타로",
    group: "live",
    description: "65개 주제 타로카드 기반 운세 해석(종합/YES-NO/감정관계).",
    promptDomains: ["tarot", "tarot_yesno", "tarot_love"],
    categoryKeys: ["tarot", "tarot_yesno", "tarot_love"],
    pricingMethodLabel: "결과보기 공용게이트",
    pricingNote: "정통사주와 동일한 공용게이트(ResultAccessService)를 공유합니다. 콘텐츠별 예외가격은 현재 설정되어 있지 않습니다.",
    existingAdminLink: { href: "/ai-content/tarot-topics", label: "타로 65개 주제 관리" },
  },
  {
    contentKey: "wishroom",
    label: "소원방",
    group: "live",
    description: "소원 게시글 작성/응원(복주머니 송금형)/후기 커뮤니티.",
    promptDomains: [],
    promptNote: "AI 생성 콘텐츠가 아닌 사용자 작성 게시글이라 프롬프트 템플릿이 없습니다.",
    categoryKeys: [],
    pricingMethodLabel: "송금형(다른 유저에게 보내기)",
    pricingNote: "복주머니 '송금형' — economy_config.daily_send_limit(1인 1일 한도)로 제어됩니다. 레벨 승급(촛불)은 누적 bokjuCount 기준이며 1건당 고정 차감액 개념이 없습니다.",
    existingAdminLink: { href: "/reward/policies", label: "복(福) 경제 설정(송금 한도 등)" },
  },
  {
    contentKey: "talisman",
    label: "부적신당",
    group: "live",
    description: "사주 기반 맞춤 부적(신당) 발급 — 65종 부적 중 선택, 49일 소지.",
    promptDomains: [],
    promptNote: "부적 해석 문구는 TalismanItem 마스터 데이터(고정 문구)로 관리되며 AI 프롬프트 템플릿을 사용하지 않습니다.",
    categoryKeys: [],
    pricingMethodLabel: "결과보기 공용게이트(동일 패턴 자체구현)",
    pricingNote: "ShrineOrder 생성은 ResultAccessTransaction(공용게이트) 1건을 전제로 합니다. 금액은 정통사주와 동일한 전역 설정을 공유합니다.",
  },
  {
    contentKey: "guinji",
    label: "귀인지도",
    group: "live",
    description: "지인 관계망 기반 귀인/오른팔/인연 등 관계유형 판정 지도.",
    promptDomains: [],
    promptNote: "관계유형 판정은 guinji-relation-judger.ts가 결정론적으로 계산합니다(LLM 미사용 — 코드 로직 수정 필요).",
    categoryKeys: [],
    pricingMethodLabel: "지도열람=공용게이트 / 스페셜해금=광고·포인트·프리패스 3택",
    pricingNote: "지도 생성 시 공용게이트 1회, 스페셜 관계 해금은 광고시청/포인트차감/프리패스 중 선택하는 3택 구조입니다(세부 로직은 코드 참조).",
    existingAdminLink: { href: "/ai-content/guinji", label: "귀인지도 현황 조회(조회 전용)" },
  },
  {
    contentKey: "compatibility",
    label: "궁합지도(사주기반)",
    group: "live",
    description: "두 사람의 사주를 비교하는 궁합 운세(연애/친구/사업/가족).",
    promptDomains: ["compatibility"],
    categoryKeys: ["compatibility"],
    pricingMethodLabel: "결과보기 공용게이트",
    pricingNote: "정통사주와 동일한 공용게이트를 공유합니다.",
  },
  {
    contentKey: "gunghap",
    label: "궁합지도(초대형)",
    group: "live",
    description: "초대 링크로 상대방이 직접 입력해 보는 궁합지도(8분야 판정).",
    promptDomains: [],
    promptNote: "LLM 해석은 코드(gunghap-interpret-service.ts)가 직접 호출합니다 — DB 템플릿이 아닌 코드 하드코딩 프롬프트라 이 화면에서 편집할 수 없습니다(개발팀 작업 필요).",
    categoryKeys: [],
    pricingMethodLabel: "잠금해제형(100P 고정)",
    pricingNote: "GUNGHAP_UNLOCK_AMOUNT=100이 unlock/route.ts에 코드 상수로 고정되어 있습니다. 동일 보고서 재열람 시 중복 차감 없음(멱등), LLM 생성 실패 시 자동 환불 로직이 이미 존재합니다. 금액 수정은 코드 배포가 필요합니다(Q3 확정: 당분간 고정).",
  },
  {
    contentKey: "face",
    label: "관상",
    group: "live",
    description: "얼굴 사진 기반 관상 해석.",
    promptDomains: ["face"],
    categoryKeys: ["face"],
    pricingMethodLabel: "결과보기 공용게이트",
    pricingNote: "정통사주와 동일한 공용게이트를 공유합니다. 최근 24시간 내 '표현레이어 JSON 파싱 실패' 등 오류 이력이 있어 탭⑤에서 주의 깊게 모니터링이 필요합니다.",
  },
  {
    contentKey: "palm",
    label: "손금",
    group: "live",
    description: "손바닥 사진 기반 손금 해석.",
    promptDomains: ["palm"],
    categoryKeys: ["palm"],
    pricingMethodLabel: "결과보기 공용게이트",
    pricingNote: "정통사주와 동일한 공용게이트를 공유합니다.",
  },
  {
    contentKey: "premium_saju",
    label: "프리미엄 사주(PDF, 기획중)",
    group: "new",
    description: "PDF 형태로 제공되는 심화 프리미엄 사주 해석(Task12b, 1차 범위: 섹션 템플릿 버전관리만).",
    promptDomains: [],
    promptNote: "PDF 섹션별 템플릿은 전용 PremiumSajuSection 버전관리 화면에서 관리합니다(아래 링크).",
    categoryKeys: [],
    pricingMethodLabel: "미정(PDF 렌더링/결제 플로우는 1차 범위 밖)",
    pricingNote: "엔진 선택(saju_engine vs TopicEngine)·실제 PDF 렌더링·결제 플로우는 보고서⑩에서 '대표자 결정 필요'로 명시된 미해결 영역입니다 — 이번 작업 범위에 포함하지 않습니다.",
    existingAdminLink: { href: "/ai-content/premium-saju", label: "PDF 섹션 템플릿 버전관리" },
  },
  {
    contentKey: "dowanyeo",
    label: "도완녀 상담(기획중)",
    group: "new",
    description: "상담사 배정 기반 AI 상담 서비스(Task12a, 1차 범위: 관리자 수동배정 상태머신만).",
    promptDomains: [],
    promptNote: "실시간 채팅/화상 상담 기능이 없어(1차 범위 밖) 프롬프트 템플릿 연동 대상이 아닙니다.",
    categoryKeys: [],
    pricingMethodLabel: "미정(실시간 채팅/예약/정산 플로우는 1차 범위 밖)",
    pricingNote: "실시간 채널 선택·예약 슬롯·정산·신원확인은 보고서⑩에서 '대표자 결정 필요'로 명시된 미해결 영역입니다. 취소 시 환불은 기존 WalletService 트랜잭션 패턴으로 이미 구현되어 있습니다(dowanyeo.ts의 cancelRequest).",
    existingAdminLink: { href: "/ai-content/dowanyeo", label: "상담사/신청 관리" },
  },
];

export const CONTENT_OPS_ORDER = CONTENT_OPS_ITEMS.map((i) => i.contentKey);

export function getContentOpsItem(contentKey: string): ContentOpsItem | undefined {
  return CONTENT_OPS_ITEMS.find((i) => i.contentKey === contentKey);
}

export const EXPOSURE_STATUS_LABEL: Record<string, string> = {
  visible: "노출",
  hidden: "숨김",
  maintenance: "점검중",
};
