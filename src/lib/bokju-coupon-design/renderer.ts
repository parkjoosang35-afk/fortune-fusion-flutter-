// src/lib/bokju-coupon-design/renderer.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 2단계: 레이아웃 + 테마 기반 렌더러
//
// [이식 메모] 1차 전달 패키지 sintong-coupon/src/coupon/jobs/renderer.ts 를
//   admin_web(Next.js + Prisma + SQLite) 구조에 맞춰 "적응 이식"한다(그대로
//   복사 금지 — 02b_지시서_2단계.md §2-④). 변경한 지점과 이유는 각 블록
//   주석에 남긴다. 세부 결정 근거는 02c_2단계-결정사항.md 를 따른다.
//
// [절대 불가침 — 02b_지시서_2단계.md §2]
//   · bokju-coupon-image-service.ts 는 수정하지 않는다(이 파일에서 import 도
//     하지 않는다 — 완전히 독립된 신규 경로).
//   · computeLayout() / CouponVisibilityConfig(bokju-coupon-visibility.ts)
//     는 건드리지 않는다. "720x1280" 치수가 같을 뿐 이 렌더러와는 별개다.
//   · 기존 캠페인이 이 렌더러를 타지 않는다 — 신규 디자인(토큰/리비전)
//     전용이며, 연결(호출부 배선)은 4단계(에디터)에서 이루어진다.
//   · 원본 renderer.ts 를 그대로 복사하지 않는다 — 아래에 변경점을 기록한다.
//   · 이 파일은 파일시스템에 쓰지 않는다 — Buffer 만 반환한다(저장은 호출부
//     책임). 원본의 putImage() 는 이식하지 않는다.
//   · BokjuCouponDesignTemplate / BokjuCoupon* 모델을 이 파일에서 읽지
//     않는다 — partner.name 처럼 DB 조회가 필요한 값은 호출부가 미리 조회해
//     RenderContext 로 전달한다.
//
// ── 원본 대비 변경점(02c_2단계-결정사항.md 근거) ────────────────────────
//   1) qrPayload(redeemToken) → qrPayload(redeemToken, registerBaseUrl)
//      원본은 모듈 로드 시 고정되는 COUPON_BASE_URL/COUPON_QR_PATH(env)를
//      썼다. 실제 admin_web 은 발행 시점마다 resolvePublicOrigin(request)
//      로 origin 을 동적 계산(page-config-helpers.ts)하므로, 고정 env 값은
//      다중 도메인/스테이징에서 QR 을 깨뜨린다(§4 결정). registerBaseUrl 을
//      매개변수로 받아 호출부가 넘기도록 바꿨다. env 는 로컬 실행/테스트
//      폴백 기본값으로만 남긴다.
//   2) QR 목적지 경로를 '/c' → '/coupon' 으로 바꿨다. 기존
//      bokju-coupon-image-service.ts 의 qrUrl 생성 패턴
//      (`${registerBaseUrl}/coupon/${redeemToken}`, 448번 줄)과 실제 라우트
//      (src/app/coupon/[token]/page.tsx — OG 메타 + Flutter 앱 리다이렉트)
//      에 맞춘 것이다(§4 "QR 목적지 — 확인 완료").
//   3) 이미지 포맷을 jpeg 기본 → png 고정으로 바꿨다. 원본은
//      `IMAGE_FORMAT==='png' ? png : jpeg`(jpeg 기본)였으나, 운영 표준은
//      PNG(`bokju-coupon-image-service.ts` 의 `.png()` 고정)이므로 분기
//      자체를 제거했다(§0 참고 확인 사항).
//   4) 'partner.name' 바인딩을 추가했다. 값은 RenderContext.partnerName
//      (문자열 | undefined)으로 호출부가 주입한다. 값이 없으면(미배정 쿠폰)
//      그 텍스트 요소를 완전히 건너뛴다 — 원본에 없던 case 이며, 기존
//      bokju-coupon-image-service.ts 의 "partnerOrEventName 없으면
//      campaignTitle 로 대체"(600번 줄) 동작은 **따라가지 않는다**(§2 결정:
//      "제휴업체명 자리에 캠페인 제목을 인쇄하면 고객에게 사실과 다른
//      정보가 나간다").
//   5) 'campaign.ctaText' / 'brand.logo' 바인딩은 추가하지 않았다(§0/§1/§3
//      결정 — 2단계에서 손대지 않음, 4단계로 이월). BIND_SOURCES 에도 이
//      두 값은 없다(partner.name 만 추가됨, layout.ts 참고).
//   6) putImage() 는 이식하지 않았다 — 이 모듈은 Buffer 만 반환한다.
//
// ── 4단계 변경(02e_4단계-에디터.md §0-E — 필수 구조 분리) ─────────────────
//   "layout+theme → SVG 문자열" 순수 로직을 ./svg.ts 로 전부 옮겼다. 이유:
//   이 파일이 모듈 최상단에서 `sharp`(네이티브 바이너리)를 import 하므로
//   React 에디터(클라이언트)에서 그대로 import 하면 번들이 깨진다. QR 생성도
//   `QRCode.toBuffer()`(서버 전용)에 의존했다. 그대로 두면 "서버(여기) ·
//   목업(engine.js, 폐기 대상) · 신규 React" 로 렌더 로직이 3벌이 되어
//   완료기준 1("화면 SVG = 서버 SVG")을 구조적으로 보장할 수 없었다.
//
//   이제 이 파일은 **얇은 I/O 래퍼**다:
//     1) QR 페이로드 문자열을 만들고(qrPayload, 변경 없음)
//     2) QRCode.toBuffer() 로 실제 QR PNG 를 만들어 data URI 로 바꾸고
//     3) 레이아웃에 쓰인 이미지 자산(assetUrl/backgroundAssetUrl)을
//        toDataUri() 로 전부 미리 로딩해 **동기 조회용 Map** 을 만들고
//     4) ./svg.ts 의 순수 buildSvg(layout, ctx, { qrDataUri, resolveAsset })
//        를 호출해 SVG 문자열을 얻고
//     5) sharp 로 래스터화한다.
//   기존 export(buildSvg, renderCouponImage, renderOgImage, qrPayload,
//   wrapText)는 **시그니처를 그대로 유지**하며 re-export/래핑한다 — 기존
//   74건 테스트가 이 변경을 몰라도 그대로 통과해야 한다.
// ─────────────────────────────────────────────────────────────────────
import QRCode from 'qrcode';
import sharp from 'sharp';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import type { DesignLayout, LayoutElement } from './layout';
import { defaultLayout, resolveLayoutTheme } from './layout';
import { wrapText, buildSvg as buildSvgPure, type SvgRenderContext, type BuildSvgOptions } from './svg';

export interface RenderContext {
  campaign: {
    title: string;
    grantAmount: number;
    guideText?: string | null;
    validFrom: Date;
    validTo: Date;
  };
  coupon: { couponNo: string; redeemToken: string };
  /**
   * 브랜드 정보 — **표시 전용**(brand.domain 바인딩이 여기서 값을 가져온다.
   * 예: "sintong.kr 에서 바로 등록하세요"). QR·등록 URL 생성에는 절대 쓰지
   * 않는다 — 아래 registerBaseUrl 참고.
   *
   * [3단계 수정 — 사용자 지적 반영] 원래 이 domain 필드가 "표시"와
   * "URL 생성"(registerBaseUrlFrom 추론) 두 역할을 겸하고 있었다. 이는
   * 2단계 설계(참고 구현을 이식하며 그대로 가져온 구조)의 결함이었다 —
   * domain 에 origin 전체(scheme+host[:port])를 넣으면 화면에 "https://"
   * 나 "http://localhost:4300" 같은 문구가 그대로 인쇄된다. 역할을
   * 분리한다: brand.domain 은 사람이 읽는 짧은 도메인명만 담고, URL 생성은
   * 아래 registerBaseUrl 전용 필드가 전담한다.
   */
  brand?: { name: string; domain: string };
  /**
   * [3단계 신규] QR·coupon.registerUrl 바인딩 생성 **전용**. scheme·포트를
   * 그대로 보존해 호출부(dispatch.ts 등)가 넘긴 값 그대로 쓴다 — 이 값을
   * 추론하지 않는다(추론은 scheme 손실 버그의 원인이었다). 없으면
   * FALLBACK_BASE_URL 로 폴백한다(로컬 실행·테스트 전용 — 실제 발행
   * 경로는 항상 이 필드를 명시적으로 채워 넘겨야 한다).
   */
  registerBaseUrl?: string;
  /**
   * [2단계 신규] 제휴업체명. 호출부가 coupon.partnerId → BokjuPartner.name
   * 조회 결과를 여기에 담아 전달한다. 미배정 쿠폰(partnerId=null)이면
   * undefined 로 둔다 — 렌더러는 이 경우 해당 요소를 건너뛴다.
   */
  partnerName?: string;
}

// env 는 로컬 실행·테스트의 폴백 기본값일 뿐이다. 실제 발행 경로는 항상
// qrPayload() 에 registerBaseUrl 을 명시적으로 전달해야 한다(§4 결정).
const FALLBACK_BASE_URL = process.env.COUPON_BASE_URL ?? 'https://sintong.kr';
const BRAND_NAME = process.env.COUPON_BRAND ?? '신통방통';
const BRAND_DOMAIN = process.env.COUPON_DOMAIN ?? 'sintong.kr';
// 기존 등록 라우트(src/app/coupon/[token]/page.tsx)와 일치. 하드코딩된
// '/c' 는 쓰지 않는다 — 02b_지시서_2단계.md §0-1, step2-renderer.test.ts 57행 수정 대상.
// [4단계] ./svg.ts 의 'coupon.registerUrl' 바인딩도 같은 '/coupon' 을
// 하드코딩해 쓴다 — 두 상수가 어긋나면 "표시 문구"와 "QR 목적지"가
// 달라지므로, 바꿀 때는 반드시 두 파일을 함께 수정해야 한다.
const QR_PATH = '/coupon';

/**
 * QR 페이로드 — 개인정보가 들어가지 않는 유일한 식별자.
 * [변경] registerBaseUrl 을 필수 인자로 받는다(§4 결정). 생략 시
 * FALLBACK_BASE_URL(로컬/테스트 전용)을 쓴다.
 * [4단계] 시그니처·동작 변경 없음 — svg.ts 는 이 함수를 import 하지 않는다
 * (순수 모듈 원칙 — svg.ts 는 완성된 qrDataUri 만 주입받는다).
 */
export function qrPayload(redeemToken: string, registerBaseUrl: string = FALLBACK_BASE_URL): string {
  return `${registerBaseUrl}${QR_PATH}/${redeemToken}`;
}

// [4단계] wrapText 는 이제 ./svg.ts 의 구현을 그대로 재사용한다(로직이
// 100% 동일했으므로 중복 보관하지 않는다). 기존 호출부·테스트는
// renderer.ts 에서 import 하므로 re-export 로 하위호환을 유지한다.
export { wrapText };

// ────────────────────────────────────────────── 이미지 data URI (I/O 전용)
/**
 * [4단계 — svg.ts 로 이식하지 않은 이유] fetch/fs 를 쓰는 I/O 함수라
 * 순수 모듈(svg.ts)에는 둘 수 없다. renderer.ts(서버 전용)에만 남긴다.
 * svg.ts 의 BuildSvgOptions.resolveAsset 콜백 뒤에서 이 함수의 결과를
 * Map 으로 미리 채워 동기 조회만 하도록 연결한다(아래 preResolveAssets).
 */
async function toDataUri(src: string): Promise<string | null> {
  try {
    if (/^https?:\/\//.test(src)) {
      const res = await fetch(src);
      if (!res.ok) return null;
      const buf = Buffer.from(await res.arrayBuffer());
      return `data:${res.headers.get('content-type') ?? 'image/png'};base64,${buf.toString('base64')}`;
    }
    const p = path.isAbsolute(src) ? src : path.join(process.cwd(), src);
    if (!existsSync(p)) return null;
    const buf = await readFile(p);
    const ext = path.extname(p).toLowerCase().replace('.', '');
    const mime = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg';
    return `data:${mime};base64,${buf.toString('base64')}`;
  } catch {
    return null;
  }
}

/**
 * 레이아웃에 쓰인 모든 이미지 소스(요소 assetUrl/assetId + 캔버스 배경)를
 * 미리 비동기로 전부 로딩해 "원본 소스 → data URI" 동기 조회용 Map 을
 * 만든다. svg.ts 의 buildSvg() 는 동기 함수이므로(순수 모듈 — 네트워크
 * 호출을 품을 수 없다), I/O 는 반드시 호출 **전에** 끝내야 한다.
 */
async function preResolveAssets(layout: DesignLayout): Promise<Map<string, string>> {
  const sources = new Set<string>();
  if (layout.canvas.backgroundAssetUrl) sources.add(layout.canvas.backgroundAssetUrl);
  for (const el of layout.elements) {
    if (el.kind === 'image') {
      const src = el.assetUrl ?? el.assetId;
      if (src) sources.add(src);
    }
  }
  const map = new Map<string, string>();
  await Promise.all(
    [...sources].map(async (src) => {
      const uri = await toDataUri(src);
      if (uri) map.set(src, uri);
    }),
  );
  return map;
}

function registerBaseUrlFrom(ctx: RenderContext): string {
  return ctx.registerBaseUrl ?? FALLBACK_BASE_URL;
}

/** RenderContext → svg.ts 가 기대하는 SvgRenderContext 로 그대로 전달(구조적으로 동일). */
function toSvgContext(ctx: RenderContext): SvgRenderContext {
  return ctx;
}

/**
 * 레이아웃에 QR 요소가 하나라도 있으면 실제 QR PNG 를 생성해 data URI 로
 * 바꾼다. 없으면 undefined — svg.ts 가 QR 을 그릴 필요 자체가 없다.
 */
async function buildQrDataUri(layout: DesignLayout, ctx: RenderContext): Promise<string | undefined> {
  const qrEl: LayoutElement | undefined = layout.elements.find((e) => e.kind === 'qr' && e.visible !== false);
  if (!qrEl) return undefined;
  const size = qrEl.width ?? Math.round(layout.canvas.width * 0.42);
  const qrPng = await QRCode.toBuffer(qrPayload(ctx.coupon.redeemToken, registerBaseUrlFrom(ctx)), {
    type: 'png', margin: 1, width: size, errorCorrectionLevel: 'M',
  });
  return `data:image/png;base64,${qrPng.toString('base64')}`;
}

/**
 * 공개 API — 기존 시그니처(layout, ctx) 그대로 유지(하위호환, 74건 테스트
 * 보존). 내부적으로는 I/O(QR 생성·자산 로딩)를 먼저 끝낸 뒤 ./svg.ts 의
 * 순수 buildSvg() 를 호출하는 얇은 래퍼다(§0-E 지시 반영).
 *
 * [완료기준 1] 이 함수가 만드는 SVG 문자열은 "같은 qrDataUri·같은
 * resolveAsset 결과"를 넣고 ./svg.ts 의 buildSvg() 를 직접 호출했을 때와
 * **100% 동일**하다 — 같은 함수를 호출하기 때문이다(비교가 아니라 동일성
 * 자체가 설계로 보장된다).
 */
export async function buildSvg(layout: DesignLayout, ctx: RenderContext): Promise<string> {
  const [qrDataUri, assetMap] = await Promise.all([
    buildQrDataUri(layout, ctx),
    preResolveAssets(layout),
  ]);
  const opts: BuildSvgOptions = {
    qrDataUri,
    resolveAsset: (src) => assetMap.get(src) ?? null,
  };
  return buildSvgPure(layout, toSvgContext(ctx), opts);
}

// ────────────────────────────────────────────── 공개 API
/**
 * 쿠폰 1장 이미지 — 레이아웃 + 테마 그대로.
 * [변경] 포맷을 PNG 로 고정했다(§0 결정 — 운영 표준이 PNG). 원본의
 * IMAGE_FORMAT 분기(기본 jpeg)는 제거했다.
 */
export async function renderCouponImage(
  layout: DesignLayout | null,
  ctx: RenderContext,
): Promise<Buffer> {
  const use = layout ?? defaultLayout();
  const svg = await buildSvg(use, ctx);
  return sharp(Buffer.from(svg)).png().toBuffer();
}

/**
 * 공유 미리보기(OG) 이미지 1200×630.
 * 카카오톡 미리보기는 가로형 카드이므로 세로 쿠폰 이미지를 그대로 쓰면 잘린다.
 * 색은 캠페인 테마에서 가져와 쿠폰과 같은 인상을 유지한다.
 * [4단계] OG 이미지는 쿠폰 레이아웃과 무관한 고정 템플릿(1200×630 가로
 * 카드)이라 svg.ts 로 옮기지 않았다 — ./svg.ts 는 DesignLayout 기반
 * "쿠폰 레이아웃" 전용이며, 이 함수는 그 범위 밖이다(변경 없음).
 */
export async function renderOgImage(
  ctx: RenderContext,
  opts: { theme?: unknown; brand?: string } = {},
): Promise<Buffer> {
  const W = 1200, H = 630;
  const theme = resolveLayoutTheme({ theme: opts.theme as never });
  const brand = opts.brand ?? ctx.brand?.name ?? BRAND_NAME;
  const accent = theme.tokens.primary;
  const titleLines = wrapText(ctx.campaign.title, 58, W - 160, 2);
  const guide = (ctx.campaign.guideText ?? 'QR코드를 찍고 복주머니를 받으세요').slice(0, 40);

  const esc = (s: string): string =>
    s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[c] as string));

  const titleTspans = titleLines.map((ln, i) =>
    `<tspan x="80" y="${230 + i * 74}">${esc(ln)}</tspan>`).join('');

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${theme.tokens.surface}"/>
      <stop offset="100%" stop-color="${theme.tokens.surfaceAlt}"/>
    </linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#g)"/>
  <rect x="0" y="0" width="14" height="${H}" fill="${accent}"/>

  <text x="80" y="96" font-family="${esc(theme.fontStack)}" font-size="30" font-weight="700"
        letter-spacing="8" fill="${theme.tokens.primary}">${esc(brand)}</text>
  <text x="80" y="150" font-family="${esc(theme.fontStack)}" font-size="26" fill="${theme.tokens.inkMuted}">복주머니 선물 쿠폰</text>

  <text font-family="${esc(theme.fontStack)}" font-size="58" font-weight="800" fill="${theme.tokens.ink}">${titleTspans}</text>

  <text x="80" y="440" font-family="${esc(theme.fontStack)}" font-size="112" font-weight="800" fill="${accent}">${ctx.campaign.grantAmount}</text>
  <text x="${80 + String(ctx.campaign.grantAmount).length * 68 + 20}" y="440"
        font-family="${esc(theme.fontStack)}" font-size="38" font-weight="700" fill="${theme.tokens.inkMuted}">복주머니</text>

  <text x="80" y="510" font-family="${esc(theme.fontStack)}" font-size="28" fill="${theme.tokens.inkMuted}">${esc(guide)}</text>
  <text x="80" y="570" font-family="${esc(theme.fontStack)}" font-size="24" fill="${theme.tokens.inkSubtle}">${esc(ctx.brand?.domain ?? BRAND_DOMAIN)} 에서 바로 등록하세요</text>
</svg>`;

  return sharp(Buffer.from(svg)).jpeg({ quality: 88 }).toBuffer();
}

// [2단계] putImage() 는 이식하지 않는다. 이 모듈은 Buffer 만 반환하며,
// 저장은 호출부(기존 자산 경로/기존 스토리지 로직)가 책임진다
// (02b_지시서_2단계.md §2 절대불가침 — "렌더러가 파일시스템에 직접 쓰기 금지").
