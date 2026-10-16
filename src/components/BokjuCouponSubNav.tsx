"use client";

// [복주머니 마케팅 쿠폰 최종본 §3] 관리자 하위 메뉴 탭.
// 8개 기획 메뉴 중 이미지생성/배정전달은 캠페인 상세에 통합했고, 나머지는
// 각각 독립 탭으로 노출한다.
import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/bokju-coupons/campaigns", label: "쿠폰 만들기 / 발행 관리" },
  { href: "/bokju-coupons/design-templates", label: "AI 쿠폰 디자인" },
  { href: "/bokju-coupons/partners", label: "제휴업체 관리" },
  { href: "/bokju-coupons/push", label: "회원 푸시 발송" },
  { href: "/bokju-coupons/usage", label: "쿠폰 사용 내역" },
  { href: "/bokju-coupons/stats", label: "쿠폰 통계" },
  { href: "/bokju-coupons/audit-logs", label: "감사 로그" },
];

export default function BokjuCouponSubNav() {
  const pathname = usePathname();
  return (
    <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-200">
      {TABS.map((tab) => {
        const active = pathname === tab.href || pathname.startsWith(tab.href + "/");
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={`rounded-t-lg px-4 py-2 text-sm font-medium transition ${
              active ? "border-b-2 border-indigo-500 text-slate-900" : "text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
