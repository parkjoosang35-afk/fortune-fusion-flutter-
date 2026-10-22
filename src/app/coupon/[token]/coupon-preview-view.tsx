"use client";

// [2026-10-22, "Midnight Temple(심야의 신전)" 디자인 핸드오프 적용 — 사용자
// 지시] 사용자가 전달한 디자인 레퍼런스(`복주머니 모바일 쿠폰.html` +
// `colors_and_type.css`, zip: design_handoff_pouch_coupon)를 픽셀 단위로
// 재구현한다: 회전하는 Sigil(마법진) SVG, 천공(perforation) 구분선,
// 캔들 글로우 카드, 별빛 배경을 가진 실제 "티켓" 디자인으로 기존의 단순
// 카드 UI를 전면 교체한다.
//
// [사용자 지시 원문] "쿠폰번호도 보낸 쿠폰번호 사실적으로 보내고 쿠폰
// 숫자도 보낸 이미지에 니가 알아서 개발해줘" — 디자인 레퍼런스의 가짜
// QR 패턴과 "SAMPLE-0000-0000" 플레이스홀더는 반드시 실데이터로
// 교체해야 한다는 README의 명시적 경고와 정확히 일치한다:
//   1) QR — `qrcode` 라이브러리(이미 설치됨, BokjuCouponDesignStudio.tsx가
//      동일하게 클라이언트에서 QRCode.toDataURL을 쓰는 선례를 그대로
//      따른다)로 실제 쿠폰 등록 URL을 인코딩한 진짜 QR을 런타임 생성한다.
//      값은 `src/lib/bokju-coupon-design/renderer.ts`의 qrPayload()와 동일한
//      관례(`{baseUrl}/coupon/{redeemToken}` — 이 페이지 자신의 URL)를
//      따라 생성 시스템 전체와 일관되게 유지한다.
//   2) 시리얼 번호 — 디자인의 "SAMPLE-0000-0000" 대신 공개 미리보기 API가
//      반환하는 실제 `coupon.couponNo`(예: "ST-86GD-ZS9X-A")를 그대로
//      표시한다.
//   3) 금액/유효기한 — 레퍼런스 HTML은 "1,000"/"2026 · 12 · 31"을 하드코딩
//      했지만 실제로는 캠페인마다 다르므로 grantAmount/validTo 실데이터로
//      바인딩한다. README의 state 예시(`type: '운세 · 사주 이용권'`)가
//      캠페인마다 달라질 수 있는 바인딩 필드임을 시사하므로, 티켓 타입
//      칩 텍스트는 campaignTitle로 바인딩한다.
// 그 외 브랜드명("신통방통")·단위("복주머니")·도장("福")·메타 라벨
// ("SINTONG · COUPON N°01")·레이아웃·색상·폰트·애니메이션은 레퍼런스와
// 동일하게 유지한다(순수 디자인 장식 요소 — README가 실데이터 교체를
// 요구한 두 항목에 해당하지 않음).
//
// [로그인 강제 전 콘텐츠 선노출 원칙 — 2026-10-22 선행 수정] 은 그대로
// 유지한다: 이 컴포넌트는 로그인 여부와 무관하게 쿠폰 내용을 먼저
// 보여주고, "등록하러 가기" CTA를 눌러야만 비로소 Flutter 앱으로 이동한다.
import { useEffect, useState } from "react";
import QRCode from "qrcode"; // 번들러가 package.json의 "browser" 필드로 lib/browser.js로 자동 치환

type ViewState = "ok" | "not_found" | "error";

type CouponPreviewViewProps = {
  token: string;
  state: ViewState;
  campaignTitle?: string;
  grantAmount?: number;
  guideText?: string | null;
  validTo?: string;
  couponNo?: string;
};

type PreviewData = {
  campaignTitle: string;
  grantAmount: number;
  guideText: string | null;
  validTo: string;
  generalStatus: "available" | "redeemed" | "unavailable";
  statusMessage: string | null;
  couponNo: string;
};

// ── Midnight Temple 팔레트 (colors_and_type.css :root 그대로) ──────────────
const C = {
  bg1: "#1a0d2e",
  bg2: "#0a0716",
  fg: "#f8f2e6",
  muted: "rgba(232, 220, 200, 0.62)",
  mutedFaint: "rgba(232, 220, 200, 0.38)",
  glow: "#f5cf6a",
  glowShadow: "rgba(245, 207, 106, 0.35)",
  accent: "#c94a3b",
  line: "rgba(255, 235, 200, 0.12)",
};

const FONT_DISPLAY = "'Noto Serif KR', 'Nanum Myeongjo', serif";
const FONT_BODY = "'Gowun Batang', 'Noto Serif KR', serif";
const FONT_UI = "'Pretendard Variable', Pretendard, -apple-system, system-ui, sans-serif";
const FONT_MONO = "'IBM Plex Mono', 'JetBrains Mono', monospace";

const SINTONG_COUPON_URL = (token: string) => `https://sintong.kr/coupon/${token}`;
const APP_COUPON_URL = (token: string) => `https://sintong.kr/app/#/coupon/${token}`;

function formatDateDots(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getFullYear()} · ${String(d.getMonth() + 1).padStart(2, "0")} · ${String(d.getDate()).padStart(2, "0")}`;
}

// ── 배경: 별 + 보라/적색 라디얼 글로우 (레퍼런스 .screen/.stars 그대로) ────
function PageBackground() {
  const starDots = [
    "radial-gradient(1px 1px at 12% 18%, rgba(255,255,255,.7), transparent)",
    "radial-gradient(1px 1px at 78% 9%, rgba(255,255,255,.5), transparent)",
    "radial-gradient(1.5px 1.5px at 64% 30%, rgba(255,255,255,.6), transparent)",
    "radial-gradient(1px 1px at 30% 52%, rgba(255,255,255,.4), transparent)",
    "radial-gradient(1px 1px at 88% 60%, rgba(255,255,255,.5), transparent)",
    "radial-gradient(1px 1px at 8% 78%, rgba(255,255,255,.4), transparent)",
    "radial-gradient(1.5px 1.5px at 50% 92%, rgba(255,255,255,.5), transparent)",
    "radial-gradient(1px 1px at 40% 6%, rgba(255,255,255,.6), transparent)",
  ].join(", ");
  return (
    <div
      aria-hidden
      className="fixed inset-0 -z-10"
      style={{
        background: `
          radial-gradient(ellipse 80% 50% at 15% 10%, rgba(120,80,200,0.28), transparent 70%),
          radial-gradient(ellipse 70% 50% at 90% 85%, rgba(201,74,59,0.16), transparent 70%),
          linear-gradient(180deg, ${C.bg1}, ${C.bg2})
        `,
      }}
    >
      <div aria-hidden className="absolute inset-0" style={{ backgroundImage: starDots }} />
    </div>
  );
}

// ── Sigil(마법진) 회전 배경 SVG — 레퍼런스 JS 생성 로직을 그대로 포팅 ──────
function SigilSvg() {
  const color = "#f5cf6a";
  const o = 0.35;
  const ticks = Array.from({ length: 36 }, (_, i) => {
    const a = (i / 36) * Math.PI * 2;
    return (
      <line
        key={`tick-${i}`}
        x1={Math.cos(a) * 86}
        y1={Math.sin(a) * 86}
        x2={Math.cos(a) * 90}
        y2={Math.sin(a) * 90}
        stroke={color}
        strokeOpacity={o * 0.8}
        strokeWidth={0.5}
      />
    );
  });
  const runes = ["✧", "✦", "☾", "❋", "◈", "✵", "❈", "✺", "✶", "☆", "◇", "⟡"];
  const runeEls = runes.map((r, i) => {
    const a = (i / 12) * Math.PI * 2 - Math.PI / 2;
    return (
      <text
        key={`rune-${i}`}
        x={Math.cos(a) * 78}
        y={Math.sin(a) * 78}
        fill={color}
        fillOpacity={o}
        fontSize={6}
        textAnchor="middle"
        dominantBaseline="middle"
        fontFamily="serif"
      >
        {r}
      </text>
    );
  });
  return (
    <svg
      viewBox="-100 -100 200 200"
      aria-hidden
      className="pointer-events-none absolute left-1/2 top-1/2"
      style={{
        width: 300,
        height: 300,
        transform: "translate(-50%, -50%)",
        opacity: 0.55,
        animation: "sintong-sigil-spin 120s linear infinite",
      }}
    >
      <circle r={90} fill="none" stroke={color} strokeOpacity={o} strokeWidth={0.6} />
      <circle r={86} fill="none" stroke={color} strokeOpacity={o * 0.5} strokeWidth={0.4} />
      {ticks}
      {runeEls}
      <circle r={60} fill="none" stroke={color} strokeOpacity={o * 0.6} strokeWidth={0.5} />
      <polygon
        points="0,-52 45,-26 45,26 0,52 -45,26 -45,-26"
        fill="none"
        stroke={color}
        strokeOpacity={o * 0.8}
        strokeWidth={0.6}
      />
      <polygon points="0,52 -45,-26 45,-26" fill="none" stroke={color} strokeOpacity={o * 0.5} strokeWidth={0.5} />
      <polygon points="0,-52 -45,26 45,26" fill="none" stroke={color} strokeOpacity={o * 0.5} strokeWidth={0.5} />
    </svg>
  );
}

export function CouponPreviewView({
  token,
  state,
  campaignTitle,
  grantAmount,
  guideText,
  validTo,
  couponNo,
}: CouponPreviewViewProps) {
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [qrDataUri, setQrDataUri] = useState<string | null>(null);

  // [핵심] 로그인 불필요한 공개 미리보기 API로 최신 상태(등록 완료/만료
  // 여부·실제 couponNo)까지 확인한다. 서버 컴포넌트가 이미 OG용으로 조회한
  // 값을 초기 화면에 먼저 그려두고(깜빡임 없이 즉시 표시), 이 fetch는 그
  // 값을 "최신 상태"로 보강하는 역할만 한다.
  useEffect(() => {
    if (state !== "ok") return;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(`/api/public/bokju-coupons/preview?token=${encodeURIComponent(token)}`);
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

  // [실제 QR 생성 — 디자인의 가짜 패턴을 대체] 레퍼런스 HTML의 placeholder
  // QR(의사난수로 그린 장식용 패턴)을 실제 쿠폰 등록 URL을 인코딩하는 진짜
  // QR PNG로 교체한다. `src/lib/bokju-coupon-design/renderer.ts`의
  // qrPayload() 관례(`{baseUrl}/coupon/{redeemToken}`)와 동일한 값을 써서
  // 쿠폰 이미지·OG 이미지·이 랜딩페이지 QR이 모두 같은 URL을 가리키도록
  // 맞춘다. 토큰이 바뀌지 않는 한 재생성하지 않는다(의도적으로 token만
  // 의존성에 넣는다).
  useEffect(() => {
    if (state !== "ok") return;
    let alive = true;
    QRCode.toDataURL(SINTONG_COUPON_URL(token), {
      type: "image/png",
      margin: 1,
      width: 480,
      errorCorrectionLevel: "M",
      color: { dark: "#1a0d2e", light: "#f8f2e6" },
    })
      .then((uri) => {
        if (alive) setQrDataUri(uri);
      })
      .catch(() => {
        if (alive) setQrDataUri(null);
      });
    return () => {
      alive = false;
    };
  }, [state, token]);

  // ── 전역 keyframes(회전/펄스) + prefers-reduced-motion 처리 ──────────────
  const GlobalKeyframes = (
    <style>{`
      @keyframes sintong-sigil-spin { to { transform: translate(-50%, -50%) rotate(360deg); } }
      @keyframes sintong-chip-pulse { 0%, 100% { opacity: 1; } 50% { opacity: .35; } }
      @media (prefers-reduced-motion: reduce) {
        .sintong-sigil-spin-wrap svg { animation: none !important; }
        .sintong-chip-dot { animation: none !important; }
      }
    `}</style>
  );

  if (state !== "ok") {
    return (
      <div className="relative min-h-screen">
        {GlobalKeyframes}
        <PageBackground />
        <div className="relative mx-auto w-full max-w-[430px] px-5 py-10">
          <Brand />
          <div
            className="relative mt-6 rounded-3xl p-8 text-center"
            style={{ border: `1px solid ${C.line}`, background: "rgba(255,235,200,0.04)" }}
          >
            <span className="mb-3 block text-[34px]">🔒</span>
            <h1 style={{ fontFamily: FONT_DISPLAY, color: C.fg }} className="mb-4 text-xl font-bold">
              더 이상 열 수 없는 링크예요
            </h1>
            <p style={{ color: C.muted, fontFamily: FONT_UI }} className="mb-2 text-sm leading-relaxed">
              링크가 만료되었거나
              <br />
              쿠폰이 삭제되었을 수 있어요.
            </p>
          </div>
        </div>
      </div>
    );
  }

  const displayTitle = preview?.campaignTitle || campaignTitle || "복주머니 쿠폰";
  const displayAmount = preview?.grantAmount ?? grantAmount ?? 0;
  const displayGuide = preview?.guideText ?? guideText ?? null;
  const displayValidTo = preview?.validTo ?? validTo ?? "";
  const displayCouponNo = preview?.couponNo ?? couponNo ?? "";
  const generalStatus = preview?.generalStatus;
  const statusMessage = preview?.statusMessage;

  const isBlocked = generalStatus === "redeemed" || generalStatus === "unavailable";

  return (
    <div className="relative min-h-screen">
      {GlobalKeyframes}
      <PageBackground />

      <div className="relative mx-auto w-full max-w-[430px] px-5 pb-10 pt-8" style={{ fontFamily: FONT_UI }}>
        {/* ── 헤더 ── */}
        <div className="flex items-center justify-between">
          <Brand />
          <div
            className="inline-flex items-center gap-[7px] whitespace-nowrap rounded-full px-3 py-[6px]"
            style={{ border: "1px solid rgba(245,207,106,.35)", background: "rgba(245,207,106,.08)" }}
          >
            <span
              className="sintong-chip-dot h-[6px] w-[6px] shrink-0 rounded-full"
              style={{
                backgroundColor: C.glow,
                boxShadow: `0 0 8px ${C.glow}`,
                animation: "sintong-chip-pulse 2.4s ease-in-out infinite",
              }}
            />
            <span className="whitespace-nowrap text-[12px] font-semibold" style={{ color: C.glow }}>
              복주머니 쿠폰 도착
            </span>
          </div>
        </div>

        {/* ── 티켓 카드 ── */}
        <div
          className="relative mt-4 overflow-hidden rounded-[22px]"
          style={{
            background: "linear-gradient(180deg, rgba(255,235,200,.075), rgba(255,235,200,.035))",
            border: `1px solid ${C.line}`,
          }}
        >
          <div
            aria-hidden
            className="pointer-events-none absolute left-1/2 top-[-60px] -translate-x-1/2 rounded-full"
            style={{
              width: 320,
              height: 180,
              background: `radial-gradient(ellipse, ${C.glowShadow}, transparent 70%)`,
              opacity: 0.7,
            }}
          />

          {/* 상단: Sigil + 쿠폰 정보 */}
          <div className="relative px-[22px] pb-[18px] pt-[18px] text-center">
            <div className="sintong-sigil-spin-wrap">
              <SigilSvg />
            </div>

            <div
              className="relative"
              style={{
                fontFamily: FONT_MONO,
                fontSize: 10,
                fontWeight: 500,
                letterSpacing: "0.32em",
                textTransform: "uppercase",
                color: C.muted,
              }}
            >
              Sintong · Coupon N°01
            </div>
            <div
              className="relative mt-[10px]"
              style={{ fontFamily: FONT_BODY, fontWeight: 700, fontSize: 16, color: C.fg }}
            >
              신통방통
            </div>
            <div
              className="relative mt-2 inline-block rounded-full px-[14px] py-[5px]"
              style={{
                border: "1px solid rgba(245,207,106,.4)",
                background: "rgba(10,7,22,.55)",
                fontFamily: FONT_BODY,
                fontWeight: 700,
                fontSize: 14,
                color: C.glow,
                letterSpacing: "0.02em",
              }}
            >
              {displayTitle}
            </div>
            <div
              className="relative mt-[10px]"
              style={{
                fontFamily: FONT_DISPLAY,
                fontWeight: 900,
                fontSize: 68,
                lineHeight: 1,
                letterSpacing: "-0.03em",
                color: C.glow,
                textShadow: `0 0 30px ${C.glowShadow}`,
              }}
            >
              {displayAmount.toLocaleString()}
            </div>
            <div
              className="relative mt-[10px] inline-flex items-center gap-2"
              style={{ fontFamily: FONT_BODY, fontWeight: 700, fontSize: 17, color: C.fg }}
            >
              <span
                className="inline-flex h-[26px] w-[26px] items-center justify-center rounded-[6px]"
                style={{
                  backgroundColor: C.accent,
                  fontFamily: FONT_DISPLAY,
                  fontWeight: 900,
                  fontSize: 14,
                  color: "#fff9e8",
                  transform: "rotate(-6deg)",
                  boxShadow: "0 2px 8px rgba(201,74,59,.55), inset 0 0 4px rgba(0,0,0,.2)",
                }}
              >
                福
              </span>
              복주머니
            </div>
            {displayValidTo && (
              <div className="relative mt-3 text-[12px]" style={{ color: C.muted }}>
                사용 기한&nbsp;
                <b style={{ fontFamily: FONT_MONO, fontWeight: 500, color: C.fg, letterSpacing: "0.08em" }}>
                  {formatDateDots(displayValidTo)}
                </b>
                &nbsp;까지
              </div>
            )}
          </div>

          {/* 천공(perforation) 구분선 */}
          <div className="relative h-[22px]">
            <div
              className="absolute left-[18px] right-[18px] top-1/2"
              style={{ borderTop: "1.5px dashed rgba(255,235,200,.2)" }}
            />
            <span
              className="absolute left-[-12px] top-0 h-[22px] w-[22px] rounded-full"
              style={{ backgroundColor: "#120c22", border: `1px solid ${C.line}` }}
            />
            <span
              className="absolute right-[-12px] top-0 h-[22px] w-[22px] rounded-full"
              style={{ backgroundColor: "#120c22", border: `1px solid ${C.line}` }}
            />
          </div>

          {/* 하단: 실제 QR + 실제 시리얼 번호 */}
          <div className="px-[22px] pb-5 pt-4 text-center">
            <div
              className="mx-auto flex h-[156px] w-[156px] items-center justify-center rounded-2xl p-3"
              style={{
                backgroundColor: "#f8f2e6",
                boxShadow: "0 0 0 4px rgba(245,207,106,.12), 0 4px 24px rgba(245,207,106,.18)",
              }}
            >
              {qrDataUri ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={qrDataUri}
                  alt="쿠폰 등록 QR 코드"
                  width={132}
                  height={132}
                  className="block h-full w-full"
                  style={{ imageRendering: "pixelated" }}
                />
              ) : (
                <div className="h-full w-full animate-pulse rounded-lg" style={{ backgroundColor: "#e7ddc6" }} />
              )}
            </div>
            {displayCouponNo && (
              <div
                className="mt-[14px]"
                style={{ fontFamily: FONT_MONO, fontSize: 14, fontWeight: 500, letterSpacing: "0.18em", color: C.fg }}
              >
                {displayCouponNo}
              </div>
            )}
            <div
              className="mt-1"
              style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: "0.3em", color: C.muted }}
            >
              SINTONG.KR
            </div>
          </div>
        </div>

        {!preview && !loadError && (
          <p className="mt-4 text-center text-[12px]" style={{ color: C.muted }}>
            쿠폰 상태를 확인하는 중이에요...
          </p>
        )}

        {displayGuide && !isBlocked && (
          <p className="mt-4 text-center text-[13px] leading-relaxed" style={{ color: C.muted }}>
            {displayGuide}
          </p>
        )}

        {isBlocked && statusMessage && (
          <div
            className="mt-4 rounded-2xl px-4 py-3 text-center"
            style={{ border: "1px solid rgba(201,74,59,.4)", background: "rgba(201,74,59,.12)" }}
          >
            <p className="text-[13px] font-semibold" style={{ color: "#f3b3a9" }}>
              {statusMessage}
            </p>
          </div>
        )}

        {/* ── CTA ── */}
        <a
          href={APP_COUPON_URL(token)}
          aria-disabled={isBlocked}
          className="mt-[18px] block h-14 w-full rounded-[14px] text-center text-[16px] font-bold leading-[56px]"
          style={{
            fontFamily: FONT_BODY,
            backgroundImage: isBlocked ? "none" : "linear-gradient(180deg, #f8d97e, #f5cf6a 60%, #e8b956)",
            backgroundColor: isBlocked ? "rgba(255,235,200,0.08)" : undefined,
            color: isBlocked ? "rgba(248,242,230,0.35)" : "#2a1a10",
            boxShadow: isBlocked ? "none" : `0 4px 20px ${C.glowShadow}, inset 0 1px 0 rgba(255,255,255,.4)`,
            pointerEvents: isBlocked ? "none" : "auto",
          }}
        >
          {isBlocked ? "지금은 등록할 수 없어요" : "로그인하고 쿠폰 등록하러 가기"}
        </a>
        <p className="mt-[10px] text-center text-[12px] leading-[1.5]" style={{ color: C.muted }}>
          신통방통 회원이 아니라면 다음 화면에서 바로 가입할 수 있어요.
        </p>

        <div
          className="mt-[14px] pt-3 text-center"
          style={{ borderTop: `1px solid ${C.line}`, fontFamily: FONT_MONO, fontSize: 9, letterSpacing: "0.12em", color: C.mutedFaint }}
        >
          © 2026 SINTONGBANGTONG. ALL RIGHTS RESERVED.
        </div>
      </div>
    </div>
  );
}

function Brand() {
  return (
    <div className="flex items-center gap-[9px]">
      <span
        className="flex h-[30px] w-[30px] items-center justify-center rounded-full"
        style={{
          backgroundImage: "linear-gradient(140deg, #d9a07a, #8b5a43)",
          boxShadow: "0 0 12px rgba(217,160,122,.35)",
        }}
      >
        <span style={{ fontFamily: FONT_DISPLAY, fontWeight: 900, fontSize: 14, color: "#fff9e8" }}>신</span>
      </span>
      <span style={{ fontFamily: FONT_DISPLAY, fontWeight: 900, fontSize: 17, letterSpacing: "-0.02em", color: C.fg }}>
        신통방통
      </span>
    </div>
  );
}
