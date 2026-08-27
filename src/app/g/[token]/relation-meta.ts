// 관계 유형(貴/同/緣/養/師) 메타데이터 — 웹 미리보기 결과 표시용.
// [Phase A-2] Flutter `guinji_relation_meta.dart`의 `guinjiRelationTypes`를
// 그대로 옮긴 것 — 새로운 문구를 만들지 않고 앱과 동일한 라벨/설명을 쓴다.
export interface GuinjiRelationTypeMeta {
  label: string;
  hanja: string;
  subtitle: string;
  description: string;
}

export const GUINJI_RELATION_TYPES: Record<string, GuinjiRelationTypeMeta> = {
  guin: {
    label: "귀인",
    hanja: "貴",
    subtitle: "나를 살리는 기운",
    description: "나에게 긍정 기운을 더해주는 조력자예요. 곁에 두면 결이 잘 맞아 힘이 됩니다.",
  },
  oreunpal: {
    label: "오른팔",
    hanja: "同",
    subtitle: "같은 기운의 동료",
    description: "마음이 잘 맞고 실질적 협력이 되는 사람. 같은 방향을 보는 동료예요.",
  },
  inyeon: {
    label: "인연",
    hanja: "緣",
    subtitle: "서로 끌리는 합(合)",
    description: "천간·지지의 합(合)으로 서로 자연스레 끌리는 사이. 오래 보게 될 사람이에요.",
  },
  salrim: {
    label: "살림꾼",
    hanja: "養",
    subtitle: "내가 돌보는 인연",
    description: "내가 살리는 기운. 내가 챙기고 이끌어주게 되는 사람이에요.",
  },
  horang: {
    label: "호랑이 선생",
    hanja: "師",
    subtitle: "나를 다잡는 스승",
    description: "자극·조언으로 성장을 이끄는 스승. 극(剋)은 나쁨이 아니라 통제·성과를 만드는 작용이에요.",
  },
};
