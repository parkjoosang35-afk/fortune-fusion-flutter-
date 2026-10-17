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
// ─────────────────────────────────────────────────────────────────────
import QRCode from 'qrcode';
import sharp from 'sharp';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import type { DesignLayout, LayoutElement } from './layout';
import { defaultLayout, resolveLayoutTheme } from './layout';
import { tokenColor, ensureContrast, type ResolvedTheme } from './theme';

export interface RenderContext {
  campaign: {
    title: string;
    grantAmount: number;
    guideText?: string | null;
    validFrom: Date;
    validTo: Date;
  };
  coupon: { couponNo: string; redeemToken: string };
  /** 브랜드 정보 — 도메인 요소(brand.domain)가 여기서 값을 가져온다 */
  brand?: { name: string; domain: string };
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
const QR_PATH = '/coupon';

/**
 * QR 페이로드 — 개인정보가 들어가지 않는 유일한 식별자.
 * [변경] registerBaseUrl 을 필수 인자로 받는다(§4 결정). 생략 시
 * FALLBACK_BASE_URL(로컬/테스트 전용)을 쓴다.
 */
export function qrPayload(redeemToken: string, registerBaseUrl: string = FALLBACK_BASE_URL): string {
  return `${registerBaseUrl}${QR_PATH}/${redeemToken}`;
}

// ────────────────────────────────────────────── 값 바인딩
function resolveText(el: LayoutElement, ctx: RenderContext): string {
  switch (el.bind) {
    case 'static': return el.text ?? '';
    case 'campaign.title': return ctx.campaign.title;
    case 'campaign.grantAmount': return String(ctx.campaign.grantAmount);
    case 'campaign.guideText': return ctx.campaign.guideText ?? '';
    case 'campaign.validPeriod': {
      const f = (d: Date) => d.toISOString().slice(0, 10).replace(/-/g, '.');
      return `${f(ctx.campaign.validFrom)} ~ ${f(ctx.campaign.validTo)}`;
    }
    case 'coupon.couponNo': return ctx.coupon.couponNo;
    case 'brand.domain': return ctx.brand?.domain ?? BRAND_DOMAIN;
    case 'coupon.registerUrl':
      return `${(ctx.brand?.domain ?? BRAND_DOMAIN)}${QR_PATH}/${ctx.coupon.redeemToken}`;
    case 'coupon.qr': return '';
    // [2단계 신규] 값이 없으면 빈 문자열 — elementSvg() 가 빈 문자열이면
    // 렌더를 건너뛰므로(원본과 동일한 '빈 텍스트는 스킵' 규칙), 별도 분기
    // 없이 campaignTitle 대체 없는 "건너뛰기"가 자동으로 성립한다.
    case 'partner.name': return ctx.partnerName ?? '';
    default: return '';
  }
}

// ────────────────────────────────────────────── 텍스트 줄바꿈
/**
 * SVG 는 자동 줄바꿈이 없다. 폭을 추정해 직접 나눈다.
 * 한글/한자/기호 = 1em, 그 외(라틴·숫자) = 0.55em 로 근사한다.
 */
export function wrapText(text: string, fontSize: number, maxWidth: number, maxLines = 3): string[] {
  const widthOf = (s: string) =>
    [...s].reduce((acc, ch) => acc + (/[\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF]/.test(ch) ? fontSize : fontSize * 0.55), 0);

  const lines: string[] = [];
  let current = '';
  for (const ch of text) {
    if (ch === '\n') { lines.push(current); current = ''; continue; }
    const next = current + ch;
    if (widthOf(next) > maxWidth && current.length > 0) {
      lines.push(current);
      current = ch;
    } else {
      current = next;
    }
    if (lines.length >= maxLines) break;
  }
  if (current && lines.length < maxLines) lines.push(current);
  if (lines.length === maxLines && widthOf(lines[maxLines - 1]) < widthOf(text)) {
    let last = lines[maxLines - 1];
    while (last.length > 1 && widthOf(last + '…') > maxWidth) last = last.slice(0, -1);
    lines[maxLines - 1] = last + '…';
  }
  return lines;
}

// ────────────────────────────────────────────── 이미지 data URI
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

// ────────────────────────────────────────────── SVG 생성
function esc(s: string): string {
  return s.replace(/[<>&'"]/g, (c) =>
    ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[c] as string));
}

function textAnchor(align?: string): string {
  return align === 'left' ? 'start' : align === 'right' ? 'end' : 'middle';
}

/**
 * 이 요소 뒤에 실제로 깔리는 색.
 * 아래 레이어의 박스가 이 위치를 덮고 있으면 그 색, 아니면 캔버스 배경.
 * 글자 대비를 "진짜 배경" 기준으로 재기 위해 필요하다.
 */
function backdropFor(el: LayoutElement, layout: DesignLayout, theme: ResolvedTheme): string {
  const canvasBg = tokenColor(theme, layout.canvas.backgroundToken, layout.canvas.background);
  const boxes = layout.elements
    .filter((e) => e.kind === 'box' && e.visible !== false && e.z < el.z)
    .sort((a, b) => b.z - a.z);                      // 위에 깔린 것부터 본다
  for (const b of boxes) {
    const w = b.width ?? 0, h = b.height ?? 0;
    if (w > 0 && h > 0 && Math.abs(el.x - b.x) <= w / 2 && Math.abs(el.y - b.y) <= h / 2) {
      return tokenColor(theme, b.fillToken, b.fill ?? theme.tokens.surface);
    }
  }
  return canvasBg;
}

/**
 * [2단계 신규 헬퍼] 렌더 컨텍스트에서 QR 목적지에 쓸 registerBaseUrl 을 뽑는다.
 * RenderContext 자체엔 registerBaseUrl 필드가 없다(브랜드 도메인과 등록
 * origin 은 다른 개념일 수 있으므로 섞지 않는다) — brand.domain 이 있으면
 * `https://{domain}` 형태로 구성하고, 없으면 FALLBACK_BASE_URL 을 쓴다.
 * 실제 발행 경로는 이 폴백을 타지 않도록, 호출부가 buildSvg/renderCouponImage
 * 호출 전에 registerBaseUrl 을 ctx.brand.domain 에 반영해 와야 한다.
 */
function registerBaseUrlFrom(ctx: RenderContext): string {
  const domain = ctx.brand?.domain;
  if (!domain) return FALLBACK_BASE_URL;
  return /^https?:\/\//.test(domain) ? domain : `https://${domain}`;
}

async function elementSvg(
  el: LayoutElement, ctx: RenderContext, layout: DesignLayout, theme: ResolvedTheme,
): Promise<string> {
  if (el.visible === false) return '';
  const { x, y } = el;
  const rotate = el.rotation ? ` transform="rotate(${el.rotation} ${x} ${y})"` : '';
  const opacity = el.opacity !== undefined ? ` opacity="${el.opacity}"` : '';
  const dash = el.dash ? ` stroke-dasharray="${esc(el.dash)}"` : '';

  switch (el.kind) {
    case 'box': {
      const w = el.width ?? 100, h = el.height ?? 100;
      const rx = el.radius ?? 0;
      const fill = tokenColor(theme, el.fillToken, el.fill ?? theme.tokens.surface);
      const stroke = el.strokeToken || el.stroke
        ? tokenColor(theme, el.strokeToken, el.stroke ?? theme.tokens.line) : null;
      return `<rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${rx}"
        fill="${fill}"${stroke ? ` stroke="${stroke}" stroke-width="${el.strokeWidth ?? 2}"${dash}` : ''}${opacity}${rotate}/>`;
    }
    case 'line': {
      const w = el.width ?? 100;
      const stroke = tokenColor(theme, el.strokeToken, el.stroke ?? el.fill ?? theme.tokens.line);
      return `<line x1="${x - w / 2}" y1="${y}" x2="${x + w / 2}" y2="${y}"
        stroke="${stroke}" stroke-width="${el.strokeWidth ?? 2}"${dash}${opacity}${rotate}/>`;
    }
    case 'image': {
      const w = el.width ?? 300, h = el.height ?? 300;
      const src = el.assetUrl ?? el.assetId;
      const uri = src ? await toDataUri(src) : null;
      if (!uri) {
        // 소스가 없으면 자리 표시 — 발행 전에 검수에서 걸러지도록 눈에 띄게 남긴다
        return `<rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${el.radius ?? 0}"
          fill="${theme.tokens.surfaceAlt}" stroke="${theme.tokens.line}" stroke-dasharray="10 8"${rotate}/>`;
      }
      return `<image x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}"
        preserveAspectRatio="${el.fit === 'cover' ? 'xMidYMid slice' : 'xMidYMid meet'}"
        href="${uri}"${opacity}${rotate}/>`;
    }
    case 'qr': {
      const size = el.width ?? Math.round(layout.canvas.width * 0.42);
      const qrPng = await QRCode.toBuffer(qrPayload(ctx.coupon.redeemToken, registerBaseUrlFrom(ctx)), {
        type: 'png', margin: 1, width: size, errorCorrectionLevel: 'M',
      });
      const pad = Math.round(size * 0.06);
      // ★ QR 은 항상 흰 판 위 — 다크 팔레트에서도 스캐너가 읽을 수 있어야 한다
      return `<g${rotate}>
        <rect x="${x - size / 2 - pad}" y="${y - size / 2 - pad}"
              width="${size + pad * 2}" height="${size + pad * 2}" rx="24"
              fill="#ffffff" stroke="${theme.tokens.line}"/>
        <image x="${x - size / 2}" y="${y - size / 2}" width="${size}" height="${size}"
               href="data:image/png;base64,${qrPng.toString('base64')}"/>
      </g>`;
    }
    case 'text': {
      const raw = resolveText(el, ctx);
      if (!raw) return '';
      const fs = (el.fontSize ?? layout.canvas.width * 0.04) * theme.textScale;
      const align = el.align ?? 'center';
      const lh = (el.lineHeight ?? 1.35) * fs;
      const margin = Math.round(layout.canvas.width * 0.06);
      const maxWidth = Math.min(
        el.width ?? layout.canvas.width - margin * 2,
        layout.canvas.width - margin,
      );
      const lines = wrapText(raw, fs, maxWidth, el.maxLines ?? 1);
      const startY = y - ((lines.length - 1) * lh) / 2 + fs * 0.35;
      const tspans = lines.map((ln, i) =>
        `<tspan x="${x}" y="${startY + i * lh}">${esc(ln)}</tspan>`).join('');

      // ★ 대비 보정 — 실제 배경을 기준으로 잰다
      let color = tokenColor(theme, el.colorToken, el.color ?? theme.tokens.ink);
      if (theme.autoContrast) {
        color = ensureContrast(color, backdropFor(el, layout, theme), 4.5).color;
      }

      return `<text text-anchor="${textAnchor(align)}" font-family="${esc(theme.fontStack)}"
        font-size="${fs}" font-weight="${el.fontWeight ?? 400}" fill="${color}"
        letter-spacing="${el.letterSpacing ?? 0}"${opacity}${rotate}>${tspans}</text>`;
    }
    default: return '';
  }
}

export async function buildSvg(layout: DesignLayout, ctx: RenderContext): Promise<string> {
  const { width: W, height: H } = layout.canvas;
  const theme = resolveLayoutTheme(layout);
  const parts: string[] = [];

  const bgAsset = layout.canvas.backgroundAssetUrl
    ? await toDataUri(layout.canvas.backgroundAssetUrl) : null;
  parts.push(
    bgAsset
      ? `<image x="0" y="0" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice" href="${bgAsset}"/>`
      : `<rect width="${W}" height="${H}" fill="${tokenColor(theme, layout.canvas.backgroundToken, layout.canvas.background)}"/>`,
  );

  const ordered = [...layout.elements].sort((a, b) => a.z - b.z);
  for (const el of ordered) parts.push(await elementSvg(el, ctx, layout, theme));

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${parts.join('')}</svg>`;
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
