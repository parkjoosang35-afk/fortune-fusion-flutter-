"use client";

// [복주머니 마케팅 쿠폰] 업체 전용 — "내가 받은 쿠폰" 목록 + 확인/보고/다운로드.
import { useEffect, useState } from "react";

interface Allocation {
  allocationId: number;
  campaignId: number;
  title: string;
  allocatedQty: number;
  deliveredAt: string | null;
  acknowledgedAt: string | null;
  distributeDeadline: string | null;
  status: string;
  redeemedQty: number;
  reportedQty: number;
}

export default function PartnerAllocationsClient() {
  const [allocations, setAllocations] = useState<Allocation[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<number | null>(null);

  // 보고 폼 상태
  const [reportQty, setReportQty] = useState(1);
  const [reportDate, setReportDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [reportMethod, setReportMethod] = useState("DIRECT");
  const [reportNote, setReportNote] = useState("");

  async function load() {
    try {
      const res = await fetch("/api/partner/bokju-coupons/allocations");
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setAllocations(json.data.allocations);
    } catch (e) {
      setError(e instanceof Error ? e.message : "목록 조회 실패");
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function handleAcknowledge(allocationId: number) {
    setPending(`ack-${allocationId}`);
    setError(null);
    try {
      const res = await fetch(`/api/partner/bokju-coupons/allocations/${allocationId}/acknowledge`, { method: "POST" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "확인 처리 실패");
    } finally {
      setPending(null);
    }
  }

  async function handleReport(allocationId: number) {
    setPending(`report-${allocationId}`);
    setError(null);
    try {
      const res = await fetch(`/api/partner/bokju-coupons/allocations/${allocationId}/report`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ qty: reportQty, date: reportDate, method: reportMethod, note: reportNote || undefined }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setReportQty(1);
      setReportNote("");
      setExpanded(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "보고 실패");
    } finally {
      setPending(null);
    }
  }

  function handleDownload(allocationId: number) {
    window.open(`/api/partner/bokju-coupons/allocations/${allocationId}/download`, "_blank");
  }

  if (error && allocations === null) {
    return (
      <div className="rounded-lg border border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div>
    );
  }

  if (allocations === null) {
    return <p className="text-sm text-slate-500">불러오는 중...</p>;
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">내가 받은 쿠폰</h1>
      <p className="text-sm text-slate-500">
        신통방통 운영팀으로부터 배정받은 복주머니 쿠폰 현황입니다. 쿠폰을 받으면 &quot;배정 확인&quot;을
        눌러주시고, 실제 고객에게 배포한 수량을 주기적으로 보고해주세요.
      </p>

      {error && <div className="rounded-lg border border-rose-300 bg-rose-50 px-4 py-2 text-sm text-rose-700">{error}</div>}

      {allocations.length === 0 && (
        <div className="rounded-xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-500">
          아직 배정받은 쿠폰이 없습니다.
        </div>
      )}

      {allocations.map((a) => (
        <div key={a.allocationId} className="rounded-xl border border-slate-200 bg-white p-5">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-bold text-slate-900">{a.title}</h2>
            <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">{a.status}</span>
          </div>
          <div className="mb-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
            <div>
              <p className="text-xs text-slate-500">배정 수량</p>
              <p className="font-semibold text-slate-900">{a.allocatedQty}장</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">내가 보고한 수량</p>
              <p className="font-semibold text-slate-900">{a.reportedQty}장</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">실제 등록(적립) 확인</p>
              <p className="font-semibold text-emerald-700">{a.redeemedQty}장</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">배정 확인</p>
              <p className="font-semibold text-slate-900">{a.acknowledgedAt ? "완료" : "미확인"}</p>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            {!a.acknowledgedAt && (
              <button
                onClick={() => handleAcknowledge(a.allocationId)}
                disabled={pending === `ack-${a.allocationId}`}
                className="rounded bg-[#7a1f1f] px-3 py-1.5 text-xs font-medium text-white hover:bg-[#8a2525] disabled:opacity-50"
              >
                배정 확인(실물 수령)
              </button>
            )}
            <button
              onClick={() => handleDownload(a.allocationId)}
              className="rounded border border-slate-300 px-3 py-1.5 text-xs hover:bg-slate-100"
            >
              쿠폰 이미지 ZIP 다운로드
            </button>
            <button
              onClick={() => setExpanded(expanded === a.allocationId ? null : a.allocationId)}
              className="rounded border border-amber-300 bg-amber-50 px-3 py-1.5 text-xs text-amber-800 hover:bg-amber-100"
            >
              배포 수량 보고
            </button>
          </div>

          {expanded === a.allocationId && (
            <div className="mt-4 grid grid-cols-1 gap-3 rounded-lg bg-slate-50 p-4 sm:grid-cols-4">
              <div>
                <label className="mb-1 block text-xs text-slate-500">배포 수량</label>
                <input
                  type="number"
                  min={1}
                  value={reportQty}
                  onChange={(e) => setReportQty(Number(e.target.value))}
                  className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs text-slate-500">배포 일자</label>
                <input
                  type="date"
                  value={reportDate}
                  onChange={(e) => setReportDate(e.target.value)}
                  className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs text-slate-500">배포 방식</label>
                <select
                  value={reportMethod}
                  onChange={(e) => setReportMethod(e.target.value)}
                  className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm"
                >
                  <option value="DIRECT">직접 전달</option>
                  <option value="COUNTER">매장 비치</option>
                  <option value="ETC">기타</option>
                </select>
              </div>
              <div>
                <label className="mb-1 block text-xs text-slate-500">메모(선택)</label>
                <input
                  value={reportNote}
                  onChange={(e) => setReportNote(e.target.value)}
                  className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm"
                />
              </div>
              <div className="sm:col-span-4">
                <button
                  onClick={() => handleReport(a.allocationId)}
                  disabled={pending === `report-${a.allocationId}`}
                  className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
                >
                  {pending === `report-${a.allocationId}` ? "제출 중..." : "보고 제출"}
                </button>
              </div>
            </div>
          )}
        </div>
      ))}

      <p className="text-xs text-slate-400">
        * &quot;내가 보고한 수량&quot;은 업체가 직접 제출한 값이며, &quot;실제 등록 확인&quot;은 고객이 QR을
        스캔해 실제로 등록 완료한 건수입니다. 두 수치는 다를 수 있으며 정상입니다.
      </p>
    </div>
  );
}
