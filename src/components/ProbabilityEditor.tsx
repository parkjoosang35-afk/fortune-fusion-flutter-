"use client";

// 08_Web_Design.md §3.4 표준컴포넌트: ProbabilityEditor
// "복주머니 확률테이블 전용(합계 100% 실시간 검증 UI)"
//
// [추출 근거] 기존 구현(LuckybagProductRow.tsx의 "확률 합계" 뱃지)은 서버에서 계산되어
//   페이지 로드 시 정적으로 표시될 뿐, 사용자가 확률 값을 "입력하는 중"에 실시간으로
//   합계를 계산해 보여주지 않았다(저장 후 재조회 시에만 갱신) — 08§3.4가 명시하는
//   "실시간 검증 UI"와 차이가 있어 이번 소단위에서 이 갭을 메운다.
// [설계 결정] LuckybagRewardPoolCreateForm.tsx(6열 그리드)와 LuckybagRewardPoolRow.tsx
//   (인라인 flex, 수정모드)는 상품 select와 확률 input이 레이아웃상 서로 인접하지 않아
//   두 필드를 하나의 컴포넌트로 감싸 DOM 순서를 재배치하면 기존 레이아웃이 깨진다.
//   따라서 select/input 엘리먼트 자체는 각 호출부에 그대로 두고(시각적 결과 불변),
//   "실시간 합계 계산 + 뱃지 렌더링" 로직만 이 컴포넌트로 추출한다. 호출부는 select/input의
//   onChange로 selectedProductId/probabilityInput 상태만 올려주면 된다.
interface ProbabilityEditorProps {
  /** 현재 선택된 상품 ID(select onChange으로 상위에서 갱신). 미선택 시 null. */
  selectedProductId: number | null;
  /** 현재 입력 중인 확률 값(number input onChange의 e.target.value, 문자열 그대로) */
  probabilityInput: string;
  /** 상품별 기존 확률 합계(서버에서 내려온 값). key=productId(number), value=합계(%) */
  probabilitySumByProduct: Record<number, number>;
  /**
   * 수정 모드 전용: 자기 자신(현재 편집 중인 보상 항목)이 이미 probabilitySumByProduct에
   * 포함되어 있으므로 이중 계산을 막기 위해 제외할 대상 상품 ID.
   * (선택된 상품이 이 값과 같을 때만 excludeAmount를 뺀다 — 상품을 다른 것으로 바꾸면
   * 그 상품의 합계에는 자신이 원래 포함되어 있지 않으므로 제외하지 않는다.)
   */
  excludeProductId?: number;
  /** excludeProductId와 함께 사용, 제외할 확률 값(수정 모드에서 자기 자신의 기존 확률) */
  excludeAmount?: number;
  /** 뱃지 wrapper에 적용할 className(호출부마다 레이아웃이 달라 전달받음) */
  wrapperClassName: string;
}

export default function ProbabilityEditor({
  selectedProductId,
  probabilityInput,
  probabilitySumByProduct,
  excludeProductId,
  excludeAmount,
  wrapperClassName,
}: ProbabilityEditorProps) {
  if (selectedProductId == null) {
    return (
      <p className={wrapperClassName}>
        <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-500">
          상품을 선택하면 실시간 확률 합계가 표시됩니다
        </span>
      </p>
    );
  }

  const rawBase = probabilitySumByProduct[selectedProductId] ?? 0;
  const baseSum =
    excludeProductId != null && selectedProductId === excludeProductId
      ? rawBase - (excludeAmount ?? 0)
      : rawBase;

  const parsedInput = parseFloat(probabilityInput);
  const inputVal = Number.isNaN(parsedInput) ? 0 : parsedInput;
  const liveTotal = Math.round((baseSum + inputVal) * 10000) / 10000;

  const isComplete = Math.abs(liveTotal - 100) < 0.0001;
  const isOver = liveTotal > 100.0001;

  const cls = isOver
    ? "bg-rose-950/60 text-rose-400"
    : isComplete
      ? "bg-emerald-950/60 text-emerald-400"
      : "bg-amber-950/60 text-amber-400";

  return (
    <p className={wrapperClassName}>
      <span className={`rounded-full px-2 py-0.5 text-xs ${cls}`}>
        실시간 합계: 기존 {baseSum}% + 입력 {inputVal}% = {liveTotal}%
        {isOver ? " (100% 초과 — 저장 불가)" : !isComplete ? " (미완성)" : " (완성)"}
      </span>
    </p>
  );
}
