// 귀인지도 V2 — 기존 운영 계약(GuinjiSajuInput, 한자 기반) ↔ V2 엔진 입력
// (PersonInput, 한글 기반) 변환 어댑터.
//
// [배경] 기존 3개 API 라우트(members/join/preview)가 실제로 손에 쥐고
// 있는 사주 데이터는 항상 `GuinjiSajuInput`(한자 1글자, stems/branches
// 분리 구조)이다 — 클라이언트(Flutter `guinjiSajuInputFromProfile()`,
// 웹 `guinjiSajuInputFromManseryeok()`)가 이 형식으로 보내고, DB
// `GuinjiMap.ownerSajuParsed`/`GuinjiMapMember.sajuParsed`도 이 형식
// 그대로 저장되어 있다. V2 엔진(`guinji-v2/saju.ts`)은 Python 원본과
// 동일한 "한글 1글자, pillars 묶음 구조"(`PersonInput`)만 받는다.
//
// [설계 결정 — 단방향 변환] 그러므로 변환은 "GuinjiSajuInput(한자) →
// PersonInput(한글)" 단방향으로 충분하다. SajuProfile/SajuManseryeokResult
// 로부터 V2 입력을 별도 경로로 새로 만드는 것은 불필요한 중복이며, 기존
// Flutter/웹의 사주 계산·전송 경로를 전혀 바꾸지 않아도 된다(요청 바디
// 계약 불변 — 회귀 위험 최소화).
//
// [검증] `scripts/verify-guinji-v2-adapter-golden.ts`가 20개 골든 벡터를
// 이 어댑터가 만든 "한자 경유" 입력으로 다시 돌려 기존 PersonInput
// 직접 입력 결과와 20/20 동일한지 검증한다 — 어댑터 자체가 결과를
// 왜곡하지 않음을 보장한다.

import type { GuinjiSajuInput } from "../guinji-relation-judger";
import type { PersonInput } from "./saju";
import { STEM_HANJA, BRANCH_HANJA } from "./constants";

export class AdapterError extends Error {}

/** 한자 → 한글 역테이블(STEM_HANJA/BRANCH_HANJA를 뒤집어 생성). */
const HANJA_TO_STEM_KR: Record<string, string> = Object.fromEntries(
  Object.entries(STEM_HANJA).map(([kr, hj]) => [hj, kr]),
);
const HANJA_TO_BRANCH_KR: Record<string, string> = Object.fromEntries(
  Object.entries(BRANCH_HANJA).map(([kr, hj]) => [hj, kr]),
);

/** 천간 한자 1글자 + 지지 한자 1글자 → 한글 기둥 문자열(예: '甲'+'子' → '갑자'). */
function toHangulPillar(stemHanja: string, branchHanja: string): string {
  const s = HANJA_TO_STEM_KR[stemHanja];
  const b = HANJA_TO_BRANCH_KR[branchHanja];
  if (!s || !b) {
    throw new AdapterError(
      `한자→한글 변환 실패: stem=${JSON.stringify(stemHanja)} branch=${JSON.stringify(branchHanja)}`,
    );
  }
  return s + b;
}

/**
 * 기존 `GuinjiSajuInput`(한자, stems/branches 분리 구조)을 V2 엔진의
 * `PersonInput`(한글, pillars 묶음 구조)으로 변환한다.
 *
 * [주의 — 버려지는 필드] `fiveElementsCount`/`sinsalIds`는 V2 엔진이
 * 사용하지 않는다(V2는 `pillars`에서 직접 오행을 재계산한다 —
 * `saju.ts`의 `elementCounts()`). 변환 후 버려도 V2 판정 결과에는
 * 영향이 없다(골든 벡터 회귀 테스트로 확인됨).
 */
export function guinjiSajuInputToV2(
  input: GuinjiSajuInput,
  name?: string,
): PersonInput {
  return {
    name: name ?? "",
    pillars: {
      year: toHangulPillar(input.stems.year, input.branches.year),
      month: toHangulPillar(input.stems.month, input.branches.month),
      day: toHangulPillar(input.stems.day, input.branches.day),
      hour: toHangulPillar(input.stems.hour, input.branches.hour),
    },
  };
}
