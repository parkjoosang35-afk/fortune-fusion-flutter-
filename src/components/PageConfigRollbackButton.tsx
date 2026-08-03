"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

interface Props {
  versionNumber: number;
}

export default function PageConfigRollbackButton({ versionNumber }: Props) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function rollback() {
    if (
      !confirm(
        `v${versionNumber} 버전으로 롤백하시겠습니까?\n현재 발행중인 버전 대신 이 버전이 즉시 서비스에 반영됩니다.`,
      )
    ) {
      return;
    }
    setPending(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/page-configs/home/rollback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ targetVersionNumber: versionNumber }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error ?? "롤백 실패");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "롤백 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="flex flex-col items-start gap-1">
      <button
        type="button"
        disabled={pending}
        onClick={rollback}
        className="rounded border border-amber-800 px-2 py-1 text-xs text-amber-300 hover:bg-amber-900/40 disabled:opacity-40"
      >
        {pending ? "롤백 중..." : "이 버전으로 롤백"}
      </button>
      {error && <p className="text-xs text-rose-400">{error}</p>}
    </div>
  );
}
