// 6-7-4-B-4: 외부(웹) 계정삭제 페이지
//
// [Google Play 정책 대응] "계정 생성 앱은 앱 내부뿐 아니라 외부 웹에서도
// 계정삭제(회원탈퇴)를 요청할 수 있어야 한다"는 요구사항 충족을 위한 페이지.
// 앱을 설치하지 않은 상태에서도 브라우저로 접근해 로그인 후 탈퇴를 요청할 수
// 있다.
//
// [최소 수정 원칙] 신규 API 엔드포인트를 만들지 않고, Flutter 앱이 이미 사용
// 중인 기존 공개 API(`/api/public/auth/login`, `/api/public/auth/withdraw`)를
// 그대로 재사용한다. 이 두 API는 이미 CORS 헤더(`Access-Control-Allow-Origin:
// *`)를 갖고 있어 별도 설정 없이 이 페이지(admin_web 자체 오리진)에서도
// 정상 호출된다.
"use client";

import { useState } from "react";

type Step = "login" | "confirm" | "done";

export default function AccountDeletionPage() {
  const [step, setStep] = useState<Step>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [reason, setReason] = useState("");
  const [token, setToken] = useState<string | null>(null);
  const [nickname, setNickname] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setPending(true);
    try {
      const res = await fetch("/api/public/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(json.error ?? "로그인에 실패했습니다.");
        return;
      }
      setToken(json.data.token);
      setNickname(json.data.user?.nickname ?? null);
      setStep("confirm");
    } catch {
      setError("네트워크 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");
    } finally {
      setPending(false);
    }
  }

  async function handleWithdraw() {
    if (!token) return;
    setError(null);
    setPending(true);
    try {
      const res = await fetch("/api/public/auth/withdraw", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ reason: reason.trim() || undefined }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(json.error ?? "탈퇴 처리에 실패했습니다.");
        return;
      }
      setStep("done");
    } catch {
      setError("네트워크 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="mx-auto min-h-screen max-w-md px-6 py-16">
      <header className="mb-8">
        <h1 className="text-xl font-bold text-slate-900">계정 삭제(회원탈퇴)</h1>
        <p className="mt-2 text-sm text-slate-500">
          신통방통(Fortune Fusion) 계정을 삭제하려면 먼저 로그인해 주세요.
        </p>
      </header>

      {step === "login" && (
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label htmlFor="email" className="mb-1 block text-sm font-medium text-slate-600">
              이메일
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 outline-none focus:border-indigo-500"
              placeholder="you@example.com"
            />
          </div>
          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium text-slate-600">
              비밀번호
            </label>
            <input
              id="password"
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 outline-none focus:border-indigo-500"
              placeholder="••••••••"
            />
          </div>

          {error && (
            <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{error}</p>
          )}

          <button
            type="submit"
            disabled={pending}
            className="w-full rounded-lg bg-slate-800 px-3 py-2 font-medium text-white transition hover:bg-slate-700 disabled:opacity-60"
          >
            {pending ? "확인 중..." : "로그인"}
          </button>
        </form>
      )}

      {step === "confirm" && (
        <div className="space-y-4">
          <div className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
            <p className="font-semibold">
              {nickname ?? "회원"}님, 계정을 삭제하면 다음과 같이 처리됩니다.
            </p>
            <ul className="mt-2 ml-4 list-disc space-y-1">
              <li>즉시 로그인 및 서비스 이용이 제한됩니다.</li>
              <li>
                탈퇴 요청일로부터 30일 후, 이메일/닉네임 등 개인식별정보가
                복구 불가능하게 비식별화되고 사주 프로필·AI 상담 이용기록
                등은 완전 삭제됩니다.
              </li>
              <li>
                단, 결제 관련 기록은 전자상거래법에 따라 5년간 별도 보존됩니다.
              </li>
              <li>이 작업은 취소할 수 없습니다.</li>
            </ul>
          </div>

          <div>
            <label htmlFor="reason" className="mb-1 block text-sm font-medium text-slate-600">
              탈퇴 사유 (선택)
            </label>
            <textarea
              id="reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={3}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 outline-none focus:border-indigo-500"
              placeholder="탈퇴 사유를 알려주시면 서비스 개선에 참고하겠습니다."
            />
          </div>

          {error && (
            <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{error}</p>
          )}

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setStep("login")}
              disabled={pending}
              className="flex-1 rounded-lg border border-slate-300 px-3 py-2 font-medium text-slate-700 transition hover:bg-slate-50 disabled:opacity-60"
            >
              취소
            </button>
            <button
              type="button"
              onClick={handleWithdraw}
              disabled={pending}
              className="flex-1 rounded-lg bg-red-600 px-3 py-2 font-medium text-white transition hover:bg-red-500 disabled:opacity-60"
            >
              {pending ? "처리 중..." : "계정 삭제 확정"}
            </button>
          </div>
        </div>
      )}

      {step === "done" && (
        <div className="rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-900">
          <p className="font-semibold">계정 삭제 요청이 완료되었습니다.</p>
          <p className="mt-1">
            그동안 신통방통을 이용해 주셔서 감사합니다. 문의사항이 있으시면{" "}
            <a href="mailto:parkjoosang35@gmail.com" className="underline">
              parkjoosang35@gmail.com
            </a>
            으로 연락해 주세요.
          </p>
        </div>
      )}

      <footer className="mt-10 border-t border-slate-200 pt-6 text-xs text-slate-400">
        <a href="/privacy-policy" className="underline hover:text-slate-600">
          개인정보처리방침
        </a>
        <span className="mx-2">·</span>
        <a href="/terms" className="underline hover:text-slate-600">
          이용약관
        </a>
      </footer>
    </div>
  );
}
