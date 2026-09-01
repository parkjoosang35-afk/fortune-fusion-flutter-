// 관계 유형(12라벨) 메타데이터 — 웹 미리보기 결과 표시용.
//
// [2026-09 전면 재작성 — 12라벨 체계] 기존 5종(귀인/오른팔/인연/살림꾼/
// 호랑이선생) 메타를 완전히 대체한다. 라벨명(subtitle)·문장 예시
// (description)는 PRD("신통방통 · 귀인지도 섹션 PRD" v0.9) p.4 "4.1 관계
// 라벨 체계" 표의 "방향성"/"문장 예시" 컬럼을 그대로 옮긴 것 — 새로운
// 문구를 만들지 않는다. 한자(hanja)는 `guinji-relation-judger.ts`의
// GuinjiRelationType 타입 주석 및 `guinji_design_handoff/DEV_SPEC.md`
// Dart RelationLabel enum과 일치시켰다.
export interface GuinjiRelationTypeMeta {
  label: string;
  hanja: string;
  subtitle: string;
  description: string;
}

export const GUINJI_RELATION_TYPES: Record<string, GuinjiRelationTypeMeta> = {
  CHEON_GWII: {
    label: "천생귀인",
    hanja: "貴",
    subtitle: "상대가 나를 살림",
    description: "이 사람은 내게 희소한 기운을 가져다줘요.",
  },
  NA_SALRIDA: {
    label: "나를 살리는 사람",
    hanja: "生",
    subtitle: "상대가 나를 살림",
    description: "힘들 때 절로 찾는, 나를 살리는 사람.",
  },
  JORYEOK: {
    label: "조력자",
    hanja: "助",
    subtitle: "쌍방 균형",
    description: "서로의 약점을 채워주는 조력자.",
  },
  GACHI_GA: {
    label: "같이 가야 좋은 길",
    hanja: "共",
    subtitle: "공동 상승",
    description: "같이 걸을 때 더 멀리 가는 사이.",
  },
  NA_SALJINDA: {
    label: "내가 살리는 사람",
    hanja: "育",
    subtitle: "내가 상대를 살림",
    description: "내가 에너지를 주는 사람 — 가끔은 쉬어가도 좋아요.",
  },
  CHANG_GYIM: {
    label: "내가 챙기는 사람",
    hanja: "養",
    subtitle: "내가 상대를 살림",
    description: "주다 보면 내가 소모되기 쉬운 조합.",
  },
  GAMJEONG: {
    label: "감정 충전소",
    hanja: "感",
    subtitle: "에너지 회복",
    description: "만나면 마음이 회복되는 사람.",
  },
  DEUNGDEUNG: {
    label: "든든한 등받이",
    hanja: "護",
    subtitle: "상대가 나를 살림",
    description: "곁에서 흔들리지 않게 잡아주는 사람.",
  },
  KKEURIDA: {
    label: "끌리는 사람",
    hanja: "緣",
    subtitle: "관성/식상 자화",
    description: "끌리지만 안정감은 따로 가는 사이.",
  },
  GACHI_BICH: {
    label: "같이 빛나는 사람",
    hanja: "輝",
    subtitle: "쌍방 상승",
    description: "각자의 결이 또렷한 채로 빛나는 사이.",
  },
  JAGEUKJE: {
    label: "자극제",
    hanja: "刺",
    subtitle: "긴장 → 성장",
    description: "서로의 날카로움이 성장으로 가는 자극제.",
  },
  GINGJANG: {
    label: "긴장 속 단짝",
    hanja: "緊",
    subtitle: "안정 + 긴장 공존",
    description: "부딪히면서도 놓지 않는 단짝.",
  },
};
