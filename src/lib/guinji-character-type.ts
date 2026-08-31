// 귀인지도(Guinji Map) 소유자 "캐릭터 유형" — 웹 랜딩페이지(`/g/[token]`) 바이럴
// 개선용 신규 파생 데이터.
//
// [배경] 사용자가 경쟁 서비스 레퍼런스(예: "가을 큰나무형")를 보고 "저렇게
// 나와야 바이럴이 된다"고 요구했다. 귀인지도는 관계 유형(貴/同/緣/養/師,
// owner↔member 대조 판정)만 있고 "소유자 본인의 캐릭터 유형" 개념이 없었다.
//
// [정직성 원칙] 새로운 사주 계산 로직을 만들지 않는다 — 이미
// `GuinjiMap.ownerSajuParsed`에 캐싱된 오행 카운트(`fiveElementsCount`,
// ManseryeokCoreEngine이 실계산한 값)에서 "가장 우세한 오행 1개"를 뽑아
// 5가지 고정 캐릭터 타입 중 하나에 대입하는 순수 매핑 함수다. 계절(봄/가을 등)
// 같은 부가 판정은 이 엔진에 없으므로 넣지 않는다(과장 금지).
export type OhaengKey = "목" | "화" | "토" | "금" | "수";

export interface GuinjiCharacterType {
  element: OhaengKey;
  /** 한자 라벨(木/火/土/金/水). */
  hanja: string;
  /** 캐릭터 타입 타이틀(레퍼런스의 "가을 큰나무형" 대응). */
  title: string;
  /** 짧은 부제(카드 상단 뱃지). */
  tagline: string;
  /** 상세 해설 줄글(레퍼런스의 "상세 사주 해설" 대응). */
  description: string;
  /** 그래프/카드에서 쓰는 강조색(크림 배경 위에서 잘 보이는 톤). */
  color: string;
}

export const GUINJI_CHARACTER_TYPES: Record<OhaengKey, GuinjiCharacterType> = {
  목: {
    element: "목",
    hanja: "木",
    title: "큰 나무형",
    tagline: "쭉쭉 뻗어나가는 성장형",
    description:
      "목(木) 기운이 가장 강해요. 위로 곧게 자라는 나무처럼, 끊임없이 배우고 뻗어나가려는 힘이 있는 사람이에요. 주변 사람을 그늘로 품어주면서도, 스스로 성장을 멈추지 않는 타입이에요.",
    color: "#6E9B5A",
  },
  화: {
    element: "화",
    hanja: "火",
    title: "타오르는 불꽃형",
    tagline: "주변을 밝히는 열정형",
    description:
      "화(火) 기운이 가장 강해요. 밝고 뜨겁게 타오르는 불꽃처럼, 주변에 활력과 에너지를 퍼뜨리는 사람이에요. 표현이 솔직하고 분위기를 이끄는 힘이 있어요.",
    color: "#D8663F",
  },
  토: {
    element: "토",
    hanja: "土",
    title: "넓은 대지형",
    tagline: "모두를 품는 안정형",
    description:
      "토(土) 기운이 가장 강해요. 넓고 든든한 땅처럼, 사람과 일을 두루 품고 중심을 잡아주는 사람이에요. 급하게 움직이지 않지만 오래 믿을 수 있는 타입이에요.",
    color: "#B58A4A",
  },
  금: {
    element: "금",
    hanja: "金",
    title: "빛나는 금속형",
    tagline: "결단력 있는 완성형",
    description:
      "금(金) 기운이 가장 강해요. 단단하고 빛나는 금속처럼, 맺고 끊는 게 분명하고 완성도를 추구하는 사람이에요. 원칙이 뚜렷해서 신뢰를 주는 타입이에요.",
    color: "#8A8F99",
  },
  수: {
    element: "수",
    hanja: "水",
    title: "흐르는 물결형",
    tagline: "유연하게 스며드는 지혜형",
    description:
      "수(水) 기운이 가장 강해요. 낮은 곳으로 스며드는 물처럼, 유연하고 지혜롭게 상황에 적응하는 사람이에요. 눈치가 빠르고 관계의 흐름을 잘 읽는 타입이에요.",
    color: "#4B7FA6",
  },
};

const OHAENG_ORDER: OhaengKey[] = ["목", "화", "토", "금", "수"];

/**
 * `fiveElementsCount`(오행 카운트)에서 가장 우세한 오행 1개를 골라 캐릭터
 * 유형을 반환한다. 동률이면 목→화→토→금→수 고정 순서로 먼저 나온 쪽을
 * 채택한다(결정론적 — 같은 입력엔 항상 같은 결과).
 */
export function deriveCharacterType(fiveElementsCount: Record<string, number>): GuinjiCharacterType {
  let best: OhaengKey = "목";
  let bestCount = -1;
  for (const key of OHAENG_ORDER) {
    const count = fiveElementsCount[key] ?? 0;
    if (count > bestCount) {
      bestCount = count;
      best = key;
    }
  }
  return GUINJI_CHARACTER_TYPES[best];
}
