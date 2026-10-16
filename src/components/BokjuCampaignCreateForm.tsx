"use client";

// [복주머니 마케팅 쿠폰 최종본 §4] 쿠폰 만들기 — 13개 입력 라벨 중 서버 저장
// 대상 필드(디자인/미리보기/발행 버튼 제외 — 발행은 상세 화면에서 별도 수행)를
// 폼으로 구성한다. 성공 시 캠페인 상세로 이동.
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function BokjuCampaignCreateForm({ canWrite }: { canWrite: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [title, setTitle] = useState("");
  const [grantAmount, setGrantAmount] = useState(100);
  const [issueType, setIssueType] = useState<"INDIVIDUAL" | "SHARED">("INDIVIDUAL");
  const [targetAudience, setTargetAudience] = useState<"ALL" | "NEW" | "EXISTING">("ALL");
  const [useLimitPerMember, setUseLimitPerMember] = useState(1);
  const [sharedTotalLimit, setSharedTotalLimit] = useState(100);
  const [validFrom, setValidFrom] = useState("");
  const [validTo, setValidTo] = useState("");
  const [guideText, setGuideText] = useState("");
  const [distributionMethod, setDistributionMethod] = useState<"DIRECT" | "PARTNER" | "GIFT">("PARTNER");

  if (!canWrite) return null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return setError("쿠폰명을 입력해주세요.");
    if (!validFrom || !validTo) return setError("사용 시작일/만료일은 필수입니다.");
    setPending(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/bokju-coupons/campaigns", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: title.trim(),
          grantAmount,
          issueType,
          targetAudience,
          useLimitPerMember,
          sharedTotalLimit: issueType === "SHARED" ? sharedTotalLimit : undefined,
          validFrom,
          validTo,
          guideText: guideText.trim() || undefined,
          distributionMethod,
        }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.push(`/bokju-coupons/campaigns/${json.data.campaignId}`);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "캠페인 생성 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="mb-6">
      {!open ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="rounded-lg border border-indigo-300 bg-indigo-100 px-4 py-2 text-sm text-indigo-800 hover:bg-indigo-100"
        >
          + 새 쿠폰 캠페인 만들기
        </button>
      ) : (
        <form onSubmit={submit} className="grid grid-cols-1 gap-4 rounded-xl border border-slate-200 bg-white p-5 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="mb-1 block text-xs text-slate-500">1. 쿠폰명 *</label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="예: 신통방통 복주머니 선물"
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">3. 지급 복주머니 *</label>
            <input
              type="number"
              min={1}
              value={grantAmount}
              onChange={(e) => setGrantAmount(Number(e.target.value))}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">5. 쿠폰 유형</label>
            <select
              value={issueType}
              onChange={(e) => setIssueType(e.target.value as "INDIVIDUAL" | "SHARED")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            >
              <option value="INDIVIDUAL">개별번호</option>
              <option value="SHARED">공용번호</option>
            </select>
          </div>

          {issueType === "SHARED" && (
            <div>
              <label className="mb-1 block text-xs text-slate-500">공용 총 사용 한도 *</label>
              <input
                type="number"
                min={1}
                value={sharedTotalLimit}
                onChange={(e) => setSharedTotalLimit(Number(e.target.value))}
                className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
              />
            </div>
          )}

          <div>
            <label className="mb-1 block text-xs text-slate-500">6. 사용 대상</label>
            <select
              value={targetAudience}
              onChange={(e) => setTargetAudience(e.target.value as "ALL" | "NEW" | "EXISTING")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            >
              <option value="ALL">전체</option>
              <option value="NEW">신규 회원</option>
              <option value="EXISTING">기존 회원</option>
            </select>
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">9. 회원당 사용 제한</label>
            <input
              type="number"
              min={1}
              value={useLimitPerMember}
              onChange={(e) => setUseLimitPerMember(Number(e.target.value))}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">7. 사용 시작일 *</label>
            <input
              type="date"
              value={validFrom}
              onChange={(e) => setValidFrom(e.target.value)}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">8. 사용 만료일 *</label>
            <input
              type="date"
              value={validTo}
              onChange={(e) => setValidTo(e.target.value)}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">11. 배포 방식</label>
            <select
              value={distributionMethod}
              onChange={(e) => setDistributionMethod(e.target.value as "DIRECT" | "PARTNER" | "GIFT")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            >
              <option value="PARTNER">제휴업체 배정</option>
              <option value="DIRECT">직접 배포</option>
              <option value="GIFT">회원 선물</option>
            </select>
          </div>

          <div className="sm:col-span-2">
            <label className="mb-1 block text-xs text-slate-500">10. 쿠폰 안내 문구</label>
            <input
              value={guideText}
              onChange={(e) => setGuideText(e.target.value)}
              placeholder="QR코드를 찍고 복주머니를 받으세요!"
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div className="flex gap-2 sm:col-span-2">
            <button
              type="submit"
              disabled={pending}
              className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending ? "생성 중..." : "13. 쿠폰 캠페인 만들기(DRAFT)"}
            </button>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-500 hover:bg-slate-100"
            >
              취소
            </button>
          </div>
          {error && <p className="sm:col-span-2 text-xs text-rose-700">{error}</p>}
        </form>
      )}
    </div>
  );
}
