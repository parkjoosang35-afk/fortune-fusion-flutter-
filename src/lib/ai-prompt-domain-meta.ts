// AI 프롬프트 템플릿 도메인 메타데이터 — /ai-content/prompts, /ai-content/prompts/[domain]
// 양쪽 화면에서 공유한다(중복 정의 방지).
//
// [11가지 콘텐츠 타입 확장] 기존 6개 도메인(saju/daily/tarot/face/palm/consultation)에서
// 사용자가 제공한 "동양 역학/타로/운세 전문가" 마스터 프롬프트의 11개 콘텐츠 타입을
// 반영해 5개 도메인을 추가한다: saju_wealth/saju_career/saju_love/saju_health/
// tarot_yesno/tarot_love/saju_monthly/compatibility/name (compatibility은 스키마
// 주석에 예정돼 있던 도메인 키를 그대로 사용).
export const DOMAIN_LABEL: Record<string, string> = {
  saju: "사주 종합운",
  daily: "오늘의 운세",
  tarot: "타로 종합운",
  face: "관상",
  palm: "손금",
  consultation: "AI 상담",
  saju_wealth: "오행 재운",
  saju_career: "사주 관운(직업운)",
  saju_love: "사주 연애운",
  saju_health: "사주 건강운",
  tarot_yesno: "타로 YES/NO",
  tarot_love: "타로 감정 관계운",
  saju_monthly: "사주 월별 운세",
  compatibility: "궁합 운세",
  name: "이름 운세(성명학)",
};

export const DOMAIN_ORDER = [
  "saju",
  "saju_wealth",
  "saju_career",
  "saju_love",
  "saju_health",
  "saju_monthly",
  "tarot",
  "tarot_yesno",
  "tarot_love",
  "compatibility",
  "name",
  "daily",
  "face",
  "palm",
  "consultation",
];
