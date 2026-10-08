// 귀인지도 V2 — API 라우트가 사용할 단일 진입점.
//
// [배경] 기존 3개 API 라우트(members/route.ts, g/[token]/join/route.ts,
// g/[token]/preview/route.ts)는 모두 `judgeGuinjiRelation(mine, other):
// GuinjiJudgeResult`(동기, 12종)를 호출해 `{relationType, chemistryScore,
// ohaengEvidence}`를 받아 그대로 DB에 저장하거나 응답에 실었다.
//
// 이 파일은 그 호출을 대체하는 **단일 함수**
// `judgeGuinjiRelationV2(mine, other, names?): Promise<GuinjiV2JudgeResult>`
// 를 제공한다 — 각 라우트가 adapter/relation/narrative 3개 모듈을 각각
// import해 조립하지 않고, 이 한 함수만 호출하면 기존 `GuinjiJudgeResult`와
// "같은 모양"(relationType/chemistryScore/ohaengEvidence)의 결과를 받을 수
// 있다. 라우트 코드 변경을 최소화하기 위한 의도적 설계(거의 drop-in
// 교체가 되도록).
//
// [반환 타입 차이 — 의도적] `relationType`은 이제 V2 6종
// (`GuinjiV2RelationType`)이다. DB 컬럼(`GuinjiRelationship.relationType`)은
// `String`이라 스키마 변경 없이 그대로 저장 가능하다(③단계 확정 — Prisma
// 변경 금지).
//
// [비동기 — 주의] V2 `computeRelation()`은 `resultId` 생성에 Node crypto
// (동적 import)를 쓰므로 async다. 호출부는 반드시 `await`해야 한다(기존
// `judgeGuinjiRelation()`은 동기였으므로, 라우트 코드에서 `await` 추가가
// 필요한 지점이다).

import type { GuinjiSajuInput } from "../guinji-relation-judger";
import { guinjiSajuInputToV2 } from "./adapter";
import { computeRelation, type GuinjiV2RelationType } from "./relation";
import { buildOhaengEvidence, type GuinjiOhaengEvidence } from "./narrative";

export interface GuinjiV2JudgeResult {
  relationType: GuinjiV2RelationType;
  chemistryScore: number;
  ohaengEvidence: GuinjiOhaengEvidence;
}

/**
 * owner(mine) 기준으로 member(other)와의 V2 관계를 판정한다.
 * 기존 `judgeGuinjiRelation(mine, other)`와 동일한 인자 순서(owner가
 * 먼저)를 유지한다 — 호출부 인자 순서를 바꾸지 않아도 된다.
 *
 * @param mine  owner의 GuinjiSajuInput(한자 기반, 기존 계약 그대로).
 * @param other member/guest의 GuinjiSajuInput.
 * @param names 선택 — adapter가 V2 PersonInput.name에 채울 이름(없으면 빈 문자열).
 */
export async function judgeGuinjiRelationV2(
  mine: GuinjiSajuInput,
  other: GuinjiSajuInput,
  names?: { mine?: string; other?: string },
): Promise<GuinjiV2JudgeResult> {
  const minePerson = guinjiSajuInputToV2(mine, names?.mine);
  const otherPerson = guinjiSajuInputToV2(other, names?.other);
  const result = await computeRelation(minePerson, otherPerson);
  const ohaengEvidence = buildOhaengEvidence(result);

  return {
    relationType: result.relationType,
    chemistryScore: result.chemistryScore,
    ohaengEvidence,
  };
}
