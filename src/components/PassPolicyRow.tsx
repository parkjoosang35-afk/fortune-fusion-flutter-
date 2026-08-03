"use client";

import { useActionState, useState } from "react";
import {
  updatePassPolicy,
  deletePassPolicy,
  type PassPolicyFormState,
} from "@/app/actions/pass-policies";
import OpenPassAttachmentCreateForm from "@/components/OpenPassAttachmentCreateForm";
import OpenPassAdSourceCreateForm from "@/components/OpenPassAdSourceCreateForm";
import OpenPassBindingsPanel from "@/components/OpenPassBindingsPanel";
import { detectScopePreset } from "@/lib/open-pass-constants";

interface AttachmentOption {
  id: number;
  fileName: string;
  fileType: string;
  purpose: string;
}
interface AdSourceOption {
  id: number;
  sourceName: string;
  sourceType: string;
  isActive: boolean;
}

interface PassPolicyRowProps {
  policy: {
    id: number;
    name: string;
    passType: string;
    durationMin: number;
    dailyLimit: number | null;
    ctaText: string | null;
    bannerImageUrl: string | null;
    linkUrl: string | null;
    bonusPoint: number;
    isActive: boolean;
    // [열림패스 첨부/광고소스 통합] 대표 소재 슬롯 + 행복머니 가격 — OpenPassBindingsPanel의
    // PolicyOption과 동일한 형태로 이 행 자체에서 바로 바인딩 패널을 렌더링하기 위해 필요.
    heroAttachmentId: number | null;
    promoAttachmentId: number | null;
    fallbackAttachmentId: number | null;
    happyMoneyPrice: number | null;
    // ── [프리패스 테스트 인프라 §3] 이 행의 수정 폼이 새 필드를 놓치고 기본값으로
    // 덮어쓰지 않도록(§15 데이터 손실 금지) 확장 값을 hidden input으로 보존한다.
    description: string | null;
    scope: string;
    adRewardEnabled: boolean;
    isFeatured: boolean;
    displayPriority: number;
    startAt: Date | null;
    endAt: Date | null;
    testModeAllowed: boolean;
    uiCopy: string | null;
  };
  canWrite: boolean;
  canDelete: boolean;
  // [열림패스 첨부/광고소스 통합] 정책 목록 화면(pass-policies/page.tsx)에서 한 번만 조회한
  // 첨부파일/광고소스 전체 목록을 그대로 전달받아, 이 행에서 등록 폼 + 연결(N:M) 패널을 띄운다.
  attachments: AttachmentOption[];
  adSources: AdSourceOption[];
}

const PASS_TYPE_OPTIONS = [
  { value: "ad", label: "광고 시청" },
  { value: "partner", label: "파트너 제휴" },
  { value: "subscription", label: "구독" },
  { value: "event", label: "이벤트" },
];

const PASS_TYPE_BADGE: Record<string, string> = {
  ad: "bg-sky-950/60 text-sky-400",
  partner: "bg-purple-950/60 text-purple-400",
  subscription: "bg-emerald-950/60 text-emerald-400",
  event: "bg-amber-950/60 text-amber-400",
};

const initialState: PassPolicyFormState = {};

// [§3 확장 필드 보존] scope CSV 문자열을 보고 가장 가까운 preset 키를 역추정(import 최소화를 위해
// open-pass-constants 의존 대신 이 파일에서는 간단히 "all_fortune이 아니면 그대로 값을 유지"하는
// 방식 대신, 서버액션과 동일한 로직을 쓰기 위해 open-pass-constants를 그대로 import한다.
function parseUiCopySafe(uiCopy: string | null): { lockCopy?: string | null; acquireCopy?: string | null; expireCopy?: string | null } {
  if (!uiCopy) return {};
  try {
    return JSON.parse(uiCopy);
  } catch {
    return {};
  }
}

function detectScopePresetSafe(scope: string): string {
  try {
    return detectScopePreset(scope);
  } catch {
    return "all_fortune";
  }
}

export default function PassPolicyRow({
  policy,
  canWrite,
  canDelete,
  attachments,
  adSources,
}: PassPolicyRowProps) {
  const [editing, setEditing] = useState(false);
  // [열림패스 첨부/광고소스 통합] "첨부/광고소스" 토글 — 이 정책에 바로 첨부파일 등록,
  // 광고소스 등록, 그리고 둘의 연결(N:M) + 대표 소재 슬롯 지정까지 한 화면에서 처리한다.
  const [managingAssets, setManagingAssets] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updatePassPolicy, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deletePassPolicy, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={7} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={policy.id} />
            <input
              type="text"
              name="name"
              defaultValue={policy.name}
              className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <select
              name="passType"
              defaultValue={policy.passType}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            >
              {PASS_TYPE_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
            <input
              type="number"
              name="durationMin"
              defaultValue={policy.durationMin}
              min={1}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="dailyLimit"
              defaultValue={policy.dailyLimit ?? ""}
              min={0}
              placeholder="한도(선택)"
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="bonusPoint"
              defaultValue={policy.bonusPoint}
              min={0}
              placeholder="보너스P"
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="linkUrl"
              defaultValue={policy.linkUrl ?? ""}
              placeholder="링크URL"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="ctaText"
              defaultValue={policy.ctaText ?? ""}
              placeholder="CTA문구"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="bannerImageUrl"
              defaultValue={policy.bannerImageUrl ?? ""}
              placeholder="배너URL"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={policy.isActive}
                className="accent-indigo-500"
              />
              활성
            </label>
            {/* [§3 확장 필드 보존] 이 간략 수정 폼은 이름/기간/금액만 바꿀 때 쓰고,
                나머지 §3 확장 필드(설명/범위/광고허용/대표/우선순위/기간/테스트모드/카피)은
                새 상품 추가 폼에서만 입력하고, 여기서는 기존값 그대로 유지(hidden)한다.
                상세 필드 편집이 필요하면 상단 "새 프리패스 상품 추가" 폼과 같은 확장 UI를
                이 행에도 후속 작업으로 추가하는 것을 권장(§14 "남은 미세조정 포인트" 참조). */}
            <input type="hidden" name="description" value={policy.description ?? ""} />
            <input type="hidden" name="scopePreset" value={detectScopePresetSafe(policy.scope)} />
            <input type="hidden" name="happyMoneyPrice" value={policy.happyMoneyPrice ?? ""} />
            <input type="hidden" name="displayPriority" value={policy.displayPriority} />
            <input
              type="hidden"
              name="startAt"
              value={policy.startAt ? new Date(policy.startAt).toISOString().slice(0, 16) : ""}
            />
            <input
              type="hidden"
              name="endAt"
              value={policy.endAt ? new Date(policy.endAt).toISOString().slice(0, 16) : ""}
            />
            {policy.adRewardEnabled && <input type="hidden" name="adRewardEnabled" value="on" />}
            {policy.isFeatured && <input type="hidden" name="isFeatured" value="on" />}
            {policy.testModeAllowed && <input type="hidden" name="testModeAllowed" value="on" />}
            <input type="hidden" name="lockCopy" value={parseUiCopySafe(policy.uiCopy).lockCopy ?? ""} />
            <input type="hidden" name="acquireCopy" value={parseUiCopySafe(policy.uiCopy).acquireCopy ?? ""} />
            <input type="hidden" name="expireCopy" value={parseUiCopySafe(policy.uiCopy).expireCopy ?? ""} />
            <button
              type="submit"
              disabled={updatePending}
              className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              저장
            </button>
            <button
              type="button"
              onClick={() => setEditing(false)}
              className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800"
            >
              취소
            </button>
            {updateState.error && <p className="w-full text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <>
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-200">{policy.name}</td>
      <td className="px-4 py-3">
        <span
          className={`rounded-full px-2 py-0.5 text-xs ${
            PASS_TYPE_BADGE[policy.passType] ?? "bg-slate-800 text-slate-400"
          }`}
        >
          {PASS_TYPE_OPTIONS.find((o) => o.value === policy.passType)?.label ?? policy.passType}
        </span>
      </td>
      <td className="px-4 py-3 text-slate-300">{policy.durationMin}분</td>
      <td className="px-4 py-3 text-slate-400">
        {policy.dailyLimit != null ? policy.dailyLimit.toLocaleString() : "무제한"}
      </td>
      <td className="px-4 py-3 text-slate-300">
        {policy.bonusPoint > 0 ? `+${policy.bonusPoint.toLocaleString()}P` : "-"}
      </td>
      <td className="px-4 py-3">
        {policy.isActive ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">활성</span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">비활성</span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800"
            >
              수정
            </button>
          )}
          <button
            onClick={() => setManagingAssets((v) => !v)}
            className={`rounded-lg border px-3 py-1 text-xs ${
              managingAssets
                ? "border-indigo-500 bg-indigo-950/60 text-indigo-300"
                : "border-slate-700 text-slate-300 hover:bg-slate-800"
            }`}
          >
            {managingAssets ? "첨부/광고소스 닫기" : "첨부/광고소스"}
          </button>
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={policy.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}
      </td>
    </tr>
    {managingAssets && (
      <tr className="border-b border-slate-800/60 bg-slate-950/40">
        <td colSpan={7} className="px-4 py-4">
          <div className="space-y-4">
            <p className="text-xs text-slate-500">
              &quot;{policy.name}&quot; 정책에 첨부파일/광고소스를 새로 등록하거나, 이미 등록된 것을 이 정책에
              연결(대표 소재 슬롯 지정 포함)할 수 있습니다.
            </p>
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              <OpenPassAttachmentCreateForm canWrite={canWrite} />
              <OpenPassAdSourceCreateForm canWrite={canWrite} attachmentOptions={attachments} />
            </div>
            <OpenPassBindingsPanel
              fixedPolicyId={policy.id}
              attachments={attachments}
              adSources={adSources}
            />
          </div>
        </td>
      </tr>
    )}
    </>
  );
}
