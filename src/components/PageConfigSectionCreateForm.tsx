"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { BLOCK_TYPES, BLOCK_TYPE_LABELS, type BlockType } from "@/lib/page-config-constants";

interface Props {
  canWrite: boolean;
  nextSortOrder: number;
}

export default function PageConfigSectionCreateForm({ canWrite, nextSortOrder }: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [sectionKey, setSectionKey] = useState("");
  const [blockType, setBlockType] = useState<BlockType>("single_card");
  const [title, setTitle] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!canWrite) return null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!sectionKey.trim()) {
      setError("sectionKey는 필수입니다. (예: new_promo_banner)");
      return;
    }
    setPending(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/page-configs/home/sections", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          sectionKey: sectionKey.trim(),
          blockType,
          title: title.trim() || null,
          sortOrder: nextSortOrder,
        }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setSectionKey("");
      setTitle("");
      setOpen(false);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "섹션 생성 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="mb-4">
      {!open ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="rounded-lg border border-indigo-300 bg-indigo-100 px-4 py-2 text-sm text-indigo-800 hover:bg-indigo-100"
        >
          + 새 섹션 추가
        </button>
      ) : (
        <form
          onSubmit={submit}
          className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4 sm:flex-row sm:items-end sm:gap-2"
        >
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">sectionKey (고유 식별자)</label>
            <input
              value={sectionKey}
              onChange={(e) => setSectionKey(e.target.value)}
              placeholder="예: new_year_event_banner"
              className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
            />
          </div>
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">블록 타입</label>
            <select
              value={blockType}
              onChange={(e) => setBlockType(e.target.value as BlockType)}
              className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
            >
              {BLOCK_TYPES.map((bt) => (
                <option key={bt} value={bt}>
                  {BLOCK_TYPE_LABELS[bt]}
                </option>
              ))}
            </select>
          </div>
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">제목(선택, 최대 18자)</label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={18}
              className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
            />
          </div>
          <div className="flex gap-2">
            <button
              type="submit"
              disabled={pending}
              className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending ? "생성 중..." : "생성"}
            </button>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-500 hover:bg-slate-100"
            >
              취소
            </button>
          </div>
          {error && <p className="w-full text-xs text-rose-700">{error}</p>}
        </form>
      )}
    </div>
  );
}
