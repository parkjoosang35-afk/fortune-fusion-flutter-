// [관상·손금 후속 개발 — 전수 검수 보고서 기준] 관상 판정 레이어.
//
// saju-judgment.ts와 동일한 원칙을 따른다 — "계산(관찰)과 표현을 분리한다":
//   ① 관찰 레이어(route.ts, completeVisionJson) — 사진 → FaceObserved(선택지 강제
//      JSON). Vision LLM은 오직 "사진에서 무엇이 보이는가"만 답한다(해석 금지).
//   ② 판정 레이어(이 파일) — FaceObserved → FaceJudgment. 여기서 사용하는
//      오관/삼정/십이궁 해석 규칙은 전부 결정론적 룩업테이블이다(LLM 비개입,
//      해시/랜덤 아님). 같은 관찰값이 입력되면 항상 같은 판정이 나온다.
//   ③ 표현 레이어(LLM, route.ts) — 이 파일이 만든 JSON만 받아서 문장을 쓴다.
//
// [범위 결정 — 설계안에서 사용자에게 고지한 제약]
//   - 전통 관상학의 십이궁은 본래 기색(氣色)·골격 입체 촉진 등을 포함하는
//     정교한 체계이나, 2D 정지 사진만으로는 전부를 정확히 관찰할 수 없다.
//     이 구현은 "사진에서 윤곽·비율로 근사 가능한 핵심 궁"만 사용한다
//     (명궁/재백궁/관록궁/부모궁/처첩궁/천이궁/노복궁/형제궁/전택궁 9궁).
//   - 오관은 전통 5관(귀/눈썹/눈/코/입)을 그대로 사용한다. 기존 구현(이마/눈/
//     코/입/턱)은 "서술용 부위 5개"였을 뿐 오관학과 무관했으므로 대체한다.

export type FaceGrade = "good" | "neutral" | "caution";

export interface FaceVerdictEntry {
  grade: FaceGrade;
  primary_evidence: string;
  hook: string;
}

// ── ① 관찰 레이어가 채워야 하는 입력 스키마(선택지 강제) ──
export type SizeLevel = "큼" | "보통" | "작음";
export type ThicknessLevel = "두꺼움" | "보통" | "얇음";
export type FullnessLevel = "풍만" | "보통" | "빈약";
export type WidthLevel = "넓음" | "보통" | "좁음";

export interface FaceObserved {
  valid: boolean;
  invalidReason: string | null;
  // 오관(五官) — 전통 5관: 눈썹(보수관)/눈(감찰관)/코(심변관)/입(출납관)/귀(채청관)
  wuguan: {
    눈썹: { thickness: ThicknessLevel; length: SizeLevel; shape: string };
    눈: { size: SizeLevel; shape: string };
    코: { size: SizeLevel; bridgeHeight: WidthLevel; shape: string };
    입: { size: SizeLevel; lipThickness: ThicknessLevel; shape: string };
    귀: { visible: boolean; size: SizeLevel | null; shape: string | null };
  };
  // 삼정(三停) — 상정(이마)/중정(눈썹~코끝)/하정(인중~턱) 비율 근사
  samjeong: {
    상정_비율: WidthLevel;
    중정_비율: WidthLevel;
    하정_비율: WidthLevel;
  };
  // 십이궁(十二宮) — 사진 기반 근사 9궁(기색/촉진 불가 영역 제외)
  sibigung: {
    명궁_인당: WidthLevel; // 양 눈썹 사이(미간)
    재백궁_코: FullnessLevel;
    관록궁_이마중앙: FullnessLevel;
    부모궁_이마양측: FullnessLevel;
    처첩궁_눈꼬리: FullnessLevel; // 간문(奸門)
    천이궁_눈썹꼬리위: FullnessLevel;
    노복궁_턱: FullnessLevel;
    형제궁_눈썹: FullnessLevel;
    전택궁_눈꺼풀: FullnessLevel; // 상안검
  };
}

export interface FaceJudgment {
  wuguan_grade: Record<"눈썹" | "눈" | "코" | "입" | "귀", FaceGrade>;
  samjeong_verdict: {
    balance: "균형" | "상정우세" | "중정우세" | "하정우세";
    primary_evidence: string;
  };
  verdict: {
    wealth: FaceVerdictEntry;
    relation: FaceVerdictEntry;
    career: FaceVerdictEntry;
    health: FaceVerdictEntry;
  };
}

function fullnessScore(v: FullnessLevel): number {
  return v === "풍만" ? 1 : v === "보통" ? 0 : -1;
}
function widthScore(v: WidthLevel): number {
  return v === "넓음" ? 1 : v === "보통" ? 0 : -1;
}

/** 오관 각 부위의 개별 등급 — "보통"에서 벗어난 특징이 뚜렷할수록 good/caution으로 분기. */
function judgeWuguan(observed: FaceObserved["wuguan"]): FaceJudgment["wuguan_grade"] {
  const 눈썹: FaceGrade =
    observed.눈썹.thickness === "두꺼움" && observed.눈썹.length === "큼"
      ? "good"
      : observed.눈썹.thickness === "얇음" && observed.눈썹.length === "작음"
        ? "caution"
        : "neutral";
  const 눈: FaceGrade = observed.눈.size === "큼" ? "good" : observed.눈.size === "작음" ? "neutral" : "good";
  const 코: FaceGrade =
    observed.코.bridgeHeight === "넓음" && observed.코.size !== "작음"
      ? "good"
      : observed.코.bridgeHeight === "좁음" && observed.코.size === "작음"
        ? "caution"
        : "neutral";
  const 입: FaceGrade =
    observed.입.lipThickness === "두꺼움"
      ? "good"
      : observed.입.lipThickness === "얇음" && observed.입.size === "작음"
        ? "caution"
        : "neutral";
  const 귀: FaceGrade = !observed.귀.visible ? "neutral" : observed.귀.size === "큼" ? "good" : "neutral";
  return { 눈썹, 눈, 코, 입, 귀 };
}

/** 삼정 균형 판정 — 세 영역 비율 중 어느 것이 우세/열세인지 결정론적으로 비교. */
function judgeSamjeong(samjeong: FaceObserved["samjeong"]): FaceJudgment["samjeong_verdict"] {
  const scores: Record<"상정" | "중정" | "하정", number> = {
    상정: widthScore(samjeong.상정_비율),
    중정: widthScore(samjeong.중정_비율),
    하정: widthScore(samjeong.하정_비율),
  };
  const maxKey = (Object.entries(scores).sort((a, b) => b[1] - a[1])[0][0]) as "상정" | "중정" | "하정";
  const minKey = (Object.entries(scores).sort((a, b) => a[1] - b[1])[0][0]) as "상정" | "중정" | "하정";
  const spread = scores[maxKey] - scores[minKey];
  const balance = spread <= 1 ? "균형" : (`${maxKey}우세` as FaceJudgment["samjeong_verdict"]["balance"]);
  return {
    balance,
    primary_evidence: `상정 ${samjeong.상정_비율} · 중정 ${samjeong.중정_비율} · 하정 ${samjeong.하정_비율}`,
  };
}

/**
 * FaceObserved(관찰값)만 입력받아 FaceJudgment(판정)를 결정론적으로 산출한다.
 * LLM을 호출하지 않으며, 동일 입력에는 항상 동일 출력을 반환한다(순수 함수).
 */
export function buildFaceJudgment(observed: FaceObserved): FaceJudgment {
  const wuguan_grade = judgeWuguan(observed.wuguan);
  const samjeong_verdict = judgeSamjeong(observed.samjeong);
  const { sibigung } = observed;

  // ── 재물: 재백궁(코) + 명궁(인당 여유) — 전통적으로 코=재백궁 직결 ──
  const jaebaek = fullnessScore(sibigung.재백궁_코);
  const myeonggung = widthScore(sibigung.명궁_인당);
  const wealth: FaceVerdictEntry =
    jaebaek > 0 && myeonggung >= 0
      ? { grade: "good", primary_evidence: `재백궁(코) ${sibigung.재백궁_코} · 명궁(인당) ${sibigung.명궁_인당}`, hook: "재물을 모으고 지키는 기운이 조화를 이룸" }
      : jaebaek < 0
        ? { grade: "caution", primary_evidence: `재백궁(코) ${sibigung.재백궁_코}`, hook: "들고 나는 재물의 흐름을 스스로 관리할 필요가 있음" }
        : { grade: "neutral", primary_evidence: `재백궁(코) ${sibigung.재백궁_코} · 명궁(인당) ${sibigung.명궁_인당}`, hook: "무리하지 않는 선에서 꾸준히 쌓아가는 편" };

  // ── 애정/대인관계: 처첩궁(눈꼬리/간문) + 전택궁(눈꺼풀) ──
  const cheocheop = fullnessScore(sibigung.처첩궁_눈꼬리);
  const jeontaek = fullnessScore(sibigung.전택궁_눈꺼풀);
  const relation: FaceVerdictEntry =
    cheocheop > 0 && jeontaek >= 0
      ? { grade: "good", primary_evidence: `처첩궁(눈꼬리) ${sibigung.처첩궁_눈꼬리} · 전택궁(눈꺼풀) ${sibigung.전택궁_눈꺼풀}`, hook: "따뜻한 인상으로 좋은 인연을 끌어들이는 기운" }
      : cheocheop < 0
        ? { grade: "caution", primary_evidence: `처첩궁(눈꼬리) ${sibigung.처첩궁_눈꼬리}`, hook: "관계에서 감정을 조금 더 표현해도 좋은 시기" }
        : { grade: "neutral", primary_evidence: `처첩궁(눈꼬리) ${sibigung.처첩궁_눈꼬리} · 전택궁(눈꺼풀) ${sibigung.전택궁_눈꺼풀}`, hook: "관계의 속도를 스스로 조절하는 편" };

  // ── 직업/성취: 관록궁(이마중앙) + 천이궁(눈썹꼬리위) + 눈썹 등급 ──
  const gwanlok = fullnessScore(sibigung.관록궁_이마중앙);
  const cheonyi = fullnessScore(sibigung.천이궁_눈썹꼬리위);
  const career: FaceVerdictEntry =
    gwanlok > 0 || wuguan_grade.눈썹 === "good"
      ? { grade: "good", primary_evidence: `관록궁(이마중앙) ${sibigung.관록궁_이마중앙} · 눈썹 ${wuguan_grade.눈썹}`, hook: "주변의 신뢰를 바탕으로 성취를 쌓아가는 흐름" }
      : gwanlok < 0 && cheonyi < 0
        ? { grade: "caution", primary_evidence: `관록궁(이마중앙) ${sibigung.관록궁_이마중앙} · 천이궁(눈썹꼬리위) ${sibigung.천이궁_눈썹꼬리위}`, hook: "변화의 시기에는 신중한 판단이 필요함" }
        : { grade: "neutral", primary_evidence: `관록궁(이마중앙) ${sibigung.관록궁_이마중앙}`, hook: "꾸준함으로 입지를 다져가는 편" };

  // ── 건강: 삼정 균형(편중은 기운의 쏠림으로 해석) + 노복궁(턱, 말년/체력) ──
  const nobok = fullnessScore(sibigung.노복궁_턱);
  const health: FaceVerdictEntry =
    samjeong_verdict.balance === "균형" && nobok >= 0
      ? { grade: "good", primary_evidence: `삼정 균형(${samjeong_verdict.primary_evidence}) · 노복궁(턱) ${sibigung.노복궁_턱}`, hook: "컨디션 기복이 크지 않은 편" }
      : samjeong_verdict.balance !== "균형" && nobok < 0
        ? { grade: "caution", primary_evidence: `삼정 ${samjeong_verdict.balance} · 노복궁(턱) ${sibigung.노복궁_턱}`, hook: "휴식과 회복의 리듬을 챙길 필요가 있음" }
        : { grade: "neutral", primary_evidence: `삼정 ${samjeong_verdict.balance}`, hook: "큰 기복 없이 안정적으로 이어지는 흐름" };

  return {
    wuguan_grade,
    samjeong_verdict,
    verdict: { wealth, relation, career, health },
  };
}
