"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

interface Campaign {
  id: number;
  title: string;
  grantAmount: number;
  issueType: string;
  status: string;
  issuedCount: number;
  allocatedCount: number;
  redeemedCount: number;
  validFrom: string;
  validTo: string;
}

export default function BokjuCampaignRow({ campaign, canWrite = false }: { campaign: Campaign; canWrite?: boolean }) {
  const router = useRouter();
  const [deleting, setDeleting] = useState(false);
  const [rowError, setRowError] = useState<string | null>(null);

  async function handleDelete() {
    if (
      !window.confirm(
        `캠페인 "${campaign.title}"을(를) 삭제하시겠습니까?\n\n발행된 쿠폰, 배정 내역이 모두 함께 삭제되며 되돌릴 수 없습니다.\n(이미 적립 완료된 쿠폰이 하나라도 있으면 삭제가 거부됩니다.)`
      )
    )
      return;
    setDeleting(true);
    setRowError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}`, { method: "DELETE" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setRowError(e instanceof Error ? e.message : "삭제 실패");
      setDeleting(false);
    }
  }

  return (
    <tr className="border-b border-slate-100">
      <td className="px-4 py-3">
        <Link href={`/bokju-coupons/campaigns/${campaign.id}`} className="font-medium text-indigo-700 hover:underline">
          {campaign.title}
        </Link>
      </td>
      <td className="px-4 py-3">{campaign.grantAmount}</td>
      <td className="px-4 py-3">{campaign.issueType === "SHARED" ? "공용번호" : "개별번호"}</td>
      <td className="px-4 py-3">
        <span
          className={`rounded-full px-2 py-0.5 text-xs font-medium ${
            campaign.status === "ACTIVE"
              ? "bg-emerald-100 text-emerald-700"
              : campaign.status === "DRAFT"
              ? "bg-slate-100 text-slate-600"
              : campaign.status === "PAUSED"
              ? "bg-amber-100 text-amber-700"
              : "bg-rose-100 text-rose-700"
          }`}
        >
          {campaign.status}
        </span>
      </td>
      <td className="px-4 py-3">{campaign.issuedCount}</td>
      <td className="px-4 py-3">{campaign.allocatedCount}</td>
      <td className="px-4 py-3">{campaign.redeemedCount}</td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {campaign.validFrom.slice(0, 10)} ~ {campaign.validTo.slice(0, 10)}
      </td>
      {canWrite && (
        <td className="px-4 py-3">
          <button
            onClick={handleDelete}
            disabled={deleting}
            title={rowError ?? undefined}
            className="rounded border border-rose-300 px-2 py-1 text-xs text-rose-700 hover:bg-rose-50 disabled:opacity-50"
          >
            {deleting ? "삭제 중..." : rowError ? "실패(다시)" : "삭제"}
          </button>
        </td>
      )}
    </tr>
  );
}
