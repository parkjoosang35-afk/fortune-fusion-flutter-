"use client";

// [2026-10-22, 쿠폰 링크 미리보기 노출 수정 — 사용자 명시 지적]
// "카카오톡을 보냈는데 쿠폰이 보여야지, 이 사람들이 들어와서 무슨 내용인지
// 알아야 회원가입을 해서 쿠폰등록을 할 것 아니야" — `/w/[token]`(소원방
// 초대, 2026-11 "초대장 최종 정상화 지시서")과 `/g/[token]`(귀인지도,
// 2026-09 "콘텐츠가 먼저 보여야 한다" 원칙)이 겪었던 것과 동일한 문제를
// 동일한 방식으로 해결한다: 마운트 즉시 앱으로 튕기지 않고, 이 화면 자체가
// 쿠폰 내용(캠페인명/지급량/유효기간/안내문구)을 먼저 보여준다. "등록하러
// 가기" 버튼을 눌러야만 비로소 Flutter 앱으로 이동한다(앱은 이미
// BokjuCouponResolveScreen에서 로그인→자동 복귀→실제 등록까지 전부
// 구현되어 있으므로 그 흐름 자체는 건드리지 않는다 — 이 페이지는 "등록 전
// 내용 확인" 단계만 보강한다).
import { useEffect, useState } from "react";

type ViewState = "ok" | "not_found" | "error";

type CouponPreviewViewProps = {
  token: string;
  state: ViewState;
  campaignTitle?: string;
  grantAmount?: number;
  guideText?: string | null;
  validTo?: string;
};

type PreviewData = {
  campaignTitle: string;
  grantAmount: number;
  guideText: string | null;
  validTo: string;
  generalStatus: "available" | "redeemed" | "unavailable";
  statusMessage: string | null;
};

const SERIF = "'Noto Serif KR', serif";
const APP_COUPON_URL = (token: string) => `https://sintong.kr/app/#/coupon/${token}`;

function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
}

export function CouponPreviewView({
  token,
  state,
  campaignTitle,
  grantAmount,
  guideText,
  validTo,
}: CouponPreviewViewProps) {
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [loadError, setLoadError] = useState(false);

  // [핵심] 로그인 불필요한 공개 미리보기 API로 최신 상태(등록 완료/만료
  // 여부 등)까지 확인한다. 서버 컴포넌트가 이미 OG용으로 조회한 값을
  // 초기 화면에 먼저 그려두고(깜빡임 없이 즉시 표시), 이 fetch는 그 값을
  // "최신 상태"로 보강하는 역할만 한다.
  useEffect(() => {
    if (state !== "ok") return;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(
          `/api/public/bokju-coupons/preview?token=${encodeURIComponent(token)}`
        );
        const json = await res.json();
        if (cancelled) return;
        if (!res.ok || !json.success) {
          setLoadError(true);
          return;
        }
        setPreview(json.data as PreviewData);
      } catch {
        if (!cancelled) setLoadError(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [state, token]);

  if (state !== "ok") {
    return (
      <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
        <Brand />
        <div className="relative rounded-3xl border border-white/10 bg-white/[0.04] p-8 text-center shadow-[0_4px_20px_-8px_rgba(0,0,0,0.4)]">
          <span className="mb-3 block text-[34px]">🔒</span>
          <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#F2ECDF]">
            더 이상 열 수 없는 링크예요
          </h1>
          <p className="mb-2 text-sm leading-relaxed text-[#E8DCC8]/70">
            링크가 만료되었거나
            <br />
            쿠폰이 삭제되었을 수 있어요.
          </p>
        </div>
      </div>
    );
  }

  const displayTitle = preview?.campaignTitle || campaignTitle || "복주머니 쿠폰";
  const displayAmount = preview?.grantAmount ?? grantAmount ?? 0;
  const displayGuide = preview?.guideText ?? guideText ?? null;
  const displayValidTo = preview?.validTo ?? validTo ?? "";
  const generalStatus = preview?.generalStatus;
  const statusMessage = preview?.statusMessage;

  const isBlocked = generalStatus === "redeemed" || generalStatus === "unavailable";

  return (
    <>
      <section className="relative overflow-hidden">
        <div className="relative mx-auto w-full max-w-[440px] px-5 pt-6 pb-6">
          <Brand />

          <div className="mb-4 inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-[#F5CF6A]/25 bg-[#F5CF6A]/10 px-3 py-1.5">
            <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#F5CF6A]" />
            <span className="whitespace-nowrap text-[11px] font-semibold text-[#F5CF6A]">
              복주머니 쿠폰 도착
            </span>
          </div>

          <h1
            style={{ fontFamily: SERIF }}
            className="mb-3 text-[26px] font-bold leading-[1.35] tracking-tight text-[#F2ECDF]"
          >
            {displayTitle}
          </h1>

          {/* [쿠폰 내용 카드] 받은 사람이 로그인 없이도 "무엇을 받았는지"
              바로 확인할 수 있는 핵심 정보. */}
          <div className="mb-4 overflow-hidden rounded-3xl bg-[#17120F] shadow-[0_4px_20px_-8px_rgba(0,0,0,0.5)]">
            <div className="p-5">
              <div className="mb-3 flex items-center gap-2">
                <div
                  className="flex h-10 w-10 items-center justify-center rounded-xl text-[18px] font-black"
                  style={{ backgroundColor: "#F5CF6A", color: "#17120F", fontFamily: SERIF }}
                >
                  福
                </div>
                <div>
                  <p className="text-[15px] font-bold text-[#F5CF6A]">
                    복주머니 {displayAmount.toLocaleString()}개 지급
                  </p>
                  {displayValidTo && (
                    <p className="text-[11px] text-[#E8DCC8]/60">
                      사용 기한: {formatDate(displayValidTo)}까지
                    </p>
                  )}
                </div>
              </div>
              {displayGuide && (
                <p className="text-[13px] leading-relaxed text-[#E8DCC8]/80">{displayGuide}</p>
              )}
            </div>
          </div>

          {!preview && !loadError && (
            <p className="mb-4 text-center text-[12px] text-[#E8DCC8]/60">쿠폰 상태를 확인하는 중이에요...</p>
          )}

          {isBlocked && statusMessage && (
            <div className="mb-4 rounded-2xl border border-rose-400/25 bg-rose-400/10 px-4 py-3 text-center">
              <p className="text-[13px] font-semibold text-rose-200">{statusMessage}</p>
            </div>
          )}

          {/* [핵심 신설 — 사용자 지적 해결] 쿠폰 내용을 보고 난 뒤에야 등장하는
              CTA. 눌러야만 비로소 Flutter 앱(BokjuCouponResolveScreen)으로
              이동해 로그인→자동 등록 흐름이 시작된다. */}
          <a
            href={APP_COUPON_URL(token)}
            aria-disabled={isBlocked}
            className="mb-2 block w-full rounded-2xl py-3.5 text-center text-[15px] font-bold text-[#0E0A14]"
            style={{
              backgroundImage: isBlocked
                ? "none"
                : "linear-gradient(90deg, #F5CF6A, #E8B45C)",
              backgroundColor: isBlocked ? "#3a3530" : undefined,
              color: isBlocked ? "rgba(242,236,223,0.4)" : "#0E0A14",
              pointerEvents: isBlocked ? "none" : "auto",
            }}
          >
            {isBlocked ? "지금은 등록할 수 없어요" : "로그인하고 쿠폰 등록하러 가기"}
          </a>
          <p className="text-center text-[11px] text-[#E8DCC8]/50">
            신통방통 회원이 아니라면 다음 화면에서 바로 가입할 수 있어요.
          </p>
        </div>
      </section>

      <footer className="mx-auto w-full max-w-[440px] border-t border-white/10 px-5 pt-5 pb-2 text-center">
        <p className="text-[10px] text-[#E8DCC8]/50">© 2026 Sintongbangtong. All rights reserved.</p>
      </footer>
    </>
  );
}

function Brand() {
  return (
    <div className="mb-5 flex items-center gap-1.5">
      <span
        className="flex h-6 w-6 items-center justify-center rounded-full"
        style={{ backgroundImage: "linear-gradient(135deg, #E2A88A, #A6795E)" }}
      >
        <span className="text-[10px] font-bold leading-none text-white">신</span>
      </span>
      <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#F2ECDF]">
        신통방통
      </span>
    </div>
  );
}
