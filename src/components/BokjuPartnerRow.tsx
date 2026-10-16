"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

interface Account {
  id: number;
  loginId: string;
  role: string;
  status: string;
  lastLoginAt: string | null;
}

interface Partner {
  id: number;
  name: string;
  managerName: string | null;
  managerContact: string | null;
  status: string;
  accounts: Account[];
}

export default function BokjuPartnerRow({ partner, canWrite }: { partner: Partner; canWrite: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function issueAccount(e: React.FormEvent) {
    e.preventDefault();
    if (!loginId.trim() || password.length < 8) {
      setError("로그인ID와 8자 이상 비밀번호를 입력하세요.");
      return;
    }
    setPending(true);
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/partners/${partner.id}/accounts`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ loginId: loginId.trim(), password }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setLoginId("");
      setPassword("");
      setOpen(false);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "계정 발급 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <tr className="border-b border-slate-100 align-top">
      <td className="px-4 py-3 font-medium text-slate-900">{partner.name}</td>
      <td className="px-4 py-3">{partner.managerName ?? "-"}</td>
      <td className="px-4 py-3">{partner.managerContact ?? "-"}</td>
      <td className="px-4 py-3">
        {partner.accounts.length === 0 ? (
          <span className="text-xs text-slate-400">계정 없음</span>
        ) : (
          <ul className="space-y-0.5 text-xs">
            {partner.accounts.map((a) => (
              <li key={a.id}>
                {a.loginId} <span className="text-slate-400">({a.role})</span>
              </li>
            ))}
          </ul>
        )}
      </td>
      <td className="px-4 py-3">
        {canWrite && (
          <>
            {!open ? (
              <button onClick={() => setOpen(true)} className="rounded border border-slate-300 px-2 py-1 text-xs hover:bg-slate-100">
                계정 발급
              </button>
            ) : (
              <form onSubmit={issueAccount} className="flex flex-col gap-1">
                <input
                  value={loginId}
                  onChange={(e) => setLoginId(e.target.value)}
                  placeholder="로그인ID"
                  className="w-32 rounded border border-slate-300 px-2 py-1 text-xs"
                />
                <input
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="비밀번호(8자+)"
                  type="text"
                  className="w-32 rounded border border-slate-300 px-2 py-1 text-xs"
                />
                <div className="flex gap-1">
                  <button type="submit" disabled={pending} className="rounded bg-indigo-600 px-2 py-1 text-xs text-white disabled:opacity-50">
                    발급
                  </button>
                  <button type="button" onClick={() => setOpen(false)} className="rounded border border-slate-300 px-2 py-1 text-xs">
                    취소
                  </button>
                </div>
                {error && <p className="text-xs text-rose-700">{error}</p>}
              </form>
            )}
          </>
        )}
      </td>
    </tr>
  );
}
