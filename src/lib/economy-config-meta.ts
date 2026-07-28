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
] as const;

export type EconomyConfigKey = (typeof ECONOMY_CONFIG_KEYS)[number]["key"];
