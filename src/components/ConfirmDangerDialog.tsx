"use client";

// 08§3.4 표준컴포넌트: ConfirmDangerDialog
// "05단계 4장 위험 조작 2단계 확인 표준 구현(환불/역할변경/확률편집 등에서 재사용)"
//
// [추출 근거] LuckybagRewardPoolRow.tsx / LuckybagRewardPoolCreateForm.tsx / ReportRow.tsx
//   3곳에 동일한 패턴(confirming state → 1차 제출 시 e.preventDefault()로 서버 전송 차단하고
//   경고 메시지만 노출 → 2차 제출 시 실제 action 실행, 버튼 색상/텍스트 전환)이 중복 구현되어
//   있어 08§3.4 스펙에 따라 공용 컴포넌트로 추출한다.
// [범위 결정] 원칙④(일괄전체구현금지): 기존 3곳의 시각적 결과(className, 문구, 레이아웃)는
//   변경하지 않고 그대로 유지한다 — 호출부에서 className/텍스트를 그대로 넘겨받아 렌더링만
//   공통화한다. confirming state 자체와 실제 제출(action) 로직은 Server Actions 특성상
//   각 호출부(useActionState 사용처)에 그대로 둔다(폼 태그 자체를 이 컴포넌트가 감싸지 않음).
interface ConfirmDangerDialogProps {
  /** 2단계 확인 대기 상태 여부(1차 제출 후 true) */
  confirming: boolean;
  /** 실제 서버 액션 진행 중 여부(버튼 비활성화 + pendingLabel 노출) */
  pending: boolean;
  /** 경고 메시지 본문(컴포넌트가 앞에 "⚠ "를 자동으로 붙인다) */
  warningText: string;
  /** 경고 메시지 하단 보조 설명(선택, 있으면 박스형 레이아웃으로 렌더링) */
  helperText?: string;
  /** 경고 메시지 컨테이너(div 또는 p)에 적용할 className */
  warningClassName: string;
  /** 평시(confirming=false) 버튼 라벨 */
  idleLabel: string;
  /** 확인 대기(confirming=true) 버튼 라벨 */
  confirmLabel: string;
  /** 서버 액션 처리 중(pending=true) 버튼 라벨 */
  pendingLabel: string;
  /** 평시 버튼 className */
  idleButtonClassName: string;
  /** 확인 대기 버튼 className(보통 rose 계열) */
  confirmButtonClassName: string;
  /** 취소 버튼 클릭 핸들러(호출부가 confirming state 등을 직접 리셋) */
  onCancel: () => void;
  /** 취소 버튼을 confirming=false 상태에서도 항상 노출할지 여부(예: 수정모드 종료용) */
  showCancelWhenIdle?: boolean;
  /** 취소 버튼 라벨 */
  cancelLabel?: string;
  /** 취소 버튼 className(호출부마다 크기가 달라 필수로 전달받음) */
  cancelButtonClassName: string;
  /** 버튼(+취소버튼) 묶음을 감싸는 래퍼 className */
  buttonWrapperClassName: string;
}

export default function ConfirmDangerDialog({
  confirming,
  pending,
  warningText,
  helperText,
  warningClassName,
  idleLabel,
  confirmLabel,
  pendingLabel,
  idleButtonClassName,
  confirmButtonClassName,
  onCancel,
  showCancelWhenIdle = false,
  cancelLabel = "취소",
  cancelButtonClassName,
  buttonWrapperClassName,
}: ConfirmDangerDialogProps) {
  return (
    <>
      {confirming &&
        (helperText ? (
          <div className={warningClassName}>
            <p className="text-xs font-semibold text-rose-300">⚠ {warningText}</p>
            <p className="mt-1 text-xs text-slate-400">{helperText}</p>
          </div>
        ) : (
          <p className={warningClassName}>⚠ {warningText}</p>
        ))}
      <div className={buttonWrapperClassName}>
        <button
          type="submit"
          disabled={pending}
          className={confirming ? confirmButtonClassName : idleButtonClassName}
        >
          {pending ? pendingLabel : confirming ? confirmLabel : idleLabel}
        </button>
        {(confirming || showCancelWhenIdle) && (
          <button type="button" onClick={onCancel} className={cancelButtonClassName}>
            {cancelLabel}
          </button>
        )}
      </div>
    </>
  );
}
