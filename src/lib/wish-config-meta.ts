// 소원성(Wish Castle) 관리자 설정(wish_config) 메타데이터.
// economy-config-meta.ts와 동일한 패턴: "use server" 액션 파일은 async function만
// export 가능하므로, 화이트리스트 상수는 별도 파일로 분리해 Server/Client 양쪽에서 공유한다.
//
// [설계] 촛불 5레벨(0~4) 중 레벨0(작은촛불)은 시작 상태이므로 임계값이 없고,
// 레벨1~4로 "승급"하기 위한 누적 복주머니(bokjuCount) 임계값만 4개 설정한다.
// value는 모두 문자열로 저장하며(wish_config.value: String), 타입별 파싱 규칙은
// 아래 valueType으로 구분한다.
export const WISH_CANDLE_LEVELS = [
  { level: 0, name: "작은 촛불", emoji: "🕯️" },
  { level: 1, name: "희망의 불꽃", emoji: "🔥" },
  { level: 2, name: "따뜻한 불꽃", emoji: "🔥" },
  { level: 3, name: "축복의 불꽃", emoji: "✨" },
  { level: 4, name: "가장 밝은 불꽃", emoji: "🌟" },
] as const;

export const WISH_CONFIG_KEYS = [
  {
    key: "candle_level_1_threshold",
    label: "레벨1(희망의 불꽃) 승급 기준",
    valueType: "number" as const,
    unit: "복주머니",
    min: 1,
    max: 100000,
    step: 1,
    defaultValue: "10",
    description: "누적 복주머니가 이 값 이상이면 레벨1로 승급합니다.",
  },
  {
    key: "candle_level_2_threshold",
    label: "레벨2(따뜻한 불꽃) 승급 기준",
    valueType: "number" as const,
    unit: "복주머니",
    min: 1,
    max: 100000,
    step: 1,
    defaultValue: "30",
    description: "누적 복주머니가 이 값 이상이면 레벨2로 승급합니다.",
  },
  {
    key: "candle_level_3_threshold",
    label: "레벨3(축복의 불꽃) 승급 기준",
    valueType: "number" as const,
    unit: "복주머니",
    min: 1,
    max: 100000,
    step: 1,
    defaultValue: "70",
    description: "누적 복주머니가 이 값 이상이면 레벨3로 승급합니다.",
  },
  {
    key: "candle_level_4_threshold",
    label: "레벨4(가장 밝은 불꽃, 최종) 승급 기준",
    valueType: "number" as const,
    unit: "복주머니",
    min: 1,
    max: 100000,
    step: 1,
    defaultValue: "150",
    description: "누적 복주머니가 이 값 이상이면 최종 레벨(레벨4)로 승급하고 특별 연출이 노출됩니다.",
  },
  {
    key: "comment_bokju_reward",
    label: "응원 댓글 작성 시 자동 지급 복주머니",
    valueType: "number" as const,
    unit: "복주머니",
    min: 0,
    max: 100,
    step: 1,
    defaultValue: "1",
    description: "소원에 댓글(응원)을 남기면 자동으로 지급되는 복주머니 개수(0으로 설정 시 비활성화).",
  },
  {
    key: "bokju_preset_amounts",
    label: "복주머니 보내기 선택 단위",
    valueType: "json" as const,
    unit: "",
    defaultValue: "[1,5,10,50,100]",
    description: "사용자가 복주머니를 보낼 때 선택할 수 있는 개수 목록(JSON 배열).",
  },
  {
    key: "animation_enabled",
    label: "성장/레벨업 애니메이션 전체 ON/OFF",
    valueType: "boolean" as const,
    unit: "",
    defaultValue: "true",
    description: "OFF 시 파티클/레벨업 풀스크린 등 화려한 연출을 건너뛰고 즉시 반영만 표시합니다.",
  },
  {
    key: "ai_cheer_messages",
    label: "AI 응원 메시지 목록",
    valueType: "json" as const,
    unit: "",
    defaultValue:
      '["당신의 마음이 따뜻한 응원으로 가득 채워지고 있어요","작은 불빛이 모여 큰 빛이 되고 있어요","누군가 당신의 소원을 함께 바라보고 있어요","오늘도 한 걸음, 소원성이 더 밝아졌어요","희망은 계속 자라나고 있어요"]',
    description:
      "복주머니를 받았을 때 랜덤으로 노출되는 응원 문구 목록(JSON 배열). '이루어진다'는 확정적 표현은 사용하지 않습니다.",
  },
] as const;

export type WishConfigKey = (typeof WISH_CONFIG_KEYS)[number]["key"];
