// ══════════════════════════════════════════════════════════════════
// BokjuCouponImageService — [복주머니 마케팅 쿠폰 최종본 §5] 모바일 쿠폰
// 이미지 자동 제작(QR 합성) + ZIP/엑셀 일괄 다운로드.
//
// [설계 원칙]
//   - 이미지는 고객이 "받는" 쿠폰일 뿐, 실제 사용 권한은 서버의 쿠폰 데이터로만
//     검증한다(§5 "이미지만 복사하거나 QR코드만 열었다고 복주머니가 자동
//     지급되지 않습니다"). 이 모듈은 순수 "보여주기용 이미지 생성"만 담당하고,
//     redeem 로직(bokju-coupon-service.ts)에는 전혀 관여하지 않는다.
//   - 대량 생성은 Node.js 프로세스 내 setImmediate 루프의 백그라운드 작업으로
//     처리한다(이 프로젝트엔 별도 워커 프로세스/큐 인프라가 없으므로, 기존
//     "백그라운드 처리" 요구는 Next.js 서버 프로세스 안에서 비동기 루프 +
//     DB 진행률 polling으로 구현한다 — sharp 합성 자체가 CPU-bound라 이벤트
//     루프를 블로킹하지 않도록 배치 사이에 setImmediate로 양보한다).
//   - 실패 항목은 failedCouponIds(JSON)에 쌓이고, retryFailedImages()로 그
//     항목만 재시도한다(전체 재생성 금지 원칙).
// ══════════════════════════════════════════════════════════════════
import { mkdir, writeFile, readFile } from "fs/promises";
import path from "path";
import QRCode from "qrcode";
import sharp from "sharp";
import archiver from "archiver";
import ExcelJS from "exceljs";
import { prisma } from "@/lib/db";
import {
  type CouponVisibilityConfig,
  computeLayout,
  parseVisibilityJson,
  CANVAS_WIDTH as CUSTOM_CANVAS_WIDTH,
  CANVAS_HEIGHT as CUSTOM_CANVAS_HEIGHT,
} from "@/lib/bokju-coupon-visibility";
// [4단계 — 02e_4단계-에디터.md §3-3/§6 완료기준11] 배치 발행 경로를 신규
// 쿠폰 디자인 스튜디오(리비전 고정) 렌더러로 연결한다. 이 import 자체는
// 절대불가침 원칙을 깨지 않는다 — bokju-coupon-design/dispatch.ts 는
// "이 파일이 4단계에서 배선해야 할 대상"으로 02d §9/02e §3-3 가 이미
// 명시한 신규(3단계) 산출물이며, 02d §7-5의 절대불가침은
// bokju-coupon-image-service.ts 자체(이 파일)를 "3단계에서" 건드리지
// 말라는 뜻이었다 — 4단계 작업 범위에서는 이 파일의 수정이 지시서에
// 명시적으로 요구된다(02e §1/§3/§6-11).
import { dispatchCouponRender } from "@/lib/bokju-coupon-design/dispatch";

const PUBLIC_DIR = path.join(process.cwd(), "public");
// [턴C — 02w §0-AA-4] 저장 루트를 앱 디렉터리 "밖"으로 옮긴다.
// [5단계 보안 수정 — 02t §0-X-4 ①]에서는 일단 public/ 밖(앱 디렉터리 "안"의
// storage/bokju-coupons)으로만 옮겼으나, 그 경로는 여전히 <project>/storage
// 였다 — 운영 배포가 rsync(ubuntu@sintong.kr:/var/www/admin_web)로 앱
// 디렉터리 자체를 교체/동기화하는 방식이라, `rsync --delete`나 디렉터리
// 교체 배포 시 "이미 발행된 쿠폰 이미지"가 통째로 삭제될 위험이 있었다.
// 참고 구현(sintong-coupon renderer.ts:314)이 정확히 이 이유로 앱 밖
// `IMAGE_OUTPUT_DIR ?? '/var/lib/sintong/coupons'`를 쓴다 — 여기서도
// 동일한 원리로 BOKJU_IMAGE_DIR(env)가 있으면 그걸 쓰고, 없으면 앱 밖
// 기본값 `/var/lib/sintong/bokju-coupons`로 폴백한다(더 이상
// process.cwd() 기준 상대경로를 쓰지 않는다 — 배포 시 디렉터리가 바뀌어도
// 이미지가 그대로 남아 있어야 하므로).
const STORAGE_ROOT =
  process.env.BOKJU_IMAGE_DIR ?? "/var/lib/sintong/bokju-coupons";

const IMG_WIDTH = 720;
const IMG_HEIGHT = 1280;
const BATCH_SIZE = 20; // 배치마다 이벤트 루프에 양보

function campaignDir(campaignId: number): string {
  return path.join(STORAGE_ROOT, `campaign_${campaignId}`);
}

// [5단계 보안 수정] 더 이상 public/ 아래 정적 URL을 반환하지 않는다 —
// 호출부가 반드시 인증 서빙 라우트(/api/admin|partner/bokju-coupons/images/[couponId])
// 를 통해서만 이미지를 받도록 강제한다. 이 함수의 반환값은 "파일시스템
// 조회용 식별자"로만 쓰이고, 어떤 API 응답에도 그대로 노출되지 않는다.

function fmtDate(d: Date): string {
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

/** [카카오톡 스타일 쿠폰 디자인 템플릿 4종] bokju-coupon-service.ts의
 * BokjuCouponDesignTemplate과 동일한 값 집합. 여기서 문자열 리터럴 유니온을
 * 다시 선언하지 않고 string으로 느슨하게 받되, buildSvgForTemplate()의
 * switch가 알 수 없는 값은 CLASSIC으로 안전하게 폴백한다(과거 데이터/오타 방어). */
type DesignTemplateId = "CLASSIC" | "PREMIUM" | "KAKAO" | "MINIMAL";

interface SvgBuildParams {
  campaignTitle: string;
  grantAmount: number;
  couponNo: string;
  guide: string;
  validFrom: Date;
  validTo: Date;
  qrBase64: string;
}

/**
 * [디자인 1/4] CLASSIC — 전통 복주머니. 적갈색/금색 그라디언트 배경에 크림색
 * 카드를 올린 기존(2026-10 최초 버전) 레이아웃을 그대로 유지한다(하위 호환
 * — 기존에 이미 발급된 쿠폰과 완전히 동일한 톤 유지가 목적).
 */
function buildClassicSvg(p: SvgBuildParams): string {
  return `
<svg width="${IMG_WIDTH}" height="${IMG_HEIGHT}" viewBox="0 0 ${IMG_WIDTH} ${IMG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#7a1f1f"/>
      <stop offset="55%" stop-color="#4a1212"/>
      <stop offset="100%" stop-color="#2a0a0a"/>
    </linearGradient>
    <linearGradient id="card" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#fff8e7"/>
      <stop offset="100%" stop-color="#fdeec9"/>
    </linearGradient>
  </defs>
  <rect width="${IMG_WIDTH}" height="${IMG_HEIGHT}" fill="url(#bg)"/>
  <circle cx="90" cy="110" r="150" fill="#ffd54f" opacity="0.08"/>
  <circle cx="${IMG_WIDTH - 60}" cy="${IMG_HEIGHT - 160}" r="200" fill="#ffd54f" opacity="0.07"/>

  <text x="${IMG_WIDTH / 2}" y="100" font-size="34" font-weight="700" fill="#ffd54f" text-anchor="middle" font-family="sans-serif">신통방통</text>
  <text x="${IMG_WIDTH / 2}" y="150" font-size="26" fill="#ffe9c0" text-anchor="middle" font-family="sans-serif">${escapeXml(p.campaignTitle)}</text>

  <rect x="60" y="200" width="${IMG_WIDTH - 120}" height="${IMG_HEIGHT - 400}" rx="28" fill="url(#card)"/>

  <text x="${IMG_WIDTH / 2}" y="290" font-size="30" fill="#7a1f1f" text-anchor="middle" font-family="sans-serif">지급 복주머니</text>
  <text x="${IMG_WIDTH / 2}" y="370" font-size="84" font-weight="800" fill="#c62828" text-anchor="middle" font-family="sans-serif">${p.grantAmount}</text>

  <image x="${IMG_WIDTH / 2 - 210}" y="410" width="420" height="420" href="data:image/png;base64,${p.qrBase64}"/>

  <text x="${IMG_WIDTH / 2}" y="880" font-size="24" fill="#6d4c20" text-anchor="middle" font-family="monospace">${escapeXml(p.couponNo)}</text>
  <text x="${IMG_WIDTH / 2}" y="930" font-size="22" fill="#8a6a3a" text-anchor="middle" font-family="sans-serif">${escapeXml(p.guide)}</text>
  <text x="${IMG_WIDTH / 2}" y="975" font-size="20" fill="#9b7b4a" text-anchor="middle" font-family="sans-serif">사용기한 ${fmtDate(p.validFrom)} ~ ${fmtDate(p.validTo)}</text>

  <text x="${IMG_WIDTH / 2}" y="${IMG_HEIGHT - 50}" font-size="18" fill="#ffe9c0" text-anchor="middle" font-family="sans-serif" opacity="0.85">신통방통 마케팅 쿠폰 · 1회 등록 가능</text>
</svg>`.trim();
}

/**
 * [디자인 2/4] PREMIUM — 고급 선물. 블랙 배경 + 골드 테두리/타이포로 프리미엄
 * 제휴 브랜드(예: 백화점, 호텔) 느낌을 낸다. 카드에 얇은 금색 double-border를
 * 둘러 "고급 선물 디자인"(개발명세서 §5 참고용 이미지 2종 중 하나) 요구를
 * 반영한다.
 */
function buildPremiumSvg(p: SvgBuildParams): string {
  return `
<svg width="${IMG_WIDTH}" height="${IMG_HEIGHT}" viewBox="0 0 ${IMG_WIDTH} ${IMG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1a1a1a"/>
      <stop offset="100%" stop-color="#000000"/>
    </linearGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#bf953f"/>
      <stop offset="50%" stop-color="#fcf6ba"/>
      <stop offset="100%" stop-color="#b38728"/>
    </linearGradient>
  </defs>
  <rect width="${IMG_WIDTH}" height="${IMG_HEIGHT}" fill="url(#bg)"/>

  <text x="${IMG_WIDTH / 2}" y="110" font-size="30" font-weight="700" fill="url(#gold)" text-anchor="middle" font-family="serif" letter-spacing="4">S I N T O N G</text>
  <text x="${IMG_WIDTH / 2}" y="155" font-size="24" fill="#e8d9a8" text-anchor="middle" font-family="serif">${escapeXml(p.campaignTitle)}</text>

  <rect x="56" y="210" width="${IMG_WIDTH - 112}" height="${IMG_HEIGHT - 410}" rx="4" fill="none" stroke="url(#gold)" stroke-width="2"/>
  <rect x="70" y="224" width="${IMG_WIDTH - 140}" height="${IMG_HEIGHT - 438}" rx="2" fill="none" stroke="url(#gold)" stroke-width="1" opacity="0.6"/>

  <text x="${IMG_WIDTH / 2}" y="300" font-size="22" fill="#cbb77a" text-anchor="middle" font-family="serif" letter-spacing="2">GIFT · 지급 복주머니</text>
  <text x="${IMG_WIDTH / 2}" y="390" font-size="90" font-weight="300" fill="#fcf6ba" text-anchor="middle" font-family="serif">${p.grantAmount}</text>

  <rect x="${IMG_WIDTH / 2 - 225}" y="430" width="450" height="450" fill="#ffffff" rx="8"/>
  <image x="${IMG_WIDTH / 2 - 210}" y="445" width="420" height="420" href="data:image/png;base64,${p.qrBase64}"/>

  <text x="${IMG_WIDTH / 2}" y="930" font-size="22" fill="#d9c58f" text-anchor="middle" font-family="monospace" letter-spacing="1">${escapeXml(p.couponNo)}</text>
  <text x="${IMG_WIDTH / 2}" y="975" font-size="20" fill="#8a7a50" text-anchor="middle" font-family="serif">${escapeXml(p.guide)}</text>
  <text x="${IMG_WIDTH / 2}" y="1015" font-size="18" fill="#6e6248" text-anchor="middle" font-family="serif">${fmtDate(p.validFrom)} ~ ${fmtDate(p.validTo)}</text>

  <text x="${IMG_WIDTH / 2}" y="${IMG_HEIGHT - 50}" font-size="16" fill="#8a7a50" text-anchor="middle" font-family="serif" letter-spacing="2" opacity="0.85">신통방통 프리미엄 선물 · 1회 등록 가능</text>
</svg>`.trim();
}

/**
 * [디자인 3/4] KAKAO — 카카오톡 스타일. 카카오 브랜드 옐로우(#FEE500) 배경 +
 * 카카오톡 채팅창을 연상시키는 흰색 "말풍선" 카드(좌상단 꼬리 포함)로 구성한다
 * (2단계 항목 요구: "카카오톡 스타일 모바일 쿠폰 디자인 템플릿"). 실제 카카오톡
 * 로고/캐릭터(라이언 등)는 저작권 문제로 사용하지 않고, 브랜드 컬러와 UI
 * 문법(말풍선, 노란 배경)만 차용한다.
 */
function buildKakaoSvg(p: SvgBuildParams): string {
  const bubbleX = 60;
  const bubbleY = 170;
  const bubbleW = IMG_WIDTH - 120;
  const bubbleH = IMG_HEIGHT - 340;
  return `
<svg width="${IMG_WIDTH}" height="${IMG_HEIGHT}" viewBox="0 0 ${IMG_WIDTH} ${IMG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${IMG_WIDTH}" height="${IMG_HEIGHT}" fill="#FEE500"/>

  <!-- 상단 카카오톡 채팅방 헤더 느낌 -->
  <circle cx="${IMG_WIDTH / 2}" cy="78" r="34" fill="#3C1E1E"/>
  <text x="${IMG_WIDTH / 2}" y="89" font-size="28" text-anchor="middle" font-family="sans-serif">🧧</text>
  <text x="${IMG_WIDTH / 2}" y="140" font-size="22" font-weight="700" fill="#3C1E1E" text-anchor="middle" font-family="sans-serif">신통방통 선물이 도착했어요!</text>

  <!-- 말풍선 카드(좌상단 꼬리) -->
  <path d="M ${bubbleX + 36} ${bubbleY} h -16 l 10 -22 z" fill="#ffffff"/>
  <rect x="${bubbleX}" y="${bubbleY}" width="${bubbleW}" height="${bubbleH}" rx="22" fill="#ffffff"/>

  <text x="${IMG_WIDTH / 2}" y="${bubbleY + 70}" font-size="20" fill="#8E8E8E" text-anchor="middle" font-family="sans-serif">${escapeXml(p.campaignTitle)}</text>
  <text x="${IMG_WIDTH / 2}" y="${bubbleY + 150}" font-size="24" fill="#3C1E1E" text-anchor="middle" font-family="sans-serif">지급 복주머니</text>
  <text x="${IMG_WIDTH / 2}" y="${bubbleY + 235}" font-size="78" font-weight="800" fill="#3C1E1E" text-anchor="middle" font-family="sans-serif">${p.grantAmount}</text>

  <rect x="${IMG_WIDTH / 2 - 190}" y="${bubbleY + 270}" width="380" height="380" fill="#ffffff" stroke="#F4D900" stroke-width="4" rx="16"/>
  <image x="${IMG_WIDTH / 2 - 180}" y="${bubbleY + 280}" width="360" height="360" href="data:image/png;base64,${p.qrBase64}"/>

  <rect x="${IMG_WIDTH / 2 - 160}" y="${bubbleY + bubbleH - 90}" width="320" height="48" rx="24" fill="#FEE500"/>
  <text x="${IMG_WIDTH / 2}" y="${bubbleY + bubbleH - 58}" font-size="22" font-weight="700" fill="#3C1E1E" text-anchor="middle" font-family="monospace">${escapeXml(p.couponNo)}</text>

  <text x="${IMG_WIDTH / 2}" y="${bubbleY + bubbleH + 55}" font-size="22" fill="#3C1E1E" text-anchor="middle" font-family="sans-serif">${escapeXml(p.guide)}</text>
  <text x="${IMG_WIDTH / 2}" y="${bubbleY + bubbleH + 92}" font-size="19" fill="#5b4a1a" text-anchor="middle" font-family="sans-serif">사용기한 ${fmtDate(p.validFrom)} ~ ${fmtDate(p.validTo)}</text>

  <text x="${IMG_WIDTH / 2}" y="${IMG_HEIGHT - 45}" font-size="18" fill="#3C1E1E" text-anchor="middle" font-family="sans-serif" opacity="0.75">신통방통 마케팅 쿠폰 · 1회 등록 가능</text>
</svg>`.trim();
}

/**
 * [디자인 4/4] MINIMAL — 미니멀. 순백 배경 + 얇은 그레이 라인만으로 구성해
 * 과한 장식 없이 정보 전달에 집중한 디자인(앱 톤 전환이 잦은 B2B 제휴처나
 * 세련된 톤을 원하는 캠페인용).
 */
function buildMinimalSvg(p: SvgBuildParams): string {
  return `
<svg width="${IMG_WIDTH}" height="${IMG_HEIGHT}" viewBox="0 0 ${IMG_WIDTH} ${IMG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${IMG_WIDTH}" height="${IMG_HEIGHT}" fill="#ffffff"/>
  <line x1="60" y1="140" x2="${IMG_WIDTH - 60}" y2="140" stroke="#e5e5e5" stroke-width="1"/>

  <text x="${IMG_WIDTH / 2}" y="90" font-size="24" font-weight="600" fill="#111111" text-anchor="middle" font-family="sans-serif" letter-spacing="2">SINTONG</text>
  <text x="${IMG_WIDTH / 2}" y="190" font-size="22" fill="#555555" text-anchor="middle" font-family="sans-serif">${escapeXml(p.campaignTitle)}</text>

  <text x="${IMG_WIDTH / 2}" y="300" font-size="18" fill="#999999" text-anchor="middle" font-family="sans-serif" letter-spacing="1">지급 복주머니</text>
  <text x="${IMG_WIDTH / 2}" y="390" font-size="96" font-weight="200" fill="#111111" text-anchor="middle" font-family="sans-serif">${p.grantAmount}</text>

  <rect x="${IMG_WIDTH / 2 - 190}" y="440" width="380" height="380" fill="#ffffff" stroke="#e5e5e5" stroke-width="1"/>
  <image x="${IMG_WIDTH / 2 - 175}" y="455" width="350" height="350" href="data:image/png;base64,${p.qrBase64}"/>

  <text x="${IMG_WIDTH / 2}" y="870" font-size="22" fill="#333333" text-anchor="middle" font-family="monospace" letter-spacing="1">${escapeXml(p.couponNo)}</text>

  <line x1="60" y1="910" x2="${IMG_WIDTH - 60}" y2="910" stroke="#e5e5e5" stroke-width="1"/>

  <text x="${IMG_WIDTH / 2}" y="955" font-size="19" fill="#555555" text-anchor="middle" font-family="sans-serif">${escapeXml(p.guide)}</text>
  <text x="${IMG_WIDTH / 2}" y="990" font-size="17" fill="#999999" text-anchor="middle" font-family="sans-serif">${fmtDate(p.validFrom)} ~ ${fmtDate(p.validTo)}</text>

  <text x="${IMG_WIDTH / 2}" y="${IMG_HEIGHT - 50}" font-size="15" fill="#bbbbbb" text-anchor="middle" font-family="sans-serif" letter-spacing="1">신통방통 마케팅 쿠폰 · 1회 등록 가능</text>
</svg>`.trim();
}

function buildSvgForTemplate(template: string, p: SvgBuildParams): string {
  switch (template as DesignTemplateId) {
    case "PREMIUM":
      return buildPremiumSvg(p);
    case "KAKAO":
      return buildKakaoSvg(p);
    case "MINIMAL":
      return buildMinimalSvg(p);
    case "CLASSIC":
    default:
      // 알 수 없는 값(과거 데이터/오타 방어)은 항상 CLASSIC으로 안전 폴백.
      return buildClassicSvg(p);
  }
}

// ══════════════════════════════════════════════════════════════════
// [신통방통 AI 쿠폰 디자인 표시·숨김 기능] 커스텀 템플릿(AI 배경 + 11개
// 항목 표시/숨김 설정) 렌더링. 기존 4종 내장 템플릿(buildClassicSvg 등)과
// 완전히 독립된 별도 함수이며, 기존 템플릿 코드는 단 한 줄도 수정하지
// 않는다(하위 호환 100% 보장 — 기존에 발급된 쿠폰/진행 중인 캠페인은
// 전혀 영향받지 않는다).
//
// [§2 "표시하지 않는 항목은 빈 공간이 남지 않도록 자연스럽게 재배치"]
// bokju-coupon-visibility.ts의 computeLayout()이 계산한 y좌표를 그대로
// 사용한다 — 레이아웃 계산과 렌더링이 분리되어 있으므로, 향후 블록을
// 추가/변경할 때도 이 함수만 computeLayout과 함께 맞춰주면 된다.
// ══════════════════════════════════════════════════════════════════
export interface CustomSvgBuildParams {
  backgroundBase64: string | null; // null이면 흰 배경 기본값(MINIMAL과 유사)
  visibility: CouponVisibilityConfig;
  campaignTitle: string;
  partnerOrEventName: string | null; // 이벤트명 또는 제휴업체명(§2 항목) — 없으면 campaignTitle로 대체
  grantAmount: number;
  couponNo: string;
  guide: string;
  validFrom: Date;
  validTo: Date;
  qrBase64: string | null; // visibility.qr=false면 애초에 호출부에서 QR을 만들지 않고 null 전달 가능
}

function buildCustomDesignSvg(p: CustomSvgBuildParams): string {
  const W = CUSTOM_CANVAS_WIDTH;
  const H = CUSTOM_CANVAS_HEIGHT;
  const { blocks } = computeLayout(p.visibility);
  const cx = W / 2;

  const parts: string[] = [];

  // ── 배경: AI 생성 이미지(있으면) 또는 심플 화이트+그라디언트 기본값 ──
  if (p.backgroundBase64) {
    parts.push(
      `<image x="0" y="0" width="${W}" height="${H}" href="data:image/png;base64,${p.backgroundBase64}" preserveAspectRatio="xMidYMid slice"/>`
    );
    // 배경 위에 글자 가독성을 위한 반투명 어둡기 보정 오버레이(배경이 밝든
    // 어둡든 흰 텍스트/검정 텍스트 중 하나로 통일 가독성을 보장하기 위해
    // 카드 영역에만 반투명 흰 패널을 깐다).
  } else {
    parts.push(`<rect width="${W}" height="${H}" fill="#f8f6f2"/>`);
  }

  // 콘텐츠 가독성 보정용 반투명 카드 패널(장식 off여도 가독성을 위해 항상 깐다 —
  // 완전 투명 배경 위에 텍스트만 얹으면 AI 배경 색상에 따라 읽기 어려워지는
  // 문제를 방지하는 최소한의 처리이며, 이것은 "장식"이 아니라 "가독성 보장"이므로
  // decoration 토글과 무관하게 항상 적용한다).
  const contentTop = blocks.logo?.y ?? blocks.partnerName?.y ?? blocks.title?.y ?? 40;
  const contentBottom =
    (blocks.ctaText ? blocks.ctaText.y + blocks.ctaText.height : 0) ||
    (blocks.guideText ? blocks.guideText.y + blocks.guideText.height : 0) ||
    (blocks.validTo ? blocks.validTo.y + blocks.validTo.height : 0) ||
    (blocks.couponNo ? blocks.couponNo.y + blocks.couponNo.height : 0) ||
    (blocks.qr ? blocks.qr.y + blocks.qr.height : 0) ||
    contentTop + 100;
  const panelTop = Math.max(0, contentTop - 30);
  const panelHeight = Math.min(H - panelTop - 20, contentBottom - panelTop + 40);
  if (p.backgroundBase64) {
    parts.push(
      `<rect x="30" y="${panelTop}" width="${W - 60}" height="${panelHeight}" rx="24" fill="#ffffff" opacity="0.82"/>`
    );
  }

  // ── 장식 요소 및 테두리(§2 항목) ──
  if (p.visibility.decoration) {
    parts.push(
      `<rect x="14" y="14" width="${W - 28}" height="${H - 28}" rx="20" fill="none" stroke="#d4a94a" stroke-width="3" opacity="0.7"/>`
    );
    parts.push(`<circle cx="50" cy="60" r="90" fill="#d4a94a" opacity="0.06"/>`);
    parts.push(`<circle cx="${W - 40}" cy="${H - 90}" r="130" fill="#d4a94a" opacity="0.06"/>`);
  }

  // ── 신통방통 로고 ──
  if (blocks.logo) {
    const b = blocks.logo;
    parts.push(
      `<text x="${cx}" y="${b.y + 36}" font-size="30" font-weight="700" fill="#7a1f1f" text-anchor="middle" font-family="sans-serif">신통방통</text>`
    );
  }

  // ── 이벤트명 또는 제휴업체명 ──
  if (blocks.partnerName) {
    const b = blocks.partnerName;
    const label = p.partnerOrEventName?.trim() || p.campaignTitle;
    parts.push(
      `<text x="${cx}" y="${b.y + 28}" font-size="20" fill="#8a6a3a" text-anchor="middle" font-family="sans-serif">${escapeXml(label)}</text>`
    );
  }

  // ── 쿠폰명 ──
  if (blocks.title) {
    const b = blocks.title;
    parts.push(
      `<text x="${cx}" y="${b.y + 34}" font-size="26" fill="#3c2a12" text-anchor="middle" font-family="sans-serif">${escapeXml(p.campaignTitle)}</text>`
    );
  }

  // ── 지급 복주머니 수량 ──
  if (blocks.amount) {
    const b = blocks.amount;
    parts.push(
      `<text x="${cx}" y="${b.y + 40}" font-size="24" fill="#8a6a3a" text-anchor="middle" font-family="sans-serif">지급 복주머니</text>`
    );
    parts.push(
      `<text x="${cx}" y="${b.y + 130}" font-size="78" font-weight="800" fill="#c62828" text-anchor="middle" font-family="sans-serif">${p.grantAmount}</text>`
    );
  }

  // ── QR코드 ──
  if (blocks.qr && p.qrBase64) {
    const b = blocks.qr;
    const qrSize = 360;
    const qrX = cx - qrSize / 2;
    parts.push(`<rect x="${qrX - 10}" y="${b.y + 10}" width="${qrSize + 20}" height="${qrSize + 20}" fill="#ffffff" rx="12"/>`);
    parts.push(
      `<image x="${qrX}" y="${b.y + 20}" width="${qrSize}" height="${qrSize}" href="data:image/png;base64,${p.qrBase64}"/>`
    );
  }

  // ── 쿠폰번호 ──
  if (blocks.couponNo) {
    const b = blocks.couponNo;
    parts.push(
      `<text x="${cx}" y="${b.y + 30}" font-size="22" fill="#6d4c20" text-anchor="middle" font-family="monospace">${escapeXml(p.couponNo)}</text>`
    );
  }

  // ── 사용 시작일/만료일 (한 줄로 합쳐 그림 — validFrom은 독립 블록이 없고
  //    validTo 블록 안에서 visibility.validFrom 값을 보고 내용만 바꾼다) ──
  if (blocks.validTo) {
    const b = blocks.validTo;
    const text = p.visibility.validFrom
      ? `사용기한 ${fmtDate(p.validFrom)} ~ ${fmtDate(p.validTo)}`
      : `사용기한 ~${fmtDate(p.validTo)}까지`;
    parts.push(
      `<text x="${cx}" y="${b.y + 24}" font-size="19" fill="#9b7b4a" text-anchor="middle" font-family="sans-serif">${escapeXml(text)}</text>`
    );
  }

  // ── 쿠폰 안내 문구 ──
  if (blocks.guideText) {
    const b = blocks.guideText;
    parts.push(
      `<text x="${cx}" y="${b.y + 28}" font-size="20" fill="#8a6a3a" text-anchor="middle" font-family="sans-serif">${escapeXml(p.guide)}</text>`
    );
  }

  // ── '쿠폰 등록하러 가기' 안내 ──
  if (blocks.ctaText) {
    const b = blocks.ctaText;
    parts.push(`<rect x="${cx - 160}" y="${b.y}" width="320" height="48" rx="24" fill="#7a1f1f"/>`);
    parts.push(
      `<text x="${cx}" y="${b.y + 32}" font-size="20" font-weight="700" fill="#ffffff" text-anchor="middle" font-family="sans-serif">쿠폰 등록하러 가기</text>`
    );
  }

  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">${parts.join("\n")}</svg>`;
}

/**
 * 쿠폰 1장의 모바일 이미지를 합성한다.
 * - 상단: 신통방통 로고 텍스트 + 쿠폰명
 * - 중앙: 지급 복주머니 수량(큰 숫자) + QR코드
 * - 하단: 쿠폰 고유번호(마스킹 없이 전체 표시 — 고객이 직접 입력할 수도 있어야 함),
 *   사용 시작일/만료일, 안내 문구
 * [카카오톡 스타일 쿠폰 디자인 템플릿 4종] designTemplate 값에 따라 4개의
 * 서로 다른 SVG 레이아웃(buildClassicSvg/buildPremiumSvg/buildKakaoSvg/
 * buildMinimalSvg) 중 하나를 선택해 렌더링한다. QR코드 색상도 어두운 배경
 * 템플릿(PREMIUM/KAKAO 말풍선 밖)에서 잘 보이도록 항상 흰 배경 위에 얹는다.
 */
/**
 * [AI 쿠폰 디자인 표시·숨김 기능] customTemplateId가 설정된 캠페인을 렌더링할 때
 * renderCouponImage()에 전달하는 추가 파라미터. 이 객체가 존재하면 4개 내장
 * 템플릿(buildSvgForTemplate) 대신 buildCustomDesignSvg()로 렌더링을 분기한다.
 * - visibility.qr === false이면 애초에 QRCode.toBuffer() 자체를 호출하지 않는다
 *   (§3 "QR/쿠폰번호 표시는 선택이지만 실제 지급·검증은 항상 기존 서버 기능을
 *   거쳐야 합니다" — 이미지에 안 그릴 뿐, qrUrl/redeemToken 생성·검증 로직
 *   자체는 변경하지 않는다. 단지 "그림으로 그리는 비용"을 아낄 뿐이다).
 */
export interface CustomTemplateRenderInput {
  backgroundBase64: string | null;
  visibility: CouponVisibilityConfig;
  partnerOrEventName: string | null;
}

async function renderCouponImage(params: {
  campaignTitle: string;
  grantAmount: number;
  couponNo: string;
  redeemToken: string;
  validFrom: Date;
  validTo: Date;
  guideText: string | null;
  registerBaseUrl: string;
  designTemplate?: string;
  customTemplate?: CustomTemplateRenderInput;
}): Promise<Buffer> {
  const qrUrl = `${params.registerBaseUrl}/coupon/${params.redeemToken}`;
  const guide = params.guideText?.trim() || "QR코드를 찍고 복주머니를 받으세요!";

  // ── [AI 쿠폰 디자인] customTemplate이 있으면 커스텀 렌더러로 분기 ──
  if (params.customTemplate) {
    const needsQr = params.customTemplate.visibility.qr;
    const qrBase64 = needsQr
      ? (
          await QRCode.toBuffer(qrUrl, {
            width: 420,
            margin: 1,
            color: { dark: "#2b1b0e", light: "#ffffff00" },
          })
        ).toString("base64")
      : null;

    const svg = buildCustomDesignSvg({
      backgroundBase64: params.customTemplate.backgroundBase64,
      visibility: params.customTemplate.visibility,
      campaignTitle: params.campaignTitle,
      partnerOrEventName: params.customTemplate.partnerOrEventName,
      grantAmount: params.grantAmount,
      couponNo: params.couponNo,
      guide,
      validFrom: params.validFrom,
      validTo: params.validTo,
      qrBase64,
    });

    return sharp(Buffer.from(svg)).png().toBuffer();
  }

  // ── 기존 4종 내장 템플릿(100% 하위 호환, 변경 없음) ──
  const qrDataUrl = await QRCode.toBuffer(qrUrl, {
    width: 420,
    margin: 1,
    color: { dark: "#2b1b0e", light: "#ffffff00" },
  });
  const qrBase64 = qrDataUrl.toString("base64");

  const svg = buildSvgForTemplate(params.designTemplate ?? "CLASSIC", {
    campaignTitle: params.campaignTitle,
    grantAmount: params.grantAmount,
    couponNo: params.couponNo,
    guide,
    validFrom: params.validFrom,
    validTo: params.validTo,
    qrBase64,
  });

  return sharp(Buffer.from(svg)).png().toBuffer();
}

// [4단계 — 02e_4단계-에디터.md §0-D 위험1 대응] registerBaseUrl 의 실제
// 출처 한 줄: 이 값은 배치 경로 내부에서 스스로 계산되지 않는다. 유일한
// 두 호출부(아래)가 **요청 시점에** page-config-helpers.ts 의
// resolvePublicOrigin(request) 로 계산한 뒤 그대로 넘겨준 값이다 —
// runImageJob() 은 이 값을 "전달만" 할 뿐, env 폴백을 스스로 읽지 않는다.
//   1) POST .../campaigns/:id/generate-images/route.ts 28번 줄
//        const registerBaseUrl = resolvePublicOrigin(request);
//        startImageGenerationJob(campaignId, actor.adminId, { registerBaseUrl })
//   2) POST .../image-jobs/:id/retry/route.ts 19번 줄
//        const registerBaseUrl = resolvePublicOrigin(request);
//        retryFailedImages(jobId, { registerBaseUrl })
// 즉 "API 경로"와 "배치 경로"는 **같은 함수(resolvePublicOrigin)가 계산한
// 같은 값**을 쓴다 — 서로 다른 계산식이 아니다. env 폴백
// (FALLBACK_BASE_URL = COUPON_BASE_URL ?? 'https://sintong.kr',
// bokju-coupon-design/renderer.ts 103번 줄)은 dispatch.ts 가 항상
// registerBaseUrl 을 명시적으로 채워 넘기므로 이 경로에서는 트리거되지
// 않는다 — scripts/verify_batch_origin_matches_api.ts 가 이를 실측한다.
// 참고 구현(1차 패키지 sintong-coupon/src/coupon/jobs/image.worker.ts)은
// 메시지큐 워커(요청 객체가 영구히 없는 별도 프로세스)라 env 상수
// BASE_URL 을 모듈 로드 시 고정해 썼다 — admin_web 은 그 구조를 쓰지
// 않는다(큐 워커가 없다. HTTP 라우트가 "시작"시키고 같은 Node 프로세스
// 안에서 void runImageJob(...) 으로 백그라운드 실행된다. 즉 요청 객체가
// 여전히 "존재했던 시점"에 계산된 값을 받으므로, 별도 폴백 경로가 필요
// 없다). 이 구조적 차이가 위험1의 원인(env 폴백 사용)이 admin_web 에는
// 적용되지 않는 이유다 — 다만 이 사실을 "문서"가 아니라 "테스트"로
// 확정하기 위해 아래 스크립트를 추가했다.
export interface StartImageJobOptions {
  registerBaseUrl: string;
}

/** 캠페인의 쿠폰 전체(ISSUED 이상 상태) 이미지를 생성하는 작업을 등록하고 즉시 백그라운드로 시작한다. */
export async function startImageGenerationJob(
  campaignId: number,
  actorId: string,
  options: StartImageJobOptions
): Promise<{ jobId: number; totalCount: number }> {
  const coupons = await prisma.bokjuCoupon.findMany({
    where: { campaignId },
    select: { id: true },
  });
  if (coupons.length === 0) {
    throw new Error("발행된 쿠폰이 없습니다. 먼저 쿠폰을 발행하세요.");
  }

  const job = await prisma.bokjuCouponImageJob.create({
    data: {
      campaignId,
      status: "PENDING",
      totalCount: coupons.length,
      createdBy: actorId,
    },
  });

  // 백그라운드로 실행(await하지 않음) — API 응답은 즉시 jobId만 반환.
  void runImageJob(job.id, options).catch((e) => {
    console.error(`[BokjuCouponImageJob ${job.id}] 실행 중 예외:`, e);
  });

  return { jobId: job.id, totalCount: coupons.length };
}

/** 실패한 쿠폰 이미지만 재시도한다(§5 "실패 재시도" 요구사항 — 전체 재생성 금지). */
export async function retryFailedImages(
  jobId: number,
  options: StartImageJobOptions
): Promise<{ retried: number }> {
  const job = await prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
  if (!job) throw new Error("이미지 생성 작업을 찾을 수 없습니다.");
  const failedIds: number[] = job.failedCouponIds ? JSON.parse(job.failedCouponIds) : [];
  if (failedIds.length === 0) return { retried: 0 };

  await prisma.bokjuCouponImageJob.update({
    where: { id: jobId },
    data: { status: "RUNNING", failedCouponIds: null, failedCount: 0 },
  });

  void runImageJob(jobId, options, failedIds).catch((e) => {
    console.error(`[BokjuCouponImageJob ${jobId}] 재시도 중 예외:`, e);
  });

  return { retried: failedIds.length };
}

async function runImageJob(
  jobId: number,
  options: StartImageJobOptions,
  onlyCouponIds?: number[]
): Promise<void> {
  const job = await prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
  if (!job) return;

  await prisma.bokjuCouponImageJob.update({
    where: { id: jobId },
    data: { status: "RUNNING", startedAt: new Date() },
  });

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: job.campaignId } });
  if (!campaign) {
    await prisma.bokjuCouponImageJob.update({ where: { id: jobId }, data: { status: "FAILED" } });
    return;
  }

  // ── [AI 쿠폰 디자인] campaign.customTemplateId가 설정돼 있으면 템플릿+배경을
  //    미리 1회 조회해 배치 루프 안에서 매번 DB를 치지 않도록 한다. 템플릿이
  //    가리키는 배경 PNG는 "읽기 전용 자산"이라 매 쿠폰마다 동일한 base64를
  //    재사용해도 무방하다(§6 "템플릿에는 배경 이미지와 설정만 저장"). ──
  let customTemplate: CustomTemplateRenderInput | undefined;
  if (campaign.customTemplateId) {
    const tpl = await prisma.bokjuCouponDesignTemplate.findUnique({
      where: { id: campaign.customTemplateId },
      include: { designAsset: true },
    });
    if (tpl) {
      let backgroundBase64: string | null = null;
      if (tpl.designAsset?.imagePath) {
        try {
          const abs = path.join(PUBLIC_DIR, tpl.designAsset.imagePath.replace(/^\//, ""));
          backgroundBase64 = (await readFile(abs)).toString("base64");
        } catch (e) {
          console.error(`[BokjuCouponImageJob ${jobId}] 배경 이미지 로드 실패(흰 배경으로 대체):`, e);
        }
      }
      customTemplate = {
        backgroundBase64,
        visibility: parseVisibilityJson(tpl.visibility),
        partnerOrEventName: null, // 캠페인에 직접적인 제휴업체명 필드가 없어 현재는 campaignTitle로 대체(buildCustomDesignSvg 내부 기본값)
      };
    }
  }

  const coupons = await prisma.bokjuCoupon.findMany({
    where: onlyCouponIds ? { id: { in: onlyCouponIds } } : { campaignId: job.campaignId },
    // [4단계 — 완료기준11] designRevisionId 를 select 절에 추가한다. 이
    // 컬럼은 발행(쿠폰 생성) 시점에 이미 각인되어 있다(bokju-coupon-service.ts
    // issueCoupons(), 3단계에서 배선 완료) — 여기서는 "읽기만" 한다(02d
    // §7 금지 목록 #4 "렌더 시점에 조회하지 않는다"는 campaign.currentDesignRevisionId
    // 를 다시 조회하지 말라는 뜻이며, coupon.designRevisionId 를 select 하는
    // 것은 그 각인값을 그대로 읽는 것이므로 위반이 아니다).
    select: { id: true, couponNo: true, redeemToken: true, expiresAt: true, designRevisionId: true },
    orderBy: { id: "asc" },
  });

  const dir = campaignDir(job.campaignId);
  await mkdir(path.join(dir, "images"), { recursive: true });

  let processed = onlyCouponIds ? job.processedCount : 0;
  const failedIds: number[] = [];

  for (let i = 0; i < coupons.length; i += BATCH_SIZE) {
    const batch = coupons.slice(i, i + BATCH_SIZE);
    await Promise.all(
      batch.map(async (c) => {
        try {
          // [4단계 — 02e_4단계-에디터.md §3-3/§6 완료기준11] 쿠폰에
          // designRevisionId 가 각인되어 있으면(= 쿠폰 디자인 스튜디오에서
          // 발행된 쿠폰) 먼저 신규 렌더러(dispatchCouponRender)를 시도한다.
          // handled=true 면 그 결과(buffer)를 그대로 쓴다 — 레거시
          // renderCouponImage()(4종 내장 템플릿/커스텀 템플릿)는 호출하지
          // 않는다. handled=false(=레거시 쿠폰, designRevisionId=null)면
          // 기존 동작을 단 한 줄도 바꾸지 않고 그대로 레거시 경로로
          // 폴백한다(완료기준12 — 리비전 없는 쿠폰은 계속 720×1280 레거시).
          let buf: Buffer | undefined;
          if (c.designRevisionId != null) {
            const dispatched = await dispatchCouponRender({
              couponId: c.id,
              registerBaseUrl: options.registerBaseUrl,
            });
            if (dispatched.handled) {
              buf = dispatched.buffer;
            }
          }
          if (!buf) {
            buf = await renderCouponImage({
              campaignTitle: campaign.title,
              grantAmount: campaign.grantAmount,
              couponNo: c.couponNo,
              redeemToken: c.redeemToken,
              validFrom: campaign.validFrom,
              validTo: campaign.validTo,
              guideText: campaign.guideText,
              registerBaseUrl: options.registerBaseUrl,
              designTemplate: campaign.designTemplate,
              customTemplate,
            });
          }
          await writeFile(path.join(dir, "images", `${c.id}.png`), buf);
          processed += 1;
        } catch (e) {
          console.error(`[BokjuCouponImageJob ${jobId}] 쿠폰 ${c.id} 이미지 생성 실패:`, e);
          failedIds.push(c.id);
        }
      })
    );
    await prisma.bokjuCouponImageJob.update({
      where: { id: jobId },
      data: { processedCount: processed, failedCount: failedIds.length },
    });
    await new Promise((resolve) => setImmediate(resolve));
  }

  // [턴D — 02w §0-AA-4/작업순서] ZIP도 더 이상 여기서 파일로 미리 만들지
  // 않는다(엑셀은 턴B에서 이미 전환 완료). 참고구현 streamImagesZip(res, ...)
  // 과 동일하게 "다운로드 요청이 올 때" 응답 스트림에 그 자리에서 생성한다
  // (아래 streamCouponImagesZip 신설). zipPath 컬럼도 더 이상 채우지 않는다
  // — 값 자체가 존재하지 않으므로 "storage에 있는데 public 경로를 반환하는
  // 깨진 링크" 상태가 원천적으로 발생할 수 없다(턴C에서 저장 루트를 옮긴
  // 뒤 실측으로 확인된 문제 — 기존 zipPath 문자열이 이미 죽은 링크였다).
  await prisma.bokjuCouponImageJob.update({
    where: { id: jobId },
    data: {
      status: failedIds.length > 0 ? "FAILED" : "COMPLETED",
      failedCouponIds: failedIds.length > 0 ? JSON.stringify(failedIds) : null,
      completedAt: new Date(),
    },
  });
}

/**
 * [턴B — 02w §0-AA-2/§0-AA-3] 쿠폰번호/등록링크 엑셀을 파일로 저장하지 않고
 * 전달된 Node.js Writable(res)에 직접 스트리밍한다. 참고구현
 * writeNumbersXlsx(res, rows, meta)와 동일하게 반환값이 없다 — 호출부(새
 * 다운로드 라우트)가 이 함수가 끝날 때까지(await) 기다리면 응답이 완료된다.
 * ExcelJS.stream.xlsx.WorkbookWriter({ stream })가 workbook.commit() 호출 시
 * 그 stream에 직접 zip(xlsx)를 써 내려간다 — 디스크 경유 없음.
 */
export async function streamCouponExcel(
  destStream: import("stream").Writable,
  campaignId: number,
  coupons: { id: number; couponNo: string; redeemToken: string; status: string; expiresAt: Date }[],
  registerBaseUrl: string
): Promise<void> {
  const workbook = new ExcelJS.stream.xlsx.WorkbookWriter({ stream: destStream, useStyles: true });
  const sheet = workbook.addWorksheet("쿠폰번호목록");
  sheet.columns = [
    { header: "번호", key: "idx", width: 8 },
    { header: "쿠폰ID", key: "id", width: 10 },
    { header: "쿠폰번호", key: "couponNo", width: 26 },
    { header: "등록링크", key: "link", width: 50 },
    { header: "상태", key: "status", width: 12 },
    { header: "만료일", key: "expiresAt", width: 14 },
  ];
  sheet.getRow(1).font = { bold: true };
  sheet.getRow(1).commit();

  coupons.forEach((c, idx) => {
    sheet
      .addRow({
        idx: idx + 1,
        id: c.id,
        couponNo: c.couponNo,
        link: `${registerBaseUrl}/coupon/${c.redeemToken}`,
        status: c.status,
        expiresAt: fmtDate(c.expiresAt),
      })
      .commit();
  });

  void campaignId; // campaignDir() 조회가 필요 없어졌다(파일을 쓰지 않으므로) — 인자는 호출부 식별/로깅용으로만 유지.
  await workbook.commit();
}

/**
 * [턴D — 02w §0-AA-4] 쿠폰 이미지 ZIP을 파일로 미리 만들어 두지 않고,
 * 다운로드 요청이 올 때 그 자리에서 전달된 Node.js Writable(응답 스트림)에
 * 직접 스트리밍한다. 참고구현 streamImagesZip(res, items, meta)와 동일한
 * 패턴 — part/partSize로 묶음을 나누고, 존재하는 이미지만 추려(존재하지
 * 않는 항목은 조용히 건너뜀 — 실패 항목은 failedCouponIds로 별도 노출됨),
 * 마지막에 _manifest.json을 동봉한다. archiver 에러는 destStream.destroy(err)로
 * 전달해 응답이 반쪽 zip으로 내려가지 않고 비정상 종료되게 한다.
 *
 * 반환값 없음(엑셀 스트리밍 streamCouponExcel과 동일한 설계) — 호출부(다운로드
 * 라우트)가 이 함수가 끝날 때까지 await하면 응답이 완료된다.
 */
export async function streamCouponImagesZip(
  destStream: import("stream").Writable,
  campaignId: number,
  couponIds: number[],
  meta: { campaignTitle: string; part?: number; partSize?: number }
): Promise<{ count: number; total: number }> {
  const { existsSync } = await import("fs");
  const dir = campaignDir(campaignId);

  const usable = couponIds.filter((id) => existsSync(path.join(dir, "images", `${id}.png`)));
  if (usable.length === 0) {
    throw new Error("IMAGE_NOT_READY: 다운로드할 이미지가 아직 생성되지 않았습니다.");
  }

  const part = meta.part ?? 1;
  const partSize = meta.partSize ?? usable.length;
  const from = (part - 1) * partSize;
  const slice = usable.slice(from, from + partSize);

  const archive = archiver("zip", { zlib: { level: 6 } });
  archive.on("error", (err) => destStream.destroy(err));
  archive.pipe(destStream);

  for (const id of slice) {
    archive.file(path.join(dir, "images", `${id}.png`), { name: `${id}.png` });
  }
  archive.append(
    Buffer.from(
      JSON.stringify(
        {
          campaign: meta.campaignTitle,
          part,
          partSize,
          total: usable.length,
          count: slice.length,
          couponIds: slice,
          generatedAt: new Date().toISOString(),
        },
        null,
        2
      ),
      "utf8"
    ),
    { name: "_manifest.json" }
  );
  await archive.finalize();
  return { count: slice.length, total: usable.length };
}

/**
 * [업체 전용 다운로드] 특정 배정(allocation)에 속한 쿠폰 이미지만 묶어 응답
 * 스트림에 직접 흘려보낸다. 캠페인 전체 ZIP을 그대로 주면 다른 업체에 배정된
 * 쿠폰까지 노출되므로, 업체 화면에서는 반드시 이 함수를 통해 본인 배정분만
 * 받는다. 이미지가 아직 생성되지 않은 쿠폰은 건너뛴다(관리자가 이미지 생성을
 * 먼저 해야 함). [턴D] 메모리 Buffer.concat 방식을 제거하고 streamCouponImagesZip과
 * 동일하게 스트리밍으로 전환했다 — part/partSize는 업체 다운로드 특성상
 * 불필요(배정 규모가 보통 작음)하므로 받지 않는다(참고구현에도 선택 파라미터).
 */
export async function streamAllocationZip(
  destStream: import("stream").Writable,
  campaignId: number,
  allocationId: number,
  couponIds: number[]
): Promise<{ count: number; total: number }> {
  return streamCouponImagesZip(destStream, campaignId, couponIds, {
    campaignTitle: `allocation_${allocationId}`,
  });
}

export async function getImageJob(jobId: number) {
  return prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
}

export async function listImageJobsForCampaign(campaignId: number) {
  return prisma.bokjuCouponImageJob.findMany({
    where: { campaignId },
    orderBy: { createdAt: "desc" },
  });
}

// [5단계 보안 수정] 더 이상 public URL 문자열을 반환하지 않는다 — 이
// 함수는 "그 쿠폰 이미지의 파일시스템 절대경로"만 반환하며, 호출부(인증
// 서빙 라우트)가 readFile로 읽어 Response 바디에 직접 담아야 한다.
export function couponImagePath(campaignId: number, couponId: number): string {
  return path.join(campaignDir(campaignId), "images", `${couponId}.png`);
}

export async function readCouponImage(campaignId: number, couponId: number): Promise<Buffer | null> {
  try {
    return await readFile(path.join(campaignDir(campaignId), "images", `${couponId}.png`));
  } catch {
    return null;
  }
}

/**
 * [카카오톡 스타일 쿠폰 디자인 템플릿 4종 — 관리자 미리보기] 실제 쿠폰을
 * 발행하지 않고도 "쿠폰 만들기" 화면에서 4개 디자인 템플릿이 어떻게
 * 보이는지 즉시 확인할 수 있게 한다(개발명세서 §4 "12. 모바일 쿠폰 미리보기
 * — 디자인·번호·QR 확인" 요건). 더미 쿠폰번호/더미 QR(실제 redeemToken이
 * 아직 없으므로 "PREVIEW" 고정 문자열을 인코딩)을 사용해 renderCouponImage와
 * 동일한 템플릿 함수를 재사용한다 — 실제 발행 이미지와 100% 동일한 룩을
 * 보장하기 위해 별도 렌더링 로직을 만들지 않고 이 함수를 그대로 호출한다.
 */
export async function renderPreviewCouponImage(params: {
  designTemplate: string;
  campaignTitle: string;
  grantAmount: number;
  guideText: string | null;
  validFrom: Date;
  validTo: Date;
}): Promise<Buffer> {
  return renderCouponImage({
    campaignTitle: params.campaignTitle || "신통방통 복주머니 선물",
    grantAmount: params.grantAmount || 100,
    couponNo: "ST-PRVW-DEMO-X",
    redeemToken: "preview-demo-token-0000000000000",
    validFrom: params.validFrom,
    validTo: params.validTo,
    guideText: params.guideText,
    // 미리보기는 실제 공개 도메인이 필요 없고, QR 내용도 데모용이면 충분하다.
    registerBaseUrl: "https://sintong.kr/coupon-preview",
    designTemplate: params.designTemplate,
  });
}

/**
 * [AI 쿠폰 디자인 표시·숨김 기능 §5 "실시간 미리보기"] 관리자가 "쿠폰 디자인
 * 관리" 화면에서 11개 체크박스를 켜고 끌 때마다 즉시 호출되는 미리보기
 * 렌더러. 아직 템플릿으로 저장하지 않은 상태(visibility를 화면에서 바로
 * 전달)에서도 미리보기가 가능해야 하므로, 저장된 BokjuCouponDesignTemplate
 * 행을 요구하지 않고 visibility 객체 + (선택적) designAssetId만 받는다.
 *
 * [§5 "미리보기는 샘플/더미 데이터를 사용하고, 실제 발행은 실제 쿠폰 데이터를
 * 사용합니다"] 쿠폰번호/QR 내용/유효기간은 전부 더미값이며, renderCouponImage
 * 를 그대로 재사용해 실제 발행 이미지와 100% 동일한 렌더링 로직을 보장한다
 * (미리보기 전용 렌더링 코드를 별도로 두지 않음 — "미리보기 따로, 실제 따로"
 * 가 되어 나중에 결과물이 달라지는 사고를 방지하기 위함).
 */
export async function renderCustomTemplatePreview(params: {
  visibility: CouponVisibilityConfig;
  designAssetId?: number | null;
  partnerOrEventName?: string | null;
  campaignTitle?: string;
  grantAmount?: number;
  guideText?: string | null;
  validFrom?: Date;
  validTo?: Date;
}): Promise<Buffer> {
  let backgroundBase64: string | null = null;
  if (params.designAssetId) {
    const asset = await prisma.bokjuCouponDesignAsset.findUnique({
      where: { id: params.designAssetId },
    });
    if (asset?.imagePath) {
      try {
        const abs = path.join(PUBLIC_DIR, asset.imagePath.replace(/^\//, ""));
        backgroundBase64 = (await readFile(abs)).toString("base64");
      } catch (e) {
        console.error("[renderCustomTemplatePreview] 배경 이미지 로드 실패(흰 배경으로 대체):", e);
      }
    }
  }

  const now = new Date();
  const dummyValidFrom = params.validFrom ?? now;
  const dummyValidTo = params.validTo ?? new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

  return renderCouponImage({
    campaignTitle: params.campaignTitle?.trim() || "신통방통 복주머니 선물",
    grantAmount: params.grantAmount && params.grantAmount > 0 ? params.grantAmount : 100,
    couponNo: "ST-PRVW-DEMO-X",
    redeemToken: "preview-demo-token-0000000000000",
    validFrom: dummyValidFrom,
    validTo: dummyValidTo,
    guideText: params.guideText ?? null,
    registerBaseUrl: "https://sintong.kr/coupon-preview",
    customTemplate: {
      backgroundBase64,
      visibility: params.visibility,
      partnerOrEventName: params.partnerOrEventName ?? null,
    },
  });
}
