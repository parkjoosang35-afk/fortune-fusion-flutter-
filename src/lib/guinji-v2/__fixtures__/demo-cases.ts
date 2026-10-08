// 관계 엔진 검증 케이스 20건 — Python 기준 소스
// `guinji_v2_source/guinji_engine/demo_cases.py`의 CASES를 그대로 1:1
// 포팅한 것(값 변경 없음). 골든 벡터(`python_golden_vectors.json`) 대조용
// 입력 데이터.

import type { PersonInput } from "../saju";

function person(
  name: string,
  y: string | null,
  m: string | null,
  d: string | null,
  h: string | null = null,
): PersonInput {
  return { name, pillars: { year: y, month: m, day: d, hour: h } };
}

export const CASES: Array<[string, PersonInput, PersonInput]> = [
  ["C01", person("가A", "계사", "갑신", "을해", "병인"), person("나B", "경신", "신해", "임인", "계사")],
  ["C02", person("다C", "신유", "임자", "계묘", "갑오"), person("라D", "갑술", "을축", "병진", "정미")],
  ["C03", person("마E", "계묘", "갑오", "을유", "병자"), person("바F", "을묘", "병오", "정유", "무자")],
  ["C04", person("사G", "무오", "기유", "경자", "신묘"), person("아H", "을묘", "병오", "정유", "무자")],
  ["C05", person("자I", "병오", "정유", "무자", "기묘"), person("차J", "임오", "계유", "갑자", "을묘")],
  ["C06", person("카K", "갑술", "을축", "병진", "정미"), person("타L", "경진", "신사", "임오", "계미")],
  ["C07", person("파M", "기축", "경술", "신미", "임신"), person("하N", "계축", "갑술", "을미", "병신")],
  ["C08", person("가O", "계해", "갑인", "을사", "병신"), person("나P", "경오", "신사", "임오", null)],
  ["C09", person("다Q", "경진", "신사", "임오", "계미"), person("라R", "갑자", "을축", "병인", "정묘")],
  ["C10", person("마S", "무오", "기미", "경신", "신유"), person("바T", "임술", "계해", "갑자", "을축")],
  ["C11", person("사U", "계해", "갑인", "을사", "병신"), person("아V", "계해", "갑인", "을사", "병신")],
  ["C12", person("가A", "계사", "갑신", "을해", "병인"), person("나B", "경신", "신해", "임인", "계사")],
  ["C13", person("자W", "을축", "병인", "정묘", "무진"), person("차X", "계사", "갑신", "을해", "병인")],
  ["C14", person("카Y", "무진", "기사", "경오", "신미"), person("타Z", "계축", "갑술", "을미", "병신")],
  ["C15", person("파AA", "경신", "신유", "임술", "계해"), person("하AB", "갑자", "을축", "병인", "정묘")],
  ["C16", person("가AC", "갑인", "을묘", "병진", "정사"), person("나AD", "병오", "정미", "무신", "기유")],
  ["C17", person("다AE", "임자", "계축", "갑인", "을묘"), person("라AF", "갑진", "을사", "병오", "정미")],
  ["C18", person("마AG", null, null, "을해", null), person("바AH", null, null, "임인", null)],
  ["C19", person("사AI", "경오", "신사", "임오", "계미"), person("아AJ", "갑인", "을묘", "병진", "정사")],
  ["C20", person("자AK", "계미", "갑신", "을유", "병술"), person("차AL", "정축", "무인", "기묘", "경진")],
];
