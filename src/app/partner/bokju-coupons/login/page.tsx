"use client";

// [복주머니 마케팅 쿠폰] 제휴업체 전용 로그인 화면.
// admin 로그인(src/app/login/page.tsx)과 디자인 톤을 맞추되, 완전히 별개 경로/세션
// 체계(bokju_partner_session 쿠키)를 사용한다 — 관리자 계정으로는 로그인 불가.
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function PartnerLoginPage() {
  const router = useRouter();
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setPending(true);
    setError(null);
    try {
      const res = await fetch("/api/partner/bokju-coupons/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ loginId, password }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.push("/partner/bokju-coupons/allocations");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "로그인 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#2a0a0a] px-4">
      <div className="w-full max-w-sm rounded-2xl border border-amber-900/30 bg-white p-8 shadow-xl">
        <div className="mb-8 text-center">
          <h1 className="text-xl font-bold text-slate-900">신통방통 제휴업체 센터</h1>
          <p className="mt-1 text-sm text-slate-500">복주머니 쿠폰 배포 현황 조회/보고</p>
        </div>

        <form onSubmit={submit} className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-slate-600">로그인 ID</label>
            <input
              value={loginId}
              onChange={(e) => setLoginId(e.target.value)}
              autoComplete="username"
              required
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 outline-none focus:border-amber-600"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-slate-600">비밀번호</label>
            <input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              type="password"
              autoComplete="current-password"
              required
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 outline-none focus:border-amber-600"
            />
          </div>

          {error && <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{error}</p>}

          <button
            type="submit"
            disabled={pending}
            className="w-full rounded-lg bg-[#7a1f1f] px-3 py-2 font-medium text-white transition hover:bg-[#8a2525] disabled:opacity-60"
          >
            {pending ? "로그인 중..." : "로그인"}
          </button>
        </form>
        <p className="mt-6 text-center text-xs text-slate-400">
          로그인 계정은 신통방통 운영팀이 발급합니다. 계정 문의는 담당자에게 연락해주세요.
        </p>
      </div>
    </div>
  );
}
