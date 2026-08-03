// 복(福) 경제 설정(economy_config) 메타데이터 — Phase4(관리자 대시보드, 옵션B).
// "use server" 액션 파일(economy-config.ts)은 async function만 export 가능하므로,
// 화이트리스트 상수는 별도 파일로 분리해 Server Component/Client Component 양쪽에서
// 공유한다.
export const ECONOMY_CONFIG_KEYS = [
  {
    key: "send_refund_rate",
    label: "복 나누기 환급률",
    unit: "rate",
    min: 0,
    max: 1,
    step: 0.05,
    defaultValue: 0.5,
    description: "사용자 간 '복 나누기(송금)' 시 보낸 사람이 즉시 돌려받는 비율(0~1). 예) 0.5 = 50%",
  },
  {
    key: "daily_send_limit",
    label: "1인 1일 복 나누기 한도",
    unit: "point",
    min: 0,
    max: 100000,
    step: 10,
    defaultValue: 200,
    description: "한 사용자가 하루에 '복 나누기'로 보낼 수 있는 최대 포인트(인플레이션 방어).",
  },
  {
    key: "refund_rate",
    label: "운세/AI서비스 소모 환급률",
    unit: "rate",
    min: 0,
    max: 1,
    step: 0.05,
    defaultValue: 0.5,
    description: "운세보기 등 AI서비스 이용(소모)에 포인트 사용 시 즉시 돌려받는 비율(0~1).",
  },
  {
    key: "daily_earn_cap_normal",
    label: "일일 적립 상한(평시)",
    unit: "point",
    min: 0,
    max: 1000,
    step: 10,
    defaultValue: 80,
    description:
      "이벤트 배율 모드가 꺼져 있을 때, 1인당 하루 총 적립 가능한 복주머니 최대치(운영자 수동 지급 제외). luck-pouch-engine의 clipToDailyCap()이 이 값을 초과하는 적립분을 자동으로 잘라낸다.",
  },
  {
    key: "daily_earn_cap_event",
    label: "일일 적립 상한(이벤트 중)",
    unit: "point",
    min: 0,
    max: 1000,
    step: 10,
    defaultValue: 120,
    description:
      "이벤트 배율 모드가 켜져 있을 때 적용되는 1인당 하루 총 적립 상한. 아래 '이벤트 배율 모드' 값이 1이면 이 상한이, 0이면 평시 상한이 적용된다.",
  },
  {
    key: "event_bonus_active",
    label: "이벤트 배율 모드",
    unit: "flag",
    min: 0,
    max: 1,
    step: 1,
    defaultValue: 0,
    description:
      "0=평시(일일 적립 상한 '평시' 값 적용) / 1=이벤트 중(일일 적립 상한 '이벤트 중' 값으로 상향 적용). 프로모션 기간에만 1로 전환해 적립 한도를 일시적으로 늘리는 용도.",
  },
] as const;

export type EconomyConfigKey = (typeof ECONOMY_CONFIG_KEYS)[number]["key"];
