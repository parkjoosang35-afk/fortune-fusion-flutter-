"use client";

// [복주머니 마케팅 쿠폰 — 카카오톡 링크 공유 지시서 §5, 최우선순위 1]
// 캠페인 상세 화면 안에서 "쿠폰별 등록 링크"를 조회해 "링크 복사" /
// "카카오톡 공유"를 실제로 수행하는 섹션.
//
// [설계 원칙 — 사용자 명시 경고 준수] "단순히 URL만 생성하고 공유 기능이
// 완료됐다고 처리하면 안 된다"는 지시에 따라, 이 컴포넌트는 실제 카카오
// JavaScript SDK(Kakao.Share.sendDefault)를 로드·초기화하고, 초기화
// 실패(JS 키 미등록/도메인 미등록 등) 시 명확한 에러 메시지로 사용자에게
// 알린 뒤 "링크 복사"로만 폴백한다 — 성공한 것처럼 속이지 않는다.
//
// [카카오 JS 키 출처] Flutter 쪽 `social_auth_config.dart`에 이미 등록된
// 동일한 JS 키(`76a00e4de08a24efb9a944d81ad9f19f`, Kakao Developers App ID
// 1571801, 사이트 도메인 `https://sintong.kr` 등록됨)를 그대로 재사용한다
// — 새 앱을 만들지 않는다. 다만 이 JS 키는 Kakao Developers 콘솔에
// "사이트 도메인"으로 **현재 실제 접속 중인 origin**이 등록돼 있어야만
// `Kakao.Share.sendDefault()`가 성공한다. 운영 도메인(`sintong.kr`)에서는
// 이미 등록되어 있으나, 샌드박스 프리뷰 도메인(매번 바뀌는 *.sandbox.*)은
// 당연히 등록되어 있지 않으므로 샌드박스에서는 실패가 "정상"이다 — 이
// 컴포넌트는 그 실패를 숨기지 않고 화면에 그대로 보여준다.
import { useEffect, useRef, useState } from "react";

const KAKAO_JS_KEY = "76a00e4de08a24efb9a944d81ad9f19f";

interface CouponRow {
  id: number;
  couponNo: string;
  status: string;
  assignedUserId: number | null;
  redeemedAt: string | null;
  shareUrl: string;
}

// [쿠폰 삭제 기능] 이미 적립(REDEEMED) 완료된 쿠폰은 적립 원장과 연결된 금전적
// 사실 기록이므로 서버에서 삭제를 거부한다 — 프런트에서도 동일 규칙으로 미리
// 체크박스/버튼을 비활성화해 사용자가 요청을 보내기도 전에 이유를 알 수 있게 한다.
const UNDELETABLE_STATUSES = new Set(["REDEEMED"]);

declare global {
  interface Window {
    Kakao?: {
      isInitialized: () => boolean;
      init: (key: string) => void;
      Share: {
        sendDefault: (options: unknown) => void;
      };
    };
  }
}

type KakaoSdkState = "loading" | "ready" | "init_failed" | "unavailable";

const STATUS_LABEL: Record<string, string> = {
  CREATED: "생성됨",
  ISSUED: "발행됨(등록 가능)",
  ALLOCATED: "업체 배정됨",
  DELIVERED: "업체 전달됨",
  ASSIGNED: "회원 지정됨",
  REDEEMED: "등록 완료",
  EXPIRED: "기간 만료",
  REVOKED: "중지됨",
  RECALLED: "회수됨",
};

export default function BokjuCouponShareSection({
  campaignId,
  campaignTitle,
  grantAmount,
  validTo,
  canWrite = true,
}: {
  campaignId: number;
  campaignTitle: string;
  grantAmount: number;
  validTo: string;
  canWrite?: boolean;
}) {
  const [coupons, setCoupons] = useState<CouponRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [copiedId, setCopiedId] = useState<number | null>(null);
  const [kakaoState, setKakaoState] = useState<KakaoSdkState>("loading");
  const [kakaoError, setKakaoError] = useState<string | null>(null);
  const scriptLoadedRef = useRef(false);
  const PAGE_SIZE = 20;

  // [쿠폰 삭제 기능]
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  // ── 쿠폰 목록(+shareUrl) 로드 ──────────────────────────────────
  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch(
          `/api/admin/bokju-coupons/campaigns/${campaignId}/coupons?page=${page}&pageSize=${PAGE_SIZE}`
        );
        const json = await res.json();
        if (cancelled) return;
        if (!json.success) throw new Error(json.error);
        setCoupons(json.data.coupons);
        setTotal(json.data.total);
        setSelectedIds(new Set());
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : "쿠폰 목록 조회 실패");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [campaignId, page, reloadKey]);

  // ── 카카오 JS SDK 로드 + 초기화 (실제 동작 검증, 조용히 숨기지 않음) ──
  useEffect(() => {
    if (scriptLoadedRef.current) return;
    scriptLoadedRef.current = true;

    const existing = document.querySelector('script[data-kakao-sdk="bokju-coupon"]');
    if (existing) {
      tryInit();
      return;
    }

    const script = document.createElement("script");
    script.src = "https://t1.kakaocdn.net/kakao_js_sdk/2.7.4/kakao.min.js";
    script.async = true;
    script.dataset.kakaoSdk = "bokju-coupon";
    script.onload = tryInit;
    script.onerror = () => {
      setKakaoState("unavailable");
      setKakaoError("카카오 SDK 스크립트를 불러오지 못했습니다(네트워크 차단 가능성).");
    };
    document.head.appendChild(script);

    function tryInit() {
      try {
        if (!window.Kakao) throw new Error("window.Kakao가 로드되지 않았습니다.");
        if (!window.Kakao.isInitialized()) {
          window.Kakao.init(KAKAO_JS_KEY);
        }
        if (!window.Kakao.isInitialized()) {
          throw new Error("Kakao.init() 이후에도 초기화 상태가 아닙니다.");
        }
        setKakaoState("ready");
      } catch (e) {
        setKakaoState("init_failed");
        setKakaoError(e instanceof Error ? e.message : "카카오 SDK 초기화 실패");
      }
    }
  }, []);

  function toggleSelect(couponId: number) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(couponId)) next.delete(couponId);
      else next.add(couponId);
      return next;
    });
  }

  function toggleSelectAll() {
    const selectableIds = coupons.filter((c) => !UNDELETABLE_STATUSES.has(c.status)).map((c) => c.id);
    const allSelected = selectableIds.length > 0 && selectableIds.every((id) => selectedIds.has(id));
    setSelectedIds(allSelected ? new Set() : new Set(selectableIds));
  }

  async function handleDeleteOne(coupon: CouponRow) {
    if (!window.confirm(`쿠폰 "${coupon.couponNo}"을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.`)) return;
    setDeletingId(coupon.id);
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/coupons/${coupon.id}/delete`, { method: "POST" });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setReloadKey((k) => k + 1);
    } catch (e) {
      setError(e instanceof Error ? e.message : "쿠폰 삭제 실패");
    } finally {
      setDeletingId(null);
    }
  }

  async function handleBulkDelete() {
    if (selectedIds.size === 0) return;
    if (!window.confirm(`선택한 쿠폰 ${selectedIds.size}장을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.`)) return;
    setBulkDeleting(true);
    setError(null);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/coupons/bulk-delete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ couponIds: Array.from(selectedIds) }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      const { deletedCount, skipped } = json.data;
      if (skipped.length > 0) {
        setError(
          `${deletedCount}장 삭제 완료. ${skipped.length}장은 이미 적립 완료되어 삭제할 수 없어 건너뛰었습니다.`
        );
      }
      setReloadKey((k) => k + 1);
    } catch (e) {
      setError(e instanceof Error ? e.message : "일괄 삭제 실패");
    } finally {
      setBulkDeleting(false);
    }
  }

  async function handleCopy(coupon: CouponRow) {
    try {
      await navigator.clipboard.writeText(coupon.shareUrl);
      setCopiedId(coupon.id);
      setTimeout(() => setCopiedId((prev) => (prev === coupon.id ? null : prev)), 2000);
    } catch {
      setError("클립보드 복사에 실패했습니다. 브라우저 권한을 확인해 주세요.");
    }
  }

  function handleKakaoShare(coupon: CouponRow) {
    setError(null);
    if (kakaoState !== "ready" || !window.Kakao) {
      // [정직한 실패 처리 — 성공했다고 속이지 않는다]
      setError(
        kakaoState === "init_failed"
          ? `카카오 공유를 사용할 수 없습니다(${kakaoError ?? "SDK 초기화 실패"}). 이 도메인이 카카오 디벨로퍼스에 "사이트 도메인"으로 등록되어 있는지 확인해 주세요(샌드박스 프리뷰 주소는 보통 미등록 상태입니다 — 운영 도메인 sintong.kr에서는 정상 동작합니다). 대신 링크를 복사해 전달해 주세요.`
          : "카카오 SDK가 아직 준비되지 않았습니다. 잠시 후 다시 시도하거나 링크 복사를 이용해 주세요."
      );
      return;
    }
    try {
      window.Kakao.Share.sendDefault({
        objectType: "feed",
        content: {
          title: `${campaignTitle} — 복주머니 쿠폰 받기`,
          description: `지금 등록하면 복주머니 ${grantAmount.toLocaleString()}개를 바로 받아요! (사용기한 ${validTo.slice(0, 10)}까지)`,
          imageUrl: `${location.origin}/share-og/bokju-coupon.png`,
          link: {
            webUrl: coupon.shareUrl,
            mobileWebUrl: coupon.shareUrl,
          },
        },
        buttons: [
          {
            title: "쿠폰 등록하러 가기",
            link: { webUrl: coupon.shareUrl, mobileWebUrl: coupon.shareUrl },
          },
        ],
      });
    } catch (e) {
      setError(`카카오 공유 호출 중 오류가 발생했습니다: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5">
      <h3 className="mb-1 text-sm font-bold text-slate-900">쿠폰 링크 공유 (카카오톡)</h3>
      <p className="mb-3 text-xs text-slate-500">
        쿠폰별 등록 링크를 복사하거나 카카오톡으로 바로 공유할 수 있습니다. 링크를 클릭하면 쿠폰 정보 안내
        페이지가 열리고, &quot;쿠폰 등록하러 가기&quot;를 누르면 로그인 후 자동으로 등록 화면으로 돌아갑니다.
      </p>

      {kakaoState === "loading" && (
        <p className="mb-3 rounded bg-slate-50 px-3 py-2 text-xs text-slate-500">카카오 SDK 로딩 중...</p>
      )}
      {kakaoState === "ready" && (
        <p className="mb-3 rounded bg-emerald-50 px-3 py-2 text-xs text-emerald-700">
          ✓ 카카오 SDK 초기화 완료 — 이 도메인에서 카카오톡 공유를 사용할 수 있습니다.
        </p>
      )}
      {(kakaoState === "init_failed" || kakaoState === "unavailable") && (
        <p className="mb-3 rounded bg-amber-50 px-3 py-2 text-xs text-amber-800">
          ⚠ 카카오 공유를 사용할 수 없습니다({kakaoError}). 이 화면 주소({typeof window !== "undefined" ? location.host : ""})가
          카카오 디벨로퍼스 콘솔의 &quot;사이트 도메인&quot;에 등록되어 있는지 확인해 주세요. 운영 도메인
          (sintong.kr)에서는 정상 동작할 수 있습니다 — 지금은 &quot;링크 복사&quot;만 사용해 주세요.
        </p>
      )}

      {error && (
        <div className="mb-3 rounded border border-rose-300 bg-rose-50 px-3 py-2 text-xs text-rose-700">{error}</div>
      )}

      {canWrite && selectedIds.size > 0 && (
        <div className="mb-3 flex items-center justify-between rounded border border-rose-200 bg-rose-50 px-3 py-2">
          <span className="text-xs text-rose-700">{selectedIds.size}장 선택됨</span>
          <button
            onClick={handleBulkDelete}
            disabled={bulkDeleting}
            className="rounded bg-rose-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-rose-500 disabled:opacity-50"
          >
            {bulkDeleting ? "삭제 중..." : `선택 쿠폰 ${selectedIds.size}장 삭제`}
          </button>
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-slate-200">
        <table className="w-full text-left text-xs">
          <thead className="border-b border-slate-200 bg-slate-50 uppercase text-slate-500">
            <tr>
              {canWrite && (
                <th className="px-3 py-2">
                  <input
                    type="checkbox"
                    checked={
                      coupons.filter((c) => !UNDELETABLE_STATUSES.has(c.status)).length > 0 &&
                      coupons
                        .filter((c) => !UNDELETABLE_STATUSES.has(c.status))
                        .every((c) => selectedIds.has(c.id))
                    }
                    onChange={toggleSelectAll}
                  />
                </th>
              )}
              <th className="px-3 py-2">쿠폰번호</th>
              <th className="px-3 py-2">상태</th>
              <th className="px-3 py-2">등록 링크</th>
              <th className="px-3 py-2">공유</th>
              {canWrite && <th className="px-3 py-2">관리</th>}
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={canWrite ? 6 : 4} className="px-3 py-6 text-center text-slate-400">
                  불러오는 중...
                </td>
              </tr>
            )}
            {!loading && coupons.length === 0 && (
              <tr>
                <td colSpan={canWrite ? 6 : 4} className="px-3 py-6 text-center text-slate-400">
                  발행된 쿠폰이 없습니다.
                </td>
              </tr>
            )}
            {!loading &&
              coupons.map((c) => {
                const deletable = !UNDELETABLE_STATUSES.has(c.status);
                return (
                  <tr key={c.id} className="border-b border-slate-100">
                    {canWrite && (
                      <td className="px-3 py-2">
                        <input
                          type="checkbox"
                          checked={selectedIds.has(c.id)}
                          disabled={!deletable}
                          onChange={() => toggleSelect(c.id)}
                        />
                      </td>
                    )}
                    <td className="px-3 py-2 font-mono text-slate-900">{c.couponNo}</td>
                    <td className="px-3 py-2">{STATUS_LABEL[c.status] ?? c.status}</td>
                    <td className="max-w-[260px] truncate px-3 py-2 text-slate-500" title={c.shareUrl}>
                      {c.shareUrl}
                    </td>
                    <td className="px-3 py-2">
                      <div className="flex gap-1.5">
                        <button
                          onClick={() => handleCopy(c)}
                          className="rounded border border-slate-300 px-2 py-1 text-xs hover:bg-slate-100"
                        >
                          {copiedId === c.id ? "복사됨!" : "링크 복사"}
                        </button>
                        <button
                          onClick={() => handleKakaoShare(c)}
                          disabled={kakaoState === "loading"}
                          className="rounded bg-[#FEE500] px-2 py-1 text-xs font-medium text-[#3A1D1D] hover:brightness-95 disabled:opacity-50"
                        >
                          카카오톡 공유
                        </button>
                      </div>
                    </td>
                    {canWrite && (
                      <td className="px-3 py-2">
                        {deletable ? (
                          <button
                            onClick={() => handleDeleteOne(c)}
                            disabled={deletingId === c.id}
                            className="rounded border border-rose-300 px-2 py-1 text-xs text-rose-700 hover:bg-rose-50 disabled:opacity-50"
                          >
                            {deletingId === c.id ? "삭제 중..." : "삭제"}
                          </button>
                        ) : (
                          <span className="text-xs text-slate-400" title="이미 적립 완료된 쿠폰은 삭제할 수 없습니다.">
                            삭제 불가
                          </span>
                        )}
                      </td>
                    )}
                  </tr>
                );
              })}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="mt-3 flex items-center justify-center gap-2 text-xs">
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
            className="rounded border border-slate-300 px-2 py-1 disabled:opacity-40"
          >
            이전
          </button>
          <span className="text-slate-500">
            {page} / {totalPages} (총 {total}장)
          </span>
          <button
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page >= totalPages}
            className="rounded border border-slate-300 px-2 py-1 disabled:opacity-40"
          >
            다음
          </button>
        </div>
      )}
    </div>
  );
}
