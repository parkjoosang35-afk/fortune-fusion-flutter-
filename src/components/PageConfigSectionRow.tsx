"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BLOCK_TYPE_LABELS, type BlockType } from "@/lib/page-config-constants";

interface SectionRowData {
  id: number;
  sectionKey: string;
  title: string | null;
  blockType: string;
  status: string;
  isPinned: boolean;
  isRequired: boolean;
  scheduleEnabled: boolean;
  startAt: string | null;
  endAt: string | null;
  platformTargets: string | null;
  updatedAt: string;
  attachmentCount: number;
  ruleCount: number;
}

interface Props {
  section: SectionRowData;
  allSectionIds: number[];
  index: number;
  isFirst: boolean;
  isLast: boolean;
  canWrite: boolean;
}

const STATUS_BADGE: Record<string, string> = {
  visible: "bg-emerald-900/60 text-emerald-300",
  hidden: "bg-amber-900/60 text-amber-300",
  archived: "bg-slate-800 text-slate-400",
};

export default function PageConfigSectionRow({
  section,
  allSectionIds,
  index,
  isFirst,
  isLast,
  canWrite,
}: Props) {
  const router = useRouter();
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function reorder(direction: "up" | "down") {
    setPending("reorder");
    setError(null);
    try {
      const order = [...allSectionIds];
      const targetIndex = direction === "up" ? index - 1 : index + 1;
      [order[index], order[targetIndex]] = [order[targetIndex], order[index]];

      const res = await fetch("/api/admin/page-configs/home/sections/reorder", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ order }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "순서 변경 실패");
    } finally {
      setPending(null);
    }
  }

  async function setStatus(status: "visible" | "hidden" | "archived") {
    setPending(status);
    setError(null);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/visibility`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status, isVisible: status === "visible" }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "상태 변경 실패");
    } finally {
      setPending(null);
    }
  }

  async function duplicate() {
    setPending("duplicate");
    setError(null);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/duplicate`, {
        method: "POST",
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "복제 실패");
    } finally {
      setPending(null);
    }
  }

  async function remove() {
    if (!confirm(`"${section.title ?? section.sectionKey}" 섹션을 삭제하시겠습니까?`)) return;
    setPending("delete");
    setError(null);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}`, {
        method: "DELETE",
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "삭제 실패");
    } finally {
      setPending(null);
    }
  }

  let platforms: string[] | null = null;
  try {
    platforms = section.platformTargets ? JSON.parse(section.platformTargets) : null;
  } catch {
    platforms = null;
  }

  return (
    <tr className="border-b border-slate-800/60 align-top">
      <td className="px-3 py-3">
        <div className="flex flex-col items-center gap-1">
          <span className="text-slate-500">{index + 1}</span>
          {canWrite && (
            <div className="flex gap-1">
              <button
                type="button"
                disabled={isFirst || pending !== null}
                onClick={() => reorder("up")}
                className="rounded border border-slate-700 px-1 text-xs text-slate-400 hover:bg-slate-800 disabled:opacity-30"
                title="위로"
              >
                ↑
              </button>
              <button
                type="button"
                disabled={isLast || pending !== null}
                onClick={() => reorder("down")}
                className="rounded border border-slate-700 px-1 text-xs text-slate-400 hover:bg-slate-800 disabled:opacity-30"
                title="아래로"
              >
                ↓
              </button>
            </div>
          )}
        </div>
      </td>
      <td className="px-3 py-3">
        <div className="font-medium text-white">
          {section.title ?? <span className="text-slate-500">(제목 없음)</span>}
          {section.isPinned && (
            <span className="ml-2 rounded bg-indigo-900/60 px-1.5 py-0.5 text-xs text-indigo-300">고정</span>
          )}
          {section.isRequired && (
            <span className="ml-2 rounded bg-rose-900/60 px-1.5 py-0.5 text-xs text-rose-300">필수</span>
          )}
        </div>
        <div className="text-xs text-slate-500">{section.sectionKey}</div>
        <div className="mt-1 text-xs text-slate-500">
          첨부 {section.attachmentCount}개 · 노출조건 {section.ruleCount}개
        </div>
      </td>
      <td className="px-3 py-3 text-slate-300">
        {BLOCK_TYPE_LABELS[section.blockType as BlockType] ?? section.blockType}
      </td>
      <td className="px-3 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${STATUS_BADGE[section.status] ?? "bg-slate-800 text-slate-400"}`}>
          {section.status}
        </span>
      </td>
      <td className="px-3 py-3 text-xs text-slate-400">
        {platforms && platforms.length > 0 ? platforms.join(", ") : "전체"}
      </td>
      <td className="px-3 py-3 text-xs text-slate-400">
        {section.scheduleEnabled ? (
          <div>
            <div>시작: {section.startAt ? new Date(section.startAt).toLocaleString("ko-KR") : "-"}</div>
            <div>종료: {section.endAt ? new Date(section.endAt).toLocaleString("ko-KR") : "-"}</div>
          </div>
        ) : (
          "즉시 노출"
        )}
      </td>
      <td className="px-3 py-3 text-xs text-slate-500">
        {new Date(section.updatedAt).toLocaleString("ko-KR")}
      </td>
      <td className="px-3 py-3">
        <div className="flex flex-wrap gap-1">
          <Link
            href={`/cms/page-configs/home/sections/${section.id}`}
            className="rounded border border-slate-700 px-2 py-1 text-xs text-slate-300 hover:bg-slate-800"
          >
            편집
          </Link>
          {canWrite && (
            <>
              {section.status !== "visible" && (
                <button
                  type="button"
                  disabled={pending !== null}
                  onClick={() => setStatus("visible")}
                  className="rounded border border-emerald-800 px-2 py-1 text-xs text-emerald-300 hover:bg-emerald-900/40 disabled:opacity-40"
                >
                  노출
                </button>
              )}
              {section.status !== "hidden" && (
                <button
                  type="button"
                  disabled={pending !== null}
                  onClick={() => setStatus("hidden")}
                  className="rounded border border-amber-800 px-2 py-1 text-xs text-amber-300 hover:bg-amber-900/40 disabled:opacity-40"
                >
                  숨김
                </button>
              )}
              {!section.isRequired && section.status !== "archived" && (
                <button
                  type="button"
                  disabled={pending !== null}
                  onClick={() => setStatus("archived")}
                  className="rounded border border-slate-700 px-2 py-1 text-xs text-slate-400 hover:bg-slate-800 disabled:opacity-40"
                >
                  보관
                </button>
              )}
              <button
                type="button"
                disabled={pending !== null}
                onClick={duplicate}
                className="rounded border border-indigo-800 px-2 py-1 text-xs text-indigo-300 hover:bg-indigo-900/40 disabled:opacity-40"
              >
                복제
              </button>
              {!section.isRequired && (
                <button
                  type="button"
                  disabled={pending !== null}
                  onClick={remove}
                  className="rounded border border-rose-900 px-2 py-1 text-xs text-rose-400 hover:bg-rose-950/40 disabled:opacity-40"
                >
                  삭제
                </button>
              )}
            </>
          )}
        </div>
        {error && <p className="mt-1 text-xs text-rose-400">{error}</p>}
      </td>
    </tr>
  );
}
