"use client";

import { useRouter } from "next/navigation";

export default function PartnerLogoutButton() {
  const router = useRouter();

  async function logout() {
    await fetch("/api/partner/bokju-coupons/logout", { method: "POST" });
    router.push("/partner/bokju-coupons/login");
    router.refresh();
  }

  return (
    <button onClick={logout} className="rounded border border-slate-300 px-3 py-1.5 text-sm text-slate-600 hover:bg-slate-100">
      로그아웃
    </button>
  );
}
