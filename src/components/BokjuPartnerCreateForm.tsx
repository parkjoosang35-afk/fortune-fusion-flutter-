"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function BokjuPartnerCreateForm({ canWrite }: { canWrite: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [managerName, setManagerName] = useState("");
  const [managerContact, setManagerContact] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!canWrite) return null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return setError("업체명을 입력해주세요.");
    setPending(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/bokju-coupons/partners", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim(), managerName: managerName.trim() || undefined, managerContact: managerContact.trim() || undefined }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setName("");
      setManagerName("");
      setManagerContact("");
      setOpen(false);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "업체 등록 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="mb-6">
      {!open ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="rounded-lg border border-indigo-300 bg-indigo-100 px-4 py-2 text-sm text-indigo-800 hover:bg-indigo-100"
        >
          + 새 제휴업체 등록
        </button>
      ) : (
        <form onSubmit={submit} className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4 sm:flex-row sm:items-end">
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">업체명 *</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded border border-slate-300 px-3 py-2 text-sm" />
          </div>
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">담당자명</label>
            <input value={managerName} onChange={(e) => setManagerName(e.target.value)} className="w-full rounded border border-slate-300 px-3 py-2 text-sm" />
          </div>
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">담당자 연락처</label>
            <input value={managerContact} onChange={(e) => setManagerContact(e.target.value)} className="w-full rounded border border-slate-300 px-3 py-2 text-sm" />
          </div>
          <div className="flex gap-2">
            <button type="submit" disabled={pending} className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50">
              {pending ? "등록 중..." : "등록"}
            </button>
            <button type="button" onClick={() => setOpen(false)} className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-500 hover:bg-slate-100">
              취소
            </button>
          </div>
          {error && <p className="w-full text-xs text-rose-700">{error}</p>}
        </form>
      )}
    </div>
  );
}
