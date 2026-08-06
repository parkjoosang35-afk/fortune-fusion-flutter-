"use client";

import { useEffect, useState, useCallback } from "react";
import { BLOCK_TYPE_LABELS, type BlockType } from "@/lib/page-config-constants";

interface PreviewSection {
  id: number;
  sectionKey: string;
  blockType: string;
  title: string | null;
  subtitle: string | null;
  description: string | null;
  buttonText: string | null;
  badgeText: string | null;
  status: string;
  stylePreset: string;
  isPinned: boolean;
  attachments: { attachmentUrl: string; usageType: string; isPrimary: boolean }[];
}
interface DiffEntry {
  sectionKey: string;
  change: "added" | "modified" | "unchanged" | "removed";
}
interface PreviewData {
  draftVersion: { id: number; versionNumber: number };
  publishedVersionId: number | null;
  sections: PreviewSection[];
  diff: DiffEntry[];
}

const VIEWPORTS = [
  { key: "ios", label: "iPhone", width: 390 },
  { key: "android", label: "Android", width: 412 },
  { key: "web", label: "Web", width: 480 },
] as const;

const DIFF_BADGE: Record<DiffEntry["change"], string> = {
  added: "bg-emerald-100 text-emerald-800",
  modified: "bg-amber-100 text-amber-800",
  removed: "bg-rose-100 text-rose-800",
  unchanged: "bg-white text-slate-500",
};
const DIFF_LABEL: Record<DiffEntry["change"], string> = {
  added: "추가됨",
  modified: "변경됨",
  removed: "제거됨",
  unchanged: "변경 없음",
};

export default function PageConfigPublishCenter({ canWrite }: { canWrite: boolean }) {
  const [data, setData] = useState<PreviewData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [viewport, setViewport] = useState<(typeof VIEWPORTS)[number]>(VIEWPORTS[0]);
  const [publishing, setPublishing] = useState(false);
  const [publishResult, setPublishResult] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/page-configs/home/preview");
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setData(json.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "미리보기 조회 실패");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function publish() {
    if (!confirm("draft 내용을 새 버전으로 발행하시겠습니까? 발행 후에도 이전 버전으로 언제든 롤백할 수 있습니다.")) return;
    setPublishing(true);
    setPublishResult(null);
    try {
      const res = await fetch("/api/admin/page-configs/home/publish", { method: "POST" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setPublishResult(`v${json.data.publishedVersion.versionNumber} 발행 완료`);
      await load();
    } catch (e) {
      setPublishResult(`발행 실패: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      setPublishing(false);
    }
  }

  if (loading) return <p className="text-sm text-slate-500">불러오는 중...</p>;
  if (error) return <p className="text-sm text-rose-700">{error}</p>;
  if (!data) return null;

  const visibleSections = data.sections.filter((s) => s.status === "visible");
  const diffCounts = data.diff.reduce(
    (acc, d) => ({ ...acc, [d.change]: (acc[d.change] ?? 0) + 1 }),
    {} as Record<string, number>,
  );

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <div className="lg:col-span-2">
        <div className="mb-3 flex items-center gap-2">
          {VIEWPORTS.map((v) => (
            <button
              key={v.key}
              type="button"
              onClick={() => setViewport(v)}
              className={`rounded-lg px-3 py-1.5 text-sm ${
                viewport.key === v.key ? "bg-indigo-600 text-white" : "border border-slate-300 text-slate-500 hover:bg-slate-100"
              }`}
            >
              {v.label}
            </button>
          ))}
          <span className="text-xs text-slate-500">draft v{data.draftVersion.versionNumber} 기준 미리보기</span>
        </div>

        <div
          className="mx-auto overflow-hidden rounded-2xl border-4 border-slate-200 bg-white"
          style={{ width: viewport.width, maxWidth: "100%" }}
        >
          <div className="max-h-[720px] overflow-y-auto bg-slate-50">
            {visibleSections.length === 0 && (
              <p className="p-6 text-center text-sm text-slate-500">노출 중인 섹션이 없습니다.</p>
            )}
            {visibleSections.map((s) => (
              <div key={s.id} className="border-b border-slate-200 bg-white p-3">
                <div className="mb-1 flex items-center gap-1">
                  <span className="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] text-slate-500">
                    {BLOCK_TYPE_LABELS[s.blockType as BlockType] ?? s.blockType}
                  </span>
                  {s.isPinned && <span className="rounded bg-indigo-100 px-1.5 py-0.5 text-[10px] text-indigo-600">고정</span>}
                  {s.badgeText && <span className="rounded bg-rose-100 px-1.5 py-0.5 text-[10px] text-rose-600">{s.badgeText}</span>}
                </div>
                {s.attachments.find((a) => a.isPrimary && a.usageType === "banner") && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={s.attachments.find((a) => a.isPrimary && a.usageType === "banner")!.attachmentUrl}
                    alt={s.title ?? s.sectionKey}
                    className="mb-2 h-24 w-full rounded object-cover"
                  />
                )}
                {s.title && <p className="text-sm font-bold text-slate-900">{s.title}</p>}
                {s.subtitle && <p className="text-xs text-slate-500">{s.subtitle}</p>}
                {s.description && <p className="mt-1 text-xs text-slate-600">{s.description}</p>}
                {s.buttonText && (
                  <span className="mt-2 inline-block rounded bg-indigo-600 px-3 py-1 text-xs text-white">{s.buttonText}</span>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="space-y-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <h3 className="mb-2 text-sm font-semibold text-slate-900">발행 버전과 비교(diff)</h3>
          <div className="mb-2 flex gap-2 text-xs">
            {(["added", "modified", "removed", "unchanged"] as const).map((c) => (
              <span key={c} className={`rounded px-1.5 py-0.5 ${DIFF_BADGE[c]}`}>
                {DIFF_LABEL[c]} {diffCounts[c] ?? 0}
              </span>
            ))}
          </div>
          <ul className="max-h-48 space-y-1 overflow-y-auto text-xs">
            {data.diff
              .filter((d) => d.change !== "unchanged")
              .map((d) => (
                <li key={d.sectionKey} className="flex items-center justify-between">
                  <span className="text-slate-600">{d.sectionKey}</span>
                  <span className={`rounded px-1.5 py-0.5 ${DIFF_BADGE[d.change]}`}>{DIFF_LABEL[d.change]}</span>
                </li>
              ))}
            {data.diff.every((d) => d.change === "unchanged") && (
              <li className="text-slate-500">발행된 버전과 차이가 없습니다.</li>
            )}
          </ul>
        </div>

        {canWrite && (
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <h3 className="mb-2 text-sm font-semibold text-slate-900">발행</h3>
            <p className="mb-3 text-xs text-slate-500">
              발행 즉시 draft의 스냅샷이 새 published 버전이 되고, 이어서 편집할 수 있는 새 draft가
              자동 생성됩니다.
            </p>
            <button
              type="button"
              onClick={publish}
              disabled={publishing}
              className="w-full rounded bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
            >
              {publishing ? "발행 중..." : "지금 발행하기"}
            </button>
            {publishResult && <p className="mt-2 text-xs text-slate-600">{publishResult}</p>}
          </div>
        )}
      </div>
    </div>
  );
}
