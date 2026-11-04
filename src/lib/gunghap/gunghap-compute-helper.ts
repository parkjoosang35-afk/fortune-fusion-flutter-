// 궁합지도(Gunghap Map) — 3개 엔진(FACT→등급→서술) 연결 + 결과 병합 공용
// 헬퍼.
//
// [Phase 3 — 궁합지도 통합 최종 개발 지시서] 기존
// `g/[token]/join/route.ts`에 인라인으로 있던 `mergeCategoryResults()`/
// `toFreeCategoryView()`와 "FACT→등급→서술" 3엔진 연결 호출부를 이
// 공용 모듈로 추출한다. 이유: Phase 3에서 신규로 만드는
// `POST /api/public/gunghap/direct`(로그인 사용자가 초대 없이 직접
// 궁합을 생성)도 정확히 동일한 계산 파이프라인이 필요한데, 로직을
// 복붙하면 "두 계산 경로가 미묘하게 달라지는" 유지보수 위험이 생긴다
// (§6 "기존 엔진의 검증된 기능을 분석하여 재사용한다" 원칙).
//
// [절대 원칙 — 계산 엔진 자체는 변경하지 않음] 이 파일은 기존
// `computeGunghapFact`/`gradeAllCategories`/`narrateAllCategories`
// 함수를 "호출하는 순서"만 캡슐화할 뿐, 각 엔진의 내부 로직은 1바이트도
// 건드리지 않는다.
import { computeGunghapFact, type GunghapFactResult } from "./gunghap-relation-fact";
import {
  gradeAllCategories,
  GUNGHAP_CATEGORY_RULES_VERSION,
  type CategoryGradeResult,
  type GunghapCategoryId,
} from "./gunghap-category-rules";
import {
  narrateAllCategories,
  GUNGHAP_NARRATIVE_VERSION,
  type CategoryNarrative,
} from "./gunghap-narrative";
import type { PersonInput } from "@/lib/guinji-v2/saju";

/** 저장/응답에 공용으로 쓰는 "분야별 등급+서술" 병합 레코드. */
export interface StoredCategoryResult {
  categoryId: GunghapCategoryId;
  grade: string;
  gradeCode: string;
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  improvement: string;
  factRefs: CategoryNarrative["factRefs"];
}

export interface GunghapComputeOutcome {
  fact: GunghapFactResult;
  stored: StoredCategoryResult[];
  engineVersion: string;
  ruleVersion: string;
}

function mergeCategoryResults(
  grades: CategoryGradeResult[],
  narratives: CategoryNarrative[],
): StoredCategoryResult[] {
  const narrativeById = new Map(narratives.map((n) => [n.categoryId, n]));
  return grades.map((g) => {
    const n = narrativeById.get(g.categoryId);
    return {
      categoryId: g.categoryId,
      grade: g.grade,
      gradeCode: g.gradeCode,
      relationshipFeature: n?.relationshipFeature ?? "",
      strength: n?.strength ?? "",
      conflictRisk: n?.conflictRisk ?? "",
      improvement: n?.improvement ?? "",
      factRefs: n?.factRefs ?? { relationshipFeature: [], strength: [], conflictRisk: [], improvement: [] },
    };
  });
}

/** 무료 응답용 — 등급만 노출(점수/서술 비노출, "grades-only" 원칙). */
export function toFreeCategoryView(stored: StoredCategoryResult[]) {
  return stored.map((c) => ({ categoryId: c.categoryId, grade: c.grade, gradeCode: c.gradeCode }));
}

/**
 * [3개 엔진 연결 — 지시서 §1-3 "궁합 결과"] FACT → 등급 → 서술 순서로
 * 연결해 8개 분야의 실제 결과를 생성한다. 어느 단계도 임의 수치를 넣지
 * 않는다(모든 값은 fact에서 결정론적으로 파생) — join/route.ts와 완전히
 * 동일한 호출 순서를 그대로 함수로 캡슐화한 것뿐이다.
 */
export async function computeGunghapResult(
  personA: PersonInput,
  personB: PersonInput,
): Promise<GunghapComputeOutcome> {
  const fact: GunghapFactResult = await computeGunghapFact(personA, personB);
  const grades = gradeAllCategories(fact);
  const narratives = narrateAllCategories(grades);
  const stored = mergeCategoryResults(grades, narratives);
  return {
    fact,
    stored,
    engineVersion: `${fact.factEngineVersion}+${GUNGHAP_CATEGORY_RULES_VERSION}+${GUNGHAP_NARRATIVE_VERSION}`,
    ruleVersion: fact.factRuleVersion,
  };
}
