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
  totalIssueLimit: number | null;
  distributionMethod: string;
  designTemplate: string;
  // [작업순서4 — §4-3 전환 버튼] null이면 아직 레거시(11토글) 화면을 쓴다.
  currentDesignRevisionId: number | null;
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

// [카카오톡 스타일 쿠폰 디자인 템플릿 4종] BokjuCampaignCreateForm.tsx의
// DESIGN_TEMPLATES와 동일한 라벨 — 생성 폼과 상세 화면 양쪽에서 같은 한글
// 이름으로 표시되도록 맞춘다.
const DESIGN_TEMPLATE_LABEL: Record<string, string> = {
  CLASSIC: "전통 복주머니",
  PREMIUM: "고급 선물",
  KAKAO: "카카오톡 스타일",
  MINIMAL: "미니멀",
};

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

  // [작업순서4 — 02e §4-3 기본안(d)] "신규 디자인으로 전환" 버튼.
  // 자동 전환이 아니라 이 버튼(관리자의 명시적 클릭)으로만 호출된다.
  // 성공하면 신규 에디터(/design)로 이동 — 이후 이 캠페인은 신규
  // 디자인 체계를 쓰며, 이 버튼은 다시 노출되지 않는다(가드는
  // studio-api.ts convertLegacyDesign()의 currentDesignRevisionId 체크
  // + 이 화면의 조건부 렌더링 두 겹).
  async function handleConvertToNewDesign() {
    if (
      !window.confirm(
        "신규 디자인으로 전환하면 현재 11토글 설정을 기반으로 레이아웃을 자동 생성하고, " +
          "이 캠페인은 앞으로 새 디자인 스튜디오를 사용하게 됩니다.\n\n" +
          "전환 전 상태는 리비전(rev1)으로 보존되어 언제든 되돌릴 수 있습니다.\n" +
          "참고: 장식(테두리·모서리 원)이 있던 설정이면, 전환 후 장식 색상이 테마 색상(@accent)으로 표시되어 기존 고정 색상(#d4a94a)과 미세하게 다르게 보일 수 있습니다.\n\n" +
          "계속하시겠습니까?"
      )
    ) {
      return;
    }
    setPending("convert-design");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}/design/convert-legacy`, {
        method: "POST",
      });
      const json = await res.json();
      if (!json.success) {
        const issueMsg = Array.isArray(json.issues) && json.issues.length > 0
          ? "\n\n" + json.issues.map((i: { message: string }) => `· ${i.message}`).join("\n")
          : "";
        throw new Error((json.error || "전환 실패") + issueMsg);
      }
      router.push(`/bokju-coupons/campaigns/${campaign.id}/design`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "신규 디자인 전환 실패");
    } finally {
      setPending(null);
    }
  }

  // [02i §필수2 — "(A) 전환 취소 경로"] "신규 디자인으로 전환"의 역방향.
  // currentDesignRevisionId 포인터를 다시 null로 되돌려 레거시(11토글)
  // 화면으로 복귀한다. 레거시 설정 데이터 자체는 전환 시 삭제되지 않고
  // 보존돼 있었으므로(studio-api.ts revertToLegacyDesign() 주석 참고),
  // 되돌리면 전환 전과 동일한 11토글 설정이 그대로 다시 보인다.
  // [안전성] 이미 발행된 쿠폰은 coupon.designRevisionId가 발행 시점에
  // 각인돼 있어(소급 변경 없음) 포인터를 되돌려도 영향받지 않는다 —
  // 아래 confirm 문구에 그대로 안내한다.
  async function handleRevertToLegacy() {
    if (
      !window.confirm(
        "신규 디자인 전환을 취소하고 레거시(11토글 설정) 화면으로 되돌립니다.\n\n" +
          "· 기존 11토글 설정은 삭제되지 않고 보존돼 있었으므로 전환 전과 동일하게 돌아갑니다.\n" +
          "· 이미 발행된 쿠폰은 발행 당시 디자인을 그대로 유지합니다(바뀌지 않습니다).\n" +
          "· 앞으로 새로 발행되는 쿠폰부터 레거시 11토글 설정을 받습니다.\n" +
          "· 참고: 전환 중에는 장식 색상이 테마 색상(@accent)으로 표시되어 레거시 고정 색상과 미세하게 달랐을 수 있습니다. 되돌리면 이 차이 없이 원래 색상 그대로 보입니다.\n\n" +
          "계속하시겠습니까?"
      )
    ) {
      return;
    }
    setPending("revert-design");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}/design/revert-to-legacy`, {
        method: "POST",
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error || "되돌리기 실패");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "레거시로 되돌리기 실패");
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

  async function handleDeleteCampaign() {
    if (
      !window.confirm(
        `캠페인 "${campaign.title}"을(를) 삭제하시겠습니까?\n\n발행된 쿠폰, 배정 내역이 모두 함께 삭제되며 되돌릴 수 없습니다.\n(이미 적립 완료된 쿠폰이 하나라도 있으면 삭제가 거부됩니다.)`
      )
    )
      return;
    setPending("delete-campaign");
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaign.id}`, { method: "DELETE" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.push("/bokju-coupons/campaigns");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "캠페인 삭제 실패");
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
  // [마케팅 쿠폰 발행 관리 개선 §4] 발급후미사용 ≠ 추가발급가능 — 명확히 구분.
  // 발급후미사용: 이미 발행(issuedCount)되었지만 아직 등록(redeemedCount)되지 않은 수량.
  // 추가발급가능: 총 발행 한도(totalIssueLimit)에서 이미 발행한 수량을 뺀 잔여 수량(무제한이면 표시 안 함).
  const unusedAfterIssue = Math.max(0, campaign.issuedCount - campaign.redeemedCount);
  const remainingIssuable = campaign.totalIssueLimit != null ? Math.max(0, campaign.totalIssueLimit - campaign.issuedCount) : null;

  return (
    <div className="space-y-6">
      {error && (
        <div className="rounded-lg border border-rose-300 bg-rose-50 px-4 py-2 text-sm text-rose-700">{error}</div>
      )}

      {/* [작업순서4 — §4-3] 레거시(11토글) 캠페인에만 노출되는 전환 버튼.
          이미 전환됐거나(currentDesignRevisionId 있음) 신규 캠페인이면
          이 블록 자체가 렌더링되지 않는다 — "버튼 1회" 원칙의 화면단 가드. */}
      {canWrite && campaign.currentDesignRevisionId == null && (
        <div className="rounded-xl border border-indigo-200 bg-indigo-50 p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm font-semibold text-indigo-900">
                이 캠페인은 아직 기존 디자인 방식(11개 표시 항목 토글)을 사용 중입니다.
              </p>
              <p className="mt-1 text-xs text-indigo-700">
                신규 디자인 스튜디오로 전환하면 현재 설정을 기반으로 자유롭게 배치를 편집할 수 있습니다.
                전환 전 디자인은 리비전으로 보존되어 언제든 되돌릴 수 있습니다.
              </p>
            </div>
            <button
              onClick={handleConvertToNewDesign}
              disabled={pending === "convert-design"}
              className="shrink-0 rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending === "convert-design" ? "전환 중..." : "신규 디자인으로 전환"}
            </button>
          </div>
        </div>
      )}

      {/* [작업순서4] 이미 신규 디자인으로 전환된(또는 신규 캠페인인) 경우
          스튜디오 바로가기 링크를 노출한다.
          [02i §필수2 — "(A) 전환 취소 경로"] 신규 캠페인(처음부터 신규
          에디터를 쓰는 캠페인)은 "되돌릴 레거시 설정" 자체가 없으므로,
          "레거시로 되돌리기" 버튼은 캠페인이 실제로 convert-legacy를 거쳐
          전환된 경우에만 의미가 있다 — 다만 이 컴포넌트는 "전환으로
          생성됐는지"와 "신규 캠페인으로 시작했는지"를 구분할 별도 플래그를
          받지 않으므로(두 경우 모두 currentDesignRevisionId != null), 신규
          캠페인에서 되돌리기를 눌러도 revertToLegacyDesign()은 단순히
          포인터를 null로 바꿀 뿐 데이터를 지우지 않아 안전하다 — 다만
          신규 캠페인엔 애초에 11토글 레거시 설정 화면 자체가 없을 수
          있으므로(생성 폼에서 customTemplateId 미지정 시 DEFAULT_VISIBILITY로
          간주), 되돌리면 "모든 항목이 켜진 기본 11토글 화면"으로 복귀한다 —
          이는 convertLegacyDesign()의 DEFAULT_VISIBILITY 폴백과 대칭이다. */}
      {campaign.currentDesignRevisionId != null && (
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <a
              href={`/bokju-coupons/campaigns/${campaign.id}/design`}
              className="text-sm font-medium text-indigo-600 hover:underline"
            >
              쿠폰 디자인 스튜디오 열기 →
            </a>
            {canWrite && (
              <button
                onClick={handleRevertToLegacy}
                disabled={pending === "revert-design"}
                className="shrink-0 rounded border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
                title="신규 디자인 전환을 취소하고 레거시(11토글 설정) 화면으로 되돌립니다. 이미 발행된 쿠폰은 영향받지 않습니다."
              >
                {pending === "revert-design" ? "되돌리는 중..." : "레거시로 되돌리기"}
              </button>
            )}
          </div>
        </div>
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
          <div>
            <p className="text-xs text-slate-500">쿠폰 디자인</p>
            <p className="font-semibold text-slate-900">
              {DESIGN_TEMPLATE_LABEL[campaign.designTemplate] ?? campaign.designTemplate}
            </p>
          </div>
        </div>
        {canWrite && (
          <div className="mt-4 flex items-center justify-between gap-2">
            <div className="flex gap-2">
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
            <button
              onClick={handleDeleteCampaign}
              disabled={pending === "delete-campaign"}
              title={campaign.redeemedCount > 0 ? "적립 완료된 쿠폰이 있으면 서버에서 삭제가 거부됩니다." : undefined}
              className="rounded border border-rose-300 px-3 py-1.5 text-sm text-rose-700 hover:bg-rose-50 disabled:opacity-50"
            >
              {pending === "delete-campaign" ? "삭제 중..." : "캠페인 삭제"}
            </button>
          </div>
        )}
      </div>

      {/* 발행 현황 + 발행 쿠폰 관리 */}
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h3 className="mb-3 text-sm font-bold text-slate-900">발행 쿠폰 관리</h3>
        {/* [마케팅 쿠폰 발행 관리 개선 §4] 총발행/발급완료/사용완료/발급후미사용/추가발급가능 5가지 수치 */}
        <div className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-5">
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">총 발행 한도</p>
            <p className="text-xl font-bold text-slate-900">
              {campaign.totalIssueLimit != null ? campaign.totalIssueLimit.toLocaleString() : "무제한"}
            </p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">발급 완료</p>
            <p className="text-xl font-bold text-slate-900">{campaign.issuedCount}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">사용 완료</p>
            <p className="text-xl font-bold text-emerald-700">{campaign.redeemedCount}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">발급 후 미사용</p>
            <p className="text-xl font-bold text-amber-700">{unusedAfterIssue}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">추가 발급 가능</p>
            <p className="text-xl font-bold text-indigo-700">
              {remainingIssuable != null ? remainingIssuable.toLocaleString() : "무제한"}
            </p>
          </div>
        </div>
        <div className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">배정</p>
            <p className="text-xl font-bold text-slate-900">{campaign.allocatedCount}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-500">미배정</p>
            <p className="text-xl font-bold text-slate-900">{unallocated}</p>
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
                  {/* [턴E — 02w §0-AA-4] 더 이상 job.zipPath(파일 경로)를 쓰지
                      않는다(턴D에서 그 값 자체를 DB에 저장하지 않도록 바꿈 —
                      스트리밍 전환). 생성된 이미지가 1건이라도 있으면(진행 중
                      작업이라도 지금까지 처리된 분량만) 그 자리에서 ZIP으로
                      묶어 내려주는 인증 스트리밍 라우트를 직접 가리킨다. */}
                  {job.processedCount > 0 && (
                    <a
                      href={`/api/admin/bokju-coupons/image-jobs/${job.id}/download`}
                      download
                      className="rounded border border-slate-300 px-3 py-1.5 text-xs hover:bg-slate-100"
                    >
                      ZIP 다운로드(이미지 전체)
                    </a>
                  )}
                  {/* [턴B — 02w §0-AA-2] 더 이상 job.excelPath(파일 경로)를 쓰지 않는다.
                      엑셀은 이미지 생성 여부와 무관하게 "발행된 쿠폰"만 있으면 항상
                      그 자리에서 스트리밍 생성 가능하므로, job 상태가 아니라 쿠폰
                      발행 여부(campaign.issuedCount)로 노출 조건을 바꾼다. */}
                  {campaign.issuedCount > 0 && (
                    <a
                      href={`/api/admin/bokju-coupons/campaigns/${campaign.id}/coupons-excel`}
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
