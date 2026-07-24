"use client";

// 05_Admin_System_Design.md §4.4 "복주머니 확률테이블 편집 워크플로우 (위험 조작)":
// "검증 통과 시 2단계 확인 모달(\"실제 서비스에 즉시 반영됩니다\") → 저장 + operation_logs 기록"
// [수정 근거] §4 워크플로우 재검토 중 발견 — 기존 구현은 100% 초과 차단 검증까지는 있었으나
//   2단계 확인 모달이 없어 스펙 미준수였음. Server Action(luckybag.ts)의 검증/RBAC/
//   operation_logs 로직은 변경하지 않고, 클라이언트 단에 GiftcardIssueActionCell과 동일한
//   "1단계 확인 노출 → 2단계 최종 확인 시에만 실제 submit" 패턴만 추가한다(설계 충돌 없음).
import { useActionState, useRef, useState } from "react";
import { createLuckybagRewardPool, type LuckybagFormState } from "@/app/actions/luckybag";
import ConfirmDangerDialog from "./ConfirmDangerDialog";

interface LuckybagRewardPoolCreateFormProps {
  canWrite: boolean;
  products: { id: number; name: string }[];
  grades: { id: number; name: string; code: string }[];
}

const REWARD_TYPES = [
  { value: "none", label: "꽝(보상 없음)" },
  { value: "point", label: "포인트" },
  { value: "amulet", label: "부적" },
  { value: "giftcard_fragment", label: "상품권 조각" },
];

const initialState: LuckybagFormState = {};

export default function LuckybagRewardPoolCreateForm({
  canWrite,
  products,
  grades,
}: LuckybagRewardPoolCreateFormProps) {
  const [state, formAction, pending] = useActionState(createLuckybagRewardPool, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const [confirming, setConfirming] = useState(false);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      onSubmit={(e) => {
        // 05§4.4: 1단계 제출 시점에는 서버 전송을 막고 2단계 확인 모달만 노출한다.
        if (!confirming) {
          e.preventDefault();
          setConfirming(true);
        }
      }}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setConfirming(false);
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-6"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">
        새 보상 항목 추가 (확률테이블)
      </h3>
      <select
        name="luckybagProductId"
        required
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      >
        <option value="" disabled>
          복주머니 상품 선택
        </option>
        {products.map((p) => (
          <option key={p.id} value={p.id}>
            {p.name}
          </option>
        ))}
      </select>
      <select
        name="gradeId"
        required
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="" disabled>
          등급 선택
        </option>
        {grades.map((g) => (
          <option key={g.id} value={g.id}>
            {g.name} ({g.code})
          </option>
        ))}
      </select>
      <select
        name="rewardType"
        required
        defaultValue="point"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        {REWARD_TYPES.map((rt) => (
          <option key={rt.value} value={rt.value}>
            {rt.label}
          </option>
        ))}
      </select>
      <input
        type="number"
        name="rewardAmount"
        placeholder="보상 수량/금액 (선택)"
        min={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="probability"
        placeholder="확률(%)"
        min={0.0001}
        max={100}
        step={0.0001}
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          보상 항목이 추가되었습니다.
        </p>
      )}

      <ConfirmDangerDialog
        confirming={confirming}
        pending={pending}
        warningText="정말 추가하시겠습니까? 실제 서비스에 즉시 반영됩니다."
        helperText="2단계 확인 — 확인을 누르면 즉시 저장되어 회원의 복주머니 추첨 확률에 반영됩니다."
        warningClassName="col-span-full rounded-lg border border-rose-900/60 bg-rose-950/20 p-3"
        idleLabel="보상 항목 추가"
        confirmLabel="확인(최종 추가)"
        pendingLabel="추가 중..."
        idleButtonClassName="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        confirmButtonClassName="rounded-lg bg-rose-700 px-4 py-2 text-sm font-medium text-white transition hover:bg-rose-600 disabled:cursor-not-allowed disabled:opacity-50"
        cancelButtonClassName="rounded-lg border border-slate-700 px-4 py-2 text-sm text-slate-300 hover:bg-slate-800"
        buttonWrapperClassName="col-span-full flex gap-2"
        onCancel={() => setConfirming(false)}
      />
      <p className="col-span-full mt-2 text-xs text-slate-500">
        ※ 04A I-3 명시: 동일 상품 내 보상 항목의 확률 합계는 100%를 넘을 수 없습니다.
        위 상품 목록의 &quot;확률 합계&quot; 뱃지가 100%가 아니면 아직 확률테이블이 미완성 상태입니다.
      </p>
    </form>
  );
}
