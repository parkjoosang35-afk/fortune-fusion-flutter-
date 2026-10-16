"use client";

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

export default function BokjuCampaignRow({ campaign }: { campaign: Campaign }) {
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
    </tr>
  );
}
