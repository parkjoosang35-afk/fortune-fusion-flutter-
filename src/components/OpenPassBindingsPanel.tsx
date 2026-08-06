"use client";

// 열림패스 상품 - 첨부파일/광고소스 바인딩 관리 패널.
// [사용자 요청] §5/§6-4 — 상품 선택 후 여러 첨부파일/광고소스를 연결/해제/우선순위 지정.
// TestLabPanel.tsx와 동일하게 "일반 함수 + useTransition 직접 호출" 패턴을 사용한다.
import { useCallback, useEffect, useState, useTransition } from "react";
import {
  bindAttachmentToProduct,
  unbindAttachmentFromProduct,
  toggleProductAttachmentActive,
  setProductAttachmentSlot,
  bindAdSourceToProduct,
  unbindAdSourceFromProduct,
  updateProductAdSourceBinding,
  getProductBindingSnapshot,
  type BindingResult,
} from "@/app/actions/open-pass-bindings";
import {
  BINDING_USAGE_TYPES,
  AD_SOURCE_PLATFORMS,
  ATTACHMENT_PURPOSE_LABELS,
  type AttachmentPurpose,
} from "@/lib/open-pass-constants";

interface PolicyOption {
  id: number;
  name: string;
  isActive: boolean;
  happyMoneyPrice: number | null;
  heroAttachmentId: number | null;
  promoAttachmentId: number | null;
  fallbackAttachmentId: number | null;
}
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

interface Snapshot {
  policy: PolicyOption | null;
  attachmentBindings: Array<{
    id: number;
    usageType: string;
    displayOrder: number;
    isPrimary: boolean;
    isActive: boolean;
    attachment: AttachmentOption;
  }>;
  adSourceBindings: Array<{
    id: number;
    priority: number;
    isPrimary: boolean;
    platform: string;
    isActive: boolean;
    adSource: AdSourceOption;
  }>;
}

export default function OpenPassBindingsPanel({
  policies,
  attachments,
  adSources,
  fixedPolicyId,
}: {
  // [열림패스 첨부/광고소스 연동] 어드민 "열림패스"(pass-policies) 화면의 각 정책 행에서
  // 바로 관리할 수 있도록, policyId를 고정해 선택 드롭다운을 숨기는 모드를 지원한다.
  // fixedPolicyId가 주어지면 policies는 생략 가능하다(전용 정책관리 탭에서만 필요).
  policies?: PolicyOption[];
  attachments: AttachmentOption[];
  adSources: AdSourceOption[];
  fixedPolicyId?: number;
}) {
  const [policyId, setPolicyId] = useState<number | undefined>(
    fixedPolicyId ?? policies?.[0]?.id
  );
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [isPending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const [newAttachmentId, setNewAttachmentId] = useState<number | undefined>(attachments[0]?.id);
  const [newUsageType, setNewUsageType] = useState<string>(BINDING_USAGE_TYPES[0]);
  const [newAdSourceId, setNewAdSourceId] = useState<number | undefined>(adSources[0]?.id);
  const [newPlatform, setNewPlatform] = useState<string>("all");

  const showResult = useCallback((r: BindingResult) => {
    setMessage({ ok: r.success, text: r.message });
  }, []);

  const refresh = useCallback((id: number) => {
    startTransition(async () => {
      const snap = await getProductBindingSnapshot(id);
      setSnapshot(snap as unknown as Snapshot);
    });
  }, []);

  useEffect(() => {
    if (policyId) refresh(policyId);
  }, [policyId, refresh]);

  const run = useCallback(
    (fn: () => Promise<BindingResult>) => {
      startTransition(async () => {
        const r = await fn();
        showResult(r);
        if (policyId) refresh(policyId);
      });
    },
    [policyId, refresh, showResult]
  );

  if (!fixedPolicyId && (!policies || policies.length === 0)) {
    return <p className="text-sm text-slate-500">등록된 열림패스 상품이 없습니다. 먼저 &quot;열림패스&quot; 탭에서 상품을 등록해주세요.</p>;
  }

  return (
    <div className="space-y-6">
      {/* 상품 선택 (fixedPolicyId 모드에서는 숨김 — 이미 어느 정책인지 확정됨) */}
      {!fixedPolicyId && policies && (
        <section className="rounded-xl border border-slate-200 bg-white p-4">
          <h2 className="mb-3 text-sm font-semibold text-slate-900">1. 열림패스 상품 선택</h2>
          <select
            value={policyId}
            onChange={(e) => setPolicyId(Number(e.target.value))}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
          >
            {policies.map((p) => (
              <option key={p.id} value={p.id}>
                #{p.id} {p.name} {p.isActive ? "" : "(비활성)"}
              </option>
            ))}
          </select>
        </section>
      )}
      {message && (
        <p className={`rounded-lg px-3 py-2 text-xs ${message.ok ? "bg-emerald-100 text-emerald-800" : "bg-red-100 text-red-800"}`}>
          {message.text}
        </p>
      )}

      {/* 대표 슬롯(hero/promo/fallback) */}
      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-semibold text-slate-900">2. 대표 소재 슬롯 지정 (PassPolicy 직접 반영)</h2>
        <p className="mb-3 text-xs text-slate-500">
          앱은 이 3개 슬롯을 최우선으로 읽어 대표 배너 / 광고유도 배너 / 공통 fallback 소재를 노출합니다.
        </p>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          {(["hero", "promo", "fallback"] as const).map((slot) => {
            const field = slot === "hero" ? "heroAttachmentId" : slot === "promo" ? "promoAttachmentId" : "fallbackAttachmentId";
            const label = { hero: "대표(hero) 배너", promo: "광고유도(promo) 배너", fallback: "공통 fallback 소재" }[slot];
            const currentId = snapshot?.policy ? snapshot.policy[field] : null;
            return (
              <div key={slot} className="rounded-lg border border-slate-200 bg-white p-3">
                <p className="mb-2 text-xs text-slate-500">{label}</p>
                <select
                  disabled={isPending}
                  value={currentId ?? ""}
                  onChange={(e) => {
                    const attachmentId = e.target.value ? Number(e.target.value) : null;
                    if (!policyId) return;
                    run(() => setProductAttachmentSlot({ passPolicyId: policyId, slot, attachmentId }));
                  }}
                  className="w-full rounded-lg border border-slate-300 bg-white px-2 py-1.5 text-sm text-slate-900 outline-none focus:border-indigo-500"
                >
                  <option value="">미지정</option>
                  {attachments.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.fileName} ({a.fileType})
                    </option>
                  ))}
                </select>
              </div>
            );
          })}
        </div>
      </section>

      {/* 첨부파일 바인딩 */}
      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-semibold text-slate-900">3. 첨부파일 연결 (usageType별 N:M)</h2>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <select value={newAttachmentId} onChange={(e) => setNewAttachmentId(Number(e.target.value))} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500">
            {attachments.map((a) => (
              <option key={a.id} value={a.id}>{a.fileName} ({ATTACHMENT_PURPOSE_LABELS[a.purpose as AttachmentPurpose] ?? a.purpose})</option>
            ))}
          </select>
          <select value={newUsageType} onChange={(e) => setNewUsageType(e.target.value)} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500">
            {BINDING_USAGE_TYPES.map((u) => (
              <option key={u} value={u}>{u}</option>
            ))}
          </select>
          <button
            disabled={isPending || !policyId || !newAttachmentId}
            onClick={() => policyId && newAttachmentId && run(() => bindAttachmentToProduct({ passPolicyId: policyId, attachmentId: newAttachmentId, usageType: newUsageType }))}
            className="rounded-lg bg-indigo-600 px-3 py-2 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            연결 추가
          </button>
        </div>

        {snapshot && snapshot.attachmentBindings.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="text-slate-500">
                <tr>
                  <th className="px-2 py-1">첨부파일</th>
                  <th className="px-2 py-1">usageType</th>
                  <th className="px-2 py-1">대표</th>
                  <th className="px-2 py-1">상태</th>
                  <th className="px-2 py-1">관리</th>
                </tr>
              </thead>
              <tbody>
                {snapshot.attachmentBindings.map((b) => (
                  <tr key={b.id} className="border-t border-slate-200">
                    <td className="px-2 py-1.5 text-slate-700">{b.attachment.fileName}</td>
                    <td className="px-2 py-1.5 text-slate-500">{b.usageType}</td>
                    <td className="px-2 py-1.5">{b.isPrimary ? <span className="text-emerald-700">대표</span> : "-"}</td>
                    <td className="px-2 py-1.5">
                      <button
                        disabled={isPending}
                        onClick={() => run(() => toggleProductAttachmentActive(b.id, !b.isActive))}
                        className={`rounded-full px-2 py-0.5 ${b.isActive ? "bg-emerald-100 text-emerald-700" : "bg-white text-slate-500"}`}
                      >
                        {b.isActive ? "활성" : "비활성"}
                      </button>
                    </td>
                    <td className="px-2 py-1.5">
                      <button disabled={isPending} onClick={() => run(() => unbindAttachmentFromProduct(b.id))} className="rounded-lg border border-red-300 px-2 py-1 text-red-700 hover:bg-red-100 disabled:opacity-50">
                        해제
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-xs text-slate-500">연결된 첨부파일이 없습니다.</p>
        )}
      </section>

      {/* 광고소스 바인딩 */}
      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-semibold text-slate-900">4. 광고소스 연결 (platform별 N:M, priority/failover)</h2>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <select value={newAdSourceId} onChange={(e) => setNewAdSourceId(Number(e.target.value))} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500">
            {adSources.map((a) => (
              <option key={a.id} value={a.id}>{a.sourceName} {a.isActive ? "" : "(비활성)"}</option>
            ))}
          </select>
          <select value={newPlatform} onChange={(e) => setNewPlatform(e.target.value)} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500">
            {AD_SOURCE_PLATFORMS.map((p) => (
              <option key={p} value={p}>{p}</option>
            ))}
          </select>
          <button
            disabled={isPending || !policyId || !newAdSourceId}
            onClick={() => policyId && newAdSourceId && run(() => bindAdSourceToProduct({ passPolicyId: policyId, adSourceId: newAdSourceId, platform: newPlatform }))}
            className="rounded-lg bg-indigo-600 px-3 py-2 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            연결 추가
          </button>
        </div>

        {snapshot && snapshot.adSourceBindings.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="text-slate-500">
                <tr>
                  <th className="px-2 py-1">광고소스</th>
                  <th className="px-2 py-1">platform</th>
                  <th className="px-2 py-1">우선순위</th>
                  <th className="px-2 py-1">대표</th>
                  <th className="px-2 py-1">상태</th>
                  <th className="px-2 py-1">관리</th>
                </tr>
              </thead>
              <tbody>
                {snapshot.adSourceBindings.map((b) => (
                  <tr key={b.id} className="border-t border-slate-200">
                    <td className="px-2 py-1.5 text-slate-700">
                      {b.adSource.sourceName}
                      {!b.adSource.isActive && <span className="ml-1 text-red-700">(소스 비활성)</span>}
                    </td>
                    <td className="px-2 py-1.5 text-slate-500">{b.platform}</td>
                    <td className="px-2 py-1.5">
                      <input
                        type="number"
                        defaultValue={b.priority}
                        onBlur={(e) => {
                          const v = Number(e.target.value);
                          if (v !== b.priority) run(() => updateProductAdSourceBinding({ bindingId: b.id, priority: v }));
                        }}
                        className="w-14 rounded border border-slate-300 bg-white px-1 py-0.5 text-slate-900"
                      />
                    </td>
                    <td className="px-2 py-1.5">
                      <button
                        disabled={isPending}
                        onClick={() => run(() => updateProductAdSourceBinding({ bindingId: b.id, isPrimary: !b.isPrimary }))}
                        className={b.isPrimary ? "text-emerald-700" : "text-slate-500 hover:text-slate-600"}
                      >
                        {b.isPrimary ? "대표" : "지정"}
                      </button>
                    </td>
                    <td className="px-2 py-1.5">
                      <button
                        disabled={isPending}
                        onClick={() => run(() => updateProductAdSourceBinding({ bindingId: b.id, isActive: !b.isActive }))}
                        className={`rounded-full px-2 py-0.5 ${b.isActive ? "bg-emerald-100 text-emerald-700" : "bg-white text-slate-500"}`}
                      >
                        {b.isActive ? "활성" : "비활성"}
                      </button>
                    </td>
                    <td className="px-2 py-1.5">
                      <button disabled={isPending} onClick={() => run(() => unbindAdSourceFromProduct(b.id))} className="rounded-lg border border-red-300 px-2 py-1 text-red-700 hover:bg-red-100 disabled:opacity-50">
                        해제
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-xs text-slate-500">연결된 광고소스가 없습니다. (광고 시청 버튼이 노출되지 않습니다)</p>
        )}
      </section>
    </div>
  );
}
