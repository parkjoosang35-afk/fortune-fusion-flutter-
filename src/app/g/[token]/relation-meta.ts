// 관계 유형(V2 6종) 메타데이터 — 웹 미리보기 결과 표시용.
//
// [2026-10-13 통합 — 12종→V2 6종 전환] 기존 12라벨 체계(JORYEOK/
// JAGEUKJE 등)를 완전히 대체한다. 관계유형 자체의 단일 소스는
// `@/lib/guinji-v2/relation`(GuinjiV2RelationType, RELATION_TYPES,
// GUINJI_V2_RELATION_TYPE_ORDER)이며, 이 파일은 그 6종에 대응하는
// "웹 랜딩 전용" 표시값(hanja·subtitle·color)만 보강해 제공한다.
// label/description은 엔진(RELATION_TYPES)과 100% 동일한 문구를
// 그대로 재사용한다(새 문구를 만들지 않음).
//
// [출처 — hanja/subtitle/color] Flutter
// `lib/features/guinji/theme/guinji_type_spec.dart`(귀인지도 v2 리스킨
// 핸드오프 1:1 이식본, guinjiTypes)와 완전히 동일한 값을 사용한다 —
// 웹 랜딩과 앱이 같은 한자 인장·색상을 보여줘야 하나의 디자인 언어로
// 보인다(기존 12종 때도 Dart RelationLabel enum과 일치시켰던 원칙 계승).
import { RELATION_TYPES, GUINJI_V2_RELATION_TYPE_ORDER, type GuinjiV2RelationType } from "@/lib/guinji-v2/relation";

export interface GuinjiRelationTypeMeta {
  label: string;
  hanja: string;
  subtitle: string;
  description: string;
}

const HANJA: Record<GuinjiV2RelationType, string> = {
  CHEON_GWII: "貴",
  HAP: "緣",
  SANG_SAENG: "生",
  BI_HWA: "同",
  SANG_GEUK: "調",
  CHUNG: "衝",
};

// [subtitle] Flutter GuinjiTypeSpec.short(짧은 이름)를 그대로 가져온다 —
// 결과 카드 한 줄 요약("OOO님과 당신은 {subtitle}의 결이에요")에 쓰인다.
const SUBTITLE: Record<GuinjiV2RelationType, string> = {
  CHEON_GWII: "귀인",
  HAP: "인연",
  SANG_SAENG: "상생",
  BI_HWA: "동반",
  SANG_GEUK: "조율",
  CHUNG: "극복",
};

export const GUINJI_RELATION_TYPES: Record<GuinjiV2RelationType, GuinjiRelationTypeMeta> =
  Object.fromEntries(
    GUINJI_V2_RELATION_TYPE_ORDER.map((key) => [
      key,
      {
        label: RELATION_TYPES[key].label,
        hanja: HANJA[key],
        subtitle: SUBTITLE[key],
        description: RELATION_TYPES[key].desc,
      },
    ]),
  ) as Record<GuinjiV2RelationType, GuinjiRelationTypeMeta>;
