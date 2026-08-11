// 소원방(Wish Room) 관리자 설정(wish_room_config) 메타데이터.
// wish-config-meta.ts(소원성/Wish Castle)와 동일한 패턴: "use server" 액션 파일은
// async function만 export 가능하므로, 화이트리스트 상수는 별도 파일로 분리해
// Server/Client 양쪽에서 공유한다.
//
// [정본 출처] prisma/seed_wish_room.ts의 CONFIGS 배열(12개 키) — 이 파일은 그
// 12개 키 각각에 대한 관리자 CMS 표시용 메타데이터(label/valueType/단위/범위/설명)만
// 정의한다. 실제 기본값/설명 원문은 seed 스크립트가 최초 1회 DB에 씨딩하며,
// 이후로는 DB(wish_room_config 테이블)에 저장된 값이 단일 진실 원천이 된다.
export const WISH_ROOM_CONFIG_KEYS = [
  {
    key: "wish_room_max_wish_count",
    label: "최대 동시 보유 소원 개수",
    valueType: "number" as const,
    unit: "개",
    min: 1,
    max: 20,
    step: 1,
    defaultValue: "3",
    description: "회원 1인당 동시 보유 가능한 최대 소원 개수(대표1+서브2 구조 기준).",
  },
  {
    key: "wish_room_care_daily_free_count",
    label: "하루 무료 힘주기 횟수",
    valueType: "number" as const,
    unit: "회/일",
    min: 0,
    max: 10,
    step: 1,
    defaultValue: "1",
    description: "하루 무료로 힘주기(돌보기)를 할 수 있는 횟수. 초과 시 DAILY_LIMIT_REACHED 오류가 반환됩니다.",
  },
  {
    key: "wish_room_care_energy_gain",
    label: "힘주기 1회당 에너지 증가량",
    valueType: "number" as const,
    unit: "에너지",
    min: 1,
    max: 1000,
    step: 1,
    defaultValue: "20",
    description: "힘주기(돌보기) 1회당 소원의 에너지가 증가하는 양.",
  },
  {
    key: "wish_room_max_energy",
    label: "소원 최대 에너지치",
    valueType: "number" as const,
    unit: "에너지",
    min: 1,
    max: 100000,
    step: 1,
    defaultValue: "300",
    description: "소원 하나가 가질 수 있는 최대 에너지치(성장 상한 기준값).",
  },
  {
    key: "wish_room_decay_day1_amount",
    label: "미접속 1일 경과 감쇠량",
    valueType: "number" as const,
    unit: "에너지",
    min: 0,
    max: 1000,
    step: 1,
    defaultValue: "5",
    description: "마지막 돌봄 이후 1일이 경과하면 감소하는 에너지량.",
  },
  {
    key: "wish_room_decay_day2_amount",
    label: "미접속 2일 경과 추가 감쇠량",
    valueType: "number" as const,
    unit: "에너지",
    min: 0,
    max: 1000,
    step: 1,
    defaultValue: "10",
    description: "마지막 돌봄 이후 2일이 경과하면 1일차 감쇠량에 추가로 감소하는 에너지량(누적 단계합).",
  },
  {
    key: "wish_room_decay_day3_amount",
    label: "미접속 3일 경과 추가 감쇠량",
    valueType: "number" as const,
    unit: "에너지",
    min: 0,
    max: 1000,
    step: 1,
    defaultValue: "15",
    description: "마지막 돌봄 이후 3일 이상 경과하면 앞선 감쇠량에 추가로 감소하는 에너지량(누적 단계합).",
  },
  {
    key: "wish_room_decay_day7_plus_amount",
    label: "미접속 7일 이상 추가 감쇠량",
    valueType: "number" as const,
    unit: "에너지",
    min: 0,
    max: 1000,
    step: 1,
    defaultValue: "25",
    description: "마지막 돌봄 이후 7일 이상 경과 시(1회만) 추가로 감소하는 에너지량.",
  },
  {
    key: "wish_room_entry_animation_enabled",
    label: "입장 애니메이션 ON/OFF",
    valueType: "boolean" as const,
    unit: "",
    defaultValue: "true",
    description: "소원방 입장 시 풀 시퀀스 애니메이션(암전→별→은하수→달) 노출 여부.",
  },
  {
    key: "wish_room_lucky_bag_animation_enabled",
    label: "복주머니 적립 연출 ON/OFF",
    valueType: "boolean" as const,
    unit: "",
    defaultValue: "true",
    description: "복주머니 적립 시 풀 연출(개봉/폭발/파티클) 노출 여부.",
  },
  {
    key: "wish_room_guide_auto_show_on_first_visit",
    label: "최초 진입 가이드 자동 노출",
    valueType: "boolean" as const,
    unit: "",
    defaultValue: "true",
    description: "최초 진입 시 가이드 레이어(6슬라이드)를 자동으로 노출할지 여부.",
  },
  {
    key: "wish_room_representative_change_cooldown_hours",
    label: "대표 소원 변경 재변경 대기시간",
    valueType: "number" as const,
    unit: "시간",
    min: 0,
    max: 720,
    step: 1,
    defaultValue: "24",
    description:
      "⚠️ 현재 API(wishes/[id]/represent/route.ts)에서 사용되지 않는 미연동 설정입니다. " +
      "대표 소원 변경은 현재 쿨다운 없이 즉시 적용됩니다. 이 값을 실제로 적용하려면 " +
      "represent 라우트에 쿨다운 검증 로직을 추가하는 별도 작업이 필요합니다.",
  },
] as const;

export type WishRoomConfigKey = (typeof WISH_ROOM_CONFIG_KEYS)[number]["key"];
