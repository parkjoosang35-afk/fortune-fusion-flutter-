"use client";

// [복주머니 마케팅 쿠폰 최종본] 캠페인 상세 — "발행 쿠폰 관리" + "이미지 생성 관리" +
// "쿠폰 배정 및 전달"을 한 화면에서 처리한다(§3 8개 메뉴 중 3개를 캠페인 단위로 통합).
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

interface Campaign {
  id: number;
  title: string;
  grantAmount: number;
  issueType: string;
  targetAudience: string;
  useLimitPerMember: number;
  sharedTotalLimit: number | null;
  distributionMethod: string;
  status: string;
  validFrom: string;
  validTo: string;
  guideText: string | null;
  issuedCount: number;
  allocatedCount: number;
  redeemedCount: number;
  usedCount: number;
}

interface ImageJob {
  id: number;
  status: string;
  totalCount: number;
  processedCount: number;
  failedCount: number;
  zipPath: string | null;
  excelPath: string | null;
}

interface Partner {
  id: number;
  name: string;
}

interface Allocation {
  allocationId: number;
  partnerId: number;
  partnerName: string;
  allocatedQty: number;
  deliveredAt: string | null;
  recalledQty: number;
  status: string;
  reportedQty: number;
  redeemedQty: number;
  redemptionRate: number;
}

const STATUS_LABEL: Record<string, string> = {
  DRAFT: "초안",
  ACTIVE: "진행중",
  PAUSED: "일시중지",
  CLOSED: "종료",
};

const ALLOWED_NEXT: Record<string, string[]> = {
  DRAFT: ["ACTIVE", "CLOSED"],
  ACTIVE: ["PAUSED", "CLOSED"],
  PAUSED: ["ACTIVE", "CLOSED"],
  CLOSED: [],
};

export default function BokjuCampaignDetailClient({
  campaign,
  statusCounts,
  latestImageJob,
  partners,
  allocations,
  recalledAvailable,
  canWrite,
}: {
  campaign: Campaign;
  statusCounts: Record<string, number>;
  latestImageJob: ImageJob | null;
  partners: Partner[];
  allocations: Allocation[];
  recalledAvailable: number;
  canWrite: boolean;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<string | null>(null);

  const [issueCount, setIssueCount] = useState(100);
  const [allocPartnerId, setAllocPartnerId] = useState<number | "">("");
  const [allocQty, setAllocQty] = useState(10);
  const [reassignPartnerId, setReassignPartnerId] = useState<number | "">("");
  const [reassignQty, setReassignQty] = useState(1);

  const [job, setJob] = useState<ImageJob | null>(latestImageJob);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (job && (job.status === "PENDING" || job.status === "RUNNING")) {
      pollRef.current = setInterval(async () => {
        const res = await fetch(`/api/admin/bokju-coupons/image-jobs/${job.id}`);
        const json = await res.json();
        if (json.success) {
          setJob(json.data);
          if (json.data.status !== "PENDING" && json.data.status !== "RUNNING") {
            if (pollRef.current) clearInterval(pollRef.current);
            router.refresh();
          }
        }
      }, 2500);
      return () => {
        if (pollRef.current) clearInterval(pollRef.current);
      };
    }
  }, [job, router]);

  async function handleStatusChange(nextStatus: string) {
    setPending("status");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}/status`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: nextStatus }),
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

  async function handleIssue() {
    setPending("issue");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}/issue`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ count: issueCount }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "쿠폰 발행 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleGenerateImages() {
    setPending("images");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}/generate-images`, {
        method: "POST",
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setJob({ id: json.data.jobId, status: "PENDING", totalCount: json.data.totalCount, processedCount: 0, failedCount: 0, zipPath: null, excelPath: null });
    } catch (e) {
      setError(e instanceof Error ? e.message : "이미지 생성 시작 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleRetryImages() {
    if (!job) return;
    setPending("retry");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/image-jobs/${job.id}/retry`, { method: "POST" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setJob({ ...job, status: "RUNNING" });
    } catch (e) {
      setError(e instanceof Error ? e.message : "재시도 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleAllocate() {
    if (!allocPartnerId) return setError("배정할 업체를 선택하세요.");
    setPending("allocate");
    setError(null);
    try {
      const res = await fetch("/api/admin/bokju-coupons/allocations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ campaignId: campaign.id, partnerId: allocPartnerId, qty: allocQty }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "배정 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleDeliver(allocationId: number) {
    setPending(`deliver-${allocationId}`);
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/allocations/${allocationId}/deliver`, { method: "POST" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "발송 처리 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleRecall(allocationId: number, confirm = false) {
    setPending(`recall-${allocationId}`);
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/allocations/${allocationId}/recall`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ confirm }),
      });
      const json = await res.json();
      if (res.status === 409 && json.confirmRequired) {
        if (window.confirm(`${json.error}\n\n그래도 회수를 강행하시겠습니까?`)) {
          await handleRecall(allocationId, true);
        }
        return;
      }
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "회수 처리 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleReassign() {
    if (!reassignPartnerId) return setError("재배정할 업체를 선택하세요.");
    setPending("reassign");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}/reassign`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ newPartnerId: reassignPartnerId, qty: reassignQty }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "재배정 실패");
    } finally {
      setPending(null);
    }
  }

  const unallocated = campaign.issuedCount - campaign.allocatedCount;

  return (
    <div className="space-y-6">
      {error && (
        <div className="rounded-lg border border-rose-300 bg-rose-50 px-4 py-2 text-sm text-rose-700">{error}</div>
      )}

      {/* 캠페인 기본 정보 + 상태 전이 */}
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold text-slate-900">{campaign.title}</h2>
          <span
            className={`rounded-full px-3 py-1 text-xs font-medium ${
              campaign.status === "ACTIVE"
                ? "bg-emerald-100 text-emerald-700"
                : campaign.status === "DRAFT"
                ? "bg-slate-100 text-slate-600"
                : campaign.status === "PAUSED"
                ? "bg-amber-100 text-amber-700"
                : "bg-rose-100 text-rose-700"
            }`}
          >
            {STATUS_LABEL[campaign.status] ?? campaign.status}
          </span>
        </div>
        <div className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
          <div>
            <p className="text-xs text-slate-500">지급 복주머니</p>
            <p className="font-semibold text-slate-900">{campaign.grantAmount}</p>
          </div>
          <div>
            <p className="text-xs text-slate-500">유형</p>
            <p className="font-semibold text-slate-900">{campaign.issueType === "SHARED" ? "공용번호" : "개별번호"}</p>
          </div>
          <div>
            <p className="text-xs text-slate-500">사용 대상</p>
            <p className="font-semibold text-slate-900">{campaign.targetAudience}</p>
          </div>
          <div>
            <p className="text-xs text-slate-500">사용기간</p>
            <p className="font-semibold text-slate-900">
              {campaign.validFrom.slice(0, 10)} ~ {campaign.validTo.slice(0, 10)}
            </p>
          </div>
        </div>
        {canWrite && (
          <div className="mt-4 flex gap-2">
            {(ALLOWED_NEXT[campaign.status] ?? []).map((next) => (
              <button
                key={next}
                onClick={() => handleStatusChange(next)}
                disabled={pending === "status"}
                className="rounded border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-100 disabled:opacity-50"
              >
                → {STATUS_LABEL[next] ?? next}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* 발행 현황 + 발행 쿠폰 관리 */}
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h3 className="mb-3 text-sm font-bold text-slate-900">발행 쿠폰 관리</h3>
        <div className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">발행</p>
            <p className="text-xl font-bold text-slate-900">{campaign.issuedCount}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">배정</p>
            <p className="text-xl font-bold text-slate-900">{campaign.allocatedCount}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">미배정</p>
            <p className="text-xl font-bold text-slate-900">{unallocated}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">등록(적립)</p>
            <p className="text-xl font-bold text-emerald-700">{campaign.redeemedCount}</p>
          </div>
        </div>
        {Object.keys(statusCounts).length > 0 && (
          <p className="mb-4 text-xs text-slate-500">
            상태별: {Object.entries(statusCounts).map(([s, c]) => `${s} ${c}장`).join(" · ")}
          </p>
        )}
        {canWrite && campaign.status === "ACTIVE" && (
          <div className="flex items-end gap-2">
            <div>
              <label className="mb-1 block text-xs text-slate-500">발행 수량</label>
              <input
                type="number"
                min={1}
                value={issueCount}
                onChange={(e) => setIssueCount(Number(e.target.value))}
                className="w-32 rounded border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <button
              onClick={handleIssue}
              disabled={pending === "issue"}
              className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending === "issue" ? "발행 중..." : "쿠폰 발행"}
            </button>
          </div>
        )}
        {campaign.status !== "ACTIVE" && (
          <p className="text-xs text-slate-500">쿠폰 발행은 캠페인이 &quot;진행중(ACTIVE)&quot; 상태일 때만 가능합니다.</p>
        )}
      </div>

      {/* 이미지 생성 관리 */}
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h3 className="mb-3 text-sm font-bold text-slate-900">이미지 생성 관리 (모바일 쿠폰 QR 이미지)</h3>
        {campaign.issuedCount === 0 ? (
          <p className="text-xs text-slate-500">먼저 쿠폰을 발행해야 이미지를 생성할 수 있습니다.</p>
        ) : (
          <>
            {canWrite && (!job || (job.status !== "PENDING" && job.status !== "RUNNING")) && (
              <button
                onClick={handleGenerateImages}
                disabled={pending === "images"}
                className="mb-3 rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
              >
                {pending === "images" ? "시작 중..." : "전체 쿠폰 이미지 일괄 생성"}
              </button>
            )}
            {job && (
              <div className="rounded-lg bg-slate-50 p-4">
                <div className="mb-2 flex items-center justify-between text-sm">
                  <span>
                    작업 상태: <strong>{job.status}</strong> ({job.processedCount}/{job.totalCount}
                    {job.failedCount > 0 ? `, 실패 ${job.failedCount}` : ""})
                  </span>
                </div>
                <div className="mb-3 h-2 w-full overflow-hidden rounded-full bg-slate-200">
                  <div
                    className="h-full bg-indigo-500 transition-all"
                    style={{ width: `${job.totalCount ? (job.processedCount / job.totalCount) * 100 : 0}%` }}
                  />
                </div>
                <div className="flex flex-wrap gap-2">
                  {job.zipPath && (
                    <a
                      href={job.zipPath}
                      download
                      className="rounded border border-slate-300 px-3 py-1.5 text-xs hover:bg-slate-100"
                    >
                      ZIP 다운로드(이미지 전체)
                    </a>
                  )}
                  {job.excelPath && (
                    <a
                      href={job.excelPath}
                      download
                      className="rounded border border-slate-300 px-3 py-1.5 text-xs hover:bg-slate-100"
                    >
                      엑셀 다운로드(쿠폰번호/링크 목록)
                    </a>
                  )}
                  {canWrite && job.failedCount > 0 && job.status !== "RUNNING" && (
                    <button
                      onClick={handleRetryImages}
                      disabled={pending === "retry"}
                      className="rounded border border-amber-300 bg-amber-50 px-3 py-1.5 text-xs text-amber-800 hover:bg-amber-100 disabled:opacity-50"
                    >
                      실패분만 재시도({job.failedCount}장)
                    </button>
                  )}
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* 쿠폰 배정 및 전달 */}
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h3 className="mb-3 text-sm font-bold text-slate-900">쿠폰 배정 및 전달</h3>
        {canWrite && campaign.distributionMethod === "PARTNER" && unallocated > 0 && (
          <div className="mb-4 flex items-end gap-2">
            <div>
              <label className="mb-1 block text-xs text-slate-500">업체 선택</label>
              <select
                value={allocPartnerId}
                onChange={(e) => setAllocPartnerId(e.target.value ? Number(e.target.value) : "")}
                className="w-48 rounded border border-slate-300 px-3 py-2 text-sm"
              >
                <option value="">선택...</option>
                {partners.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1 block text-xs text-slate-500">수량(미배정 {unallocated}장)</label>
              <input
                type="number"
                min={1}
                max={unallocated}
                value={allocQty}
                onChange={(e) => setAllocQty(Number(e.target.value))}
                className="w-28 rounded border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <button
              onClick={handleAllocate}
              disabled={pending === "allocate"}
              className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending === "allocate" ? "배정 중..." : "업체에 배정"}
            </button>
          </div>
        )}
        <div className="overflow-x-auto rounded-lg border border-slate-200">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 bg-slate-50 uppercase text-slate-500">
              <tr>
                <th className="px-3 py-2">업체</th>
                <th className="px-3 py-2">배정</th>
                <th className="px-3 py-2">발송</th>
                <th className="px-3 py-2">업체보고</th>
                <th className="px-3 py-2">시스템등록</th>
                <th className="px-3 py-2">전환율</th>
                <th className="px-3 py-2">상태</th>
                <th className="px-3 py-2">관리</th>
              </tr>
            </thead>
            <tbody>
              {allocations.length === 0 && (
                <tr>
                  <td colSpan={8} className="px-3 py-6 text-center text-slate-400">
                    배정 내역이 없습니다.
                  </td>
                </tr>
              )}
              {allocations.map((a) => (
                <tr key={a.allocationId} className="border-b border-slate-100">
                  <td className="px-3 py-2 font-medium text-slate-900">{a.partnerName}</td>
                  <td className="px-3 py-2">{a.allocatedQty}</td>
                  <td className="px-3 py-2">{a.deliveredAt ? "완료" : "미발송"}</td>
                  <td className="px-3 py-2">{a.reportedQty}</td>
                  <td className="px-3 py-2 font-semibold text-emerald-700">{a.redeemedQty}</td>
                  <td className="px-3 py-2">{a.redemptionRate}%</td>
                  <td className="px-3 py-2">{a.status}</td>
                  <td className="px-3 py-2">
                    {canWrite && !a.deliveredAt && (
                      <button
                        onClick={() => handleDeliver(a.allocationId)}
                        disabled={pending === `deliver-${a.allocationId}`}
                        className="mr-2 rounded border border-slate-300 px-2 py-1 hover:bg-slate-100 disabled:opacity-50"
                      >
                        발송완료
                      </button>
                    )}
                    {canWrite && a.status !== "RECALLED" && (
                      <button
                        onClick={() => handleRecall(a.allocationId)}
                        disabled={pending === `recall-${a.allocationId}`}
                        className="rounded border border-rose-300 px-2 py-1 text-rose-700 hover:bg-rose-50 disabled:opacity-50"
                      >
                        미등록 회수
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-400">
          * &quot;업체보고&quot;는 업체가 직접 제출한 수치이며, &quot;시스템등록&quot;은 실제 QR 등록(복주머니 적립) 완료 건수입니다. 두 수치는 절대 합산하지 않습니다.
        </p>
      </div>

      {/* 회수 쿠폰 재배정 (§9/§22.6) */}
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h3 className="mb-1 text-sm font-bold text-slate-900">회수 쿠폰 재배정</h3>
        <p className="mb-3 text-xs text-slate-500">
          재배정 가능 수량(회수됨 · 미사용 · 미배정): <strong className="text-rose-700">{recalledAvailable}장</strong>
        </p>
        {canWrite && recalledAvailable > 0 ? (
          <div className="flex items-end gap-2">
            <div>
              <label className="mb-1 block text-xs text-slate-500">재배정 업체 선택</label>
              <select
                value={reassignPartnerId}
                onChange={(e) => setReassignPartnerId(e.target.value ? Number(e.target.value) : "")}
                className="w-48 rounded border border-slate-300 px-3 py-2 text-sm"
              >
                <option value="">선택...</option>
                {partners.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1 block text-xs text-slate-500">수량(회수 가용 {recalledAvailable}장)</label>
              <input
                type="number"
                min={1}
                max={recalledAvailable}
                value={reassignQty}
                onChange={(e) => setReassignQty(Number(e.target.value))}
                className="w-28 rounded border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <button
              onClick={handleReassign}
              disabled={pending === "reassign"}
              className="rounded bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-500 disabled:opacity-50"
            >
              {pending === "reassign" ? "재배정 중..." : "선택 업체에 재배정"}
            </button>
          </div>
        ) : (
          <p className="text-xs text-slate-400">
            {recalledAvailable === 0
              ? "현재 재배정 가능한 회수 쿠폰이 없습니다."
              : "쓰기 권한이 없어 재배정할 수 없습니다."}
          </p>
        )}
        <p className="mt-2 text-xs text-slate-400">
          * 재배정 조건: 아직 사용되지 않았고(미등록) 다른 회원에게 유효하게 배정되지 않은 회수(RECALLED) 쿠폰만 허용됩니다. 재배정 시 새 배정 건이 생성되며, 기존 회수 이력의 실적과는 분리되어 집계됩니다.
        </p>
      </div>
    </div>
  );
}
