// [관상·손금 후속 개발 — 설계안 §F "테스트 설계"] 판정 레이어(face-judgment.ts /
// palm-judgment.ts) 단위테스트. 별도 테스트 프레임워크(vitest/jest)가 설치돼
// 있지 않으므로, 프로젝트의 기존 스크립트(test-build-og-png.ts 등)와 동일한
// 패턴으로 tsx 실행 스크립트 형태로 작성한다.
//
// 실행: cd /home/user/admin_web && npx tsx scripts/test-face-palm-judgment.ts
//
// 판정 레이어는 "결정론적 순수 함수"(LLM 비개입)이므로, 동일 입력에 항상
// 동일 출력이 나오는지(결정성)와 각 분기 조건이 의도대로 동작하는지(규칙
// 커버리지)를 전수에 가깝게 검증할 수 있다 — 이것이 saju-judgment.ts와
// 동일한 아키텍처를 채택한 핵심 이유다(사진 기반 테스트와 달리 비용/LLM
// 변동성 없이 반복 실행 가능).
import assert from "node:assert/strict";
import { buildFaceJudgment, type FaceObserved } from "../src/lib/face-judgment";
import { buildPalmJudgment, type PalmObserved } from "../src/lib/palm-judgment";

let passed = 0;
function check(name: string, fn: () => void) {
  try {
    fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    console.error(`  ❌ ${name}`);
    throw e;
  }
}

// ── 공통 베이스 관찰값(모두 "보통"/"풍만" 등 중립값) ──
const baseFaceObserved: FaceObserved = {
  valid: true,
  invalidReason: null,
  wuguan: {
    눈썹: { thickness: "보통", length: "보통", shape: "일자형" },
    눈: { size: "보통", shape: "둥근형" },
    코: { size: "보통", bridgeHeight: "보통", shape: "곧은형" },
    입: { size: "보통", lipThickness: "보통", shape: "단정형" },
    귀: { visible: true, size: "보통", shape: "둥근형" },
  },
  samjeong: { 상정_비율: "보통", 중정_비율: "보통", 하정_비율: "보통" },
  sibigung: {
    명궁_인당: "보통",
    재백궁_코: "보통",
    관록궁_이마중앙: "보통",
    부모궁_이마양측: "보통",
    처첩궁_눈꼬리: "보통",
    천이궁_눈썹꼬리위: "보통",
    노복궁_턱: "보통",
    형제궁_눈썹: "보통",
    전택궁_눈꺼풀: "보통",
  },
};

const basePalmObserved: PalmObserved = {
  valid: true,
  invalidReason: null,
  hand: "right",
  majorLines: {
    생명선: { length: "보통", depth: "보통", shape: "곡선형" },
    두뇌선: { length: "보통", depth: "보통", shape: "곡선형" },
    감정선: { length: "보통", depth: "보통", shape: "곡선형" },
    운명선: { presence: "흐릿함", shape: "직선형" },
  },
  minorLines: {
    태양선: { presence: "흐릿함" },
    수성선: { presence: "흐릿함" },
    결혼선: { presence: "흐릿함", count: "1개" },
  },
};

console.log("[face-judgment.ts]");

check("동일 입력 → 동일 출력(결정성)", () => {
  const a = buildFaceJudgment(baseFaceObserved);
  const b = buildFaceJudgment(baseFaceObserved);
  assert.deepStrictEqual(a, b, "같은 관찰값인데 판정이 달라짐 — 순수 함수 위반");
});

check("재백궁(코) 풍만 + 명궁 넓음 → 재물 good", () => {
  const observed: FaceObserved = {
    ...baseFaceObserved,
    sibigung: { ...baseFaceObserved.sibigung, 재백궁_코: "풍만", 명궁_인당: "넓음" },
  };
  const j = buildFaceJudgment(observed);
  assert.equal(j.verdict.wealth.grade, "good");
});

check("재백궁(코) 빈약 → 재물 caution", () => {
  const observed: FaceObserved = {
    ...baseFaceObserved,
    sibigung: { ...baseFaceObserved.sibigung, 재백궁_코: "빈약" },
  };
  const j = buildFaceJudgment(observed);
  assert.equal(j.verdict.wealth.grade, "caution");
});

check("처첩궁 빈약 → 애정 caution", () => {
  const observed: FaceObserved = {
    ...baseFaceObserved,
    sibigung: { ...baseFaceObserved.sibigung, 처첩궁_눈꼬리: "빈약" },
  };
  const j = buildFaceJudgment(observed);
  assert.equal(j.verdict.relation.grade, "caution");
});

check("삼정 균형 + 노복궁 보통 이상 → 건강 good", () => {
  const j = buildFaceJudgment(baseFaceObserved);
  assert.equal(j.samjeong_verdict.balance, "균형");
  assert.equal(j.verdict.health.grade, "good");
});

check("상정만 넓음(편중) → 삼정 상정우세", () => {
  const observed: FaceObserved = {
    ...baseFaceObserved,
    samjeong: { 상정_비율: "넓음", 중정_비율: "보통", 하정_비율: "좁음" },
  };
  const j = buildFaceJudgment(observed);
  assert.equal(j.samjeong_verdict.balance, "상정우세");
});

check("눈썹 두껍고 긺 → 눈썹 등급 good", () => {
  const observed: FaceObserved = {
    ...baseFaceObserved,
    wuguan: { ...baseFaceObserved.wuguan, 눈썹: { thickness: "두꺼움", length: "큼", shape: "짙은 눈썹" } },
  };
  const j = buildFaceJudgment(observed);
  assert.equal(j.wuguan_grade.눈썹, "good");
});

check("귀가 안 보이면(visible=false) 귀 등급은 neutral로 안전 처리", () => {
  const observed: FaceObserved = {
    ...baseFaceObserved,
    wuguan: { ...baseFaceObserved.wuguan, 귀: { visible: false, size: null, shape: null } },
  };
  const j = buildFaceJudgment(observed);
  assert.equal(j.wuguan_grade.귀, "neutral");
});

console.log("\n[palm-judgment.ts]");

check("동일 입력 → 동일 출력(결정성)", () => {
  const a = buildPalmJudgment(basePalmObserved);
  const b = buildPalmJudgment(basePalmObserved);
  assert.deepStrictEqual(a, b, "같은 관찰값인데 판정이 달라짐 — 순수 함수 위반");
});

check("hand만 다르면 hand_interpretation_note가 달라진다(좌우손 반영 확인)", () => {
  const right = buildPalmJudgment({ ...basePalmObserved, hand: "right" });
  const left = buildPalmJudgment({ ...basePalmObserved, hand: "left" });
  assert.notEqual(right.hand_interpretation_note, left.hand_interpretation_note);
  assert.equal(right.hand, "right");
  assert.equal(left.hand, "left");
});

check("hand가 달라도 major_line_grade(관찰 기반 등급)는 동일(관찰값이 같으므로)", () => {
  const right = buildPalmJudgment({ ...basePalmObserved, hand: "right" });
  const left = buildPalmJudgment({ ...basePalmObserved, hand: "left" });
  assert.deepStrictEqual(right.major_line_grade, left.major_line_grade);
});

check("생명선 길고 깊음 → 생명선 good → 건강 good", () => {
  const observed: PalmObserved = {
    ...basePalmObserved,
    majorLines: { ...basePalmObserved.majorLines, 생명선: { length: "긺", depth: "깊음", shape: "곡선형" } },
  };
  const j = buildPalmJudgment(observed);
  assert.equal(j.major_line_grade.생명선, "good");
  assert.equal(j.verdict.health.grade, "good");
});

check("생명선 짧고 옅음 → 생명선 caution → 건강 caution", () => {
  const observed: PalmObserved = {
    ...basePalmObserved,
    majorLines: { ...basePalmObserved.majorLines, 생명선: { length: "짧음", depth: "옅음", shape: "곡선형" } },
  };
  const j = buildPalmJudgment(observed);
  assert.equal(j.major_line_grade.생명선, "caution");
  assert.equal(j.verdict.health.grade, "caution");
});

check("감정선 끊어짐 → 감정선 caution → 애정 caution", () => {
  const observed: PalmObserved = {
    ...basePalmObserved,
    majorLines: { ...basePalmObserved.majorLines, 감정선: { length: "보통", depth: "깊음", shape: "끊어짐" } },
  };
  const j = buildPalmJudgment(observed);
  assert.equal(j.major_line_grade.감정선, "caution");
  assert.equal(j.verdict.relation.grade, "caution");
});

check("두뇌선 끊어짐 → 두뇌선 caution → 직업 caution", () => {
  const observed: PalmObserved = {
    ...basePalmObserved,
    majorLines: { ...basePalmObserved.majorLines, 두뇌선: { length: "보통", depth: "보통", shape: "끊어짐" } },
  };
  const j = buildPalmJudgment(observed);
  assert.equal(j.major_line_grade.두뇌선, "caution");
  assert.equal(j.verdict.career.grade, "caution");
});

check("운명선 뚜렷함 + 태양선 뚜렷함 → 재물 good", () => {
  const observed: PalmObserved = {
    ...basePalmObserved,
    majorLines: { ...basePalmObserved.majorLines, 운명선: { presence: "뚜렷함", shape: "직선형" } },
    minorLines: { ...basePalmObserved.minorLines, 태양선: { presence: "뚜렷함" } },
  };
  const j = buildPalmJudgment(observed);
  assert.equal(j.verdict.wealth.grade, "good");
});

console.log(`\n✅ 전체 ${passed}개 테스트 통과`);
