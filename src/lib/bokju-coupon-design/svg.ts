// src/lib/bokju-coupon-design/svg.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 4단계: 순수 SVG 빌더 (서버 · 클라이언트 공용)
//
// [4단계 — 02e_4단계-에디터.md §0-E 지시] 완료기준 1("같은 레이아웃 → 화면
//   SVG 와 서버 SVG 좌표·색 동일")을 구조적으로 보장하기 위해, 기존
//   renderer.ts 의 buildSvg() 가 품고 있던 "layout+theme → SVG 문자열"
//   순수 로직을 이 파일로 분리한다.
//
// ── 분리 이유(사용자 지적 원문 요지) ────────────────────────────────────
//   renderer.ts 는 모듈 최상단에서 `sharp`(네이티브 바이너리)를 import 한다
//   → 클라이언트(React 에디터)에서 그대로 import 하면 번들 실패.
//   QR 은 renderer.ts 안에서 `QRCode.toBuffer()`(서버 전용)로 생성한다.
//   목업은 별도로 CDN `qrcode-generator` 로 브라우저에서 QR 을 그렸다.
//   → 이대로 두면 "서버(renderer.ts) · 목업(engine.js) · 신규 React" 로
//     렌더 로직이 3벌이 되어 반드시 어긋난다.
//
// ── 이 파일의 절대 규칙 ─────────────────────────────────────────────────
//   · `sharp` · `node:fs` · `node:fs/promises` · `qrcode` 를 import 하지
//     않는다. 네트워크(`fetch`)도 호출하지 않는다 — 전부 **주입**받는다.
//   · 오직 './layout' 과 './theme' 만 의존한다 (둘 다 1단계 승인 순수 모듈,
//     zod 스키마 + 색상 계산 로직뿐이라 브라우저에서도 안전하게 동작한다).
//   · QR 이미지는 완성된 data URI(`opts.qrDataUri`)를 주입받는다. 없으면
//     QR 자리에 "같은 크기의 자리표시 사각형"을 그린다(§0-E: "드래그 중
//     클라이언트가 사용"). 자리표시는 점선 테두리 + QR 텍스트 라벨로,
//     진짜 QR 이미지와 혼동되지 않게 한다.
//   · 이미지 요소(kind='image')·캔버스 배경 이미지(backgroundAssetUrl) 도
//     같은 원칙을 따른다 — data URI 로딩(fetch/fs)은 순수 모듈의 책임이
//     아니므로, 호출부가 `opts.resolveAsset(src)` 콜백으로 이미 로딩된
//     data URI(또는 그대로 쓸 수 있는 URL)를 돌려주게 한다. 콜백이 없거나
//     null 을 반환하면 기존과 동일한 "자리 표시 사각형" 폴백을 그린다
//     (renderer.ts 의 기존 동작과 100% 동일 — 02c §2 결정 보존).
//
// ── renderer.ts 와의 관계 ────────────────────────────────────────────────
//   renderer.ts 는 이제 "얇은 I/O 래퍼"가 된다: 실제 QR PNG 를
//   QRCode.toBuffer() 로 생성해 data URI 화하고, 이미지 자산은 기존
//   toDataUri()(fetch/fs)로 로딩한 뒤, 이 파일의 buildSvg() 를 호출해
//   최종 SVG 문자열을 만들고 sharp 로 래스터화한다. renderer.ts 의 기존
//   export(buildSvg, renderCouponImage, renderOgImage, qrPayload,
//   wrapText 등)는 전부 그대로 유지된다 — 기존 74건 테스트가 이 파일의
//   존재를 몰라도 깨지지 않는다(re-export 패턴).
//
// ── 완료기준 1 검증 방법(§0-E) ────────────────────────────────────────────
//   같은 layout + 같은 qrDataUri 를 넣고 **이 파일의 buildSvg() 를 서버와
//   클라이언트에서 각각 호출**하면 문자열이 완전히 같아야 한다(100% 같은
//   모듈을 쓰므로 자명하게 같다 — "눈으로 비교"가 아니라 "같은 코드를
//   실행했다"는 사실 자체가 증거다). QR 생성 알고리즘 차이(바이트 차이)는
//   qrDataUri 를 외부에서 동일하게 주입함으로써 애초에 비교 대상에서
//   제외된다.
// ─────────────────────────────────────────────────────────────────────
import type { DesignLayout, LayoutElement } from './layout';
import { defaultLayout, resolveLayoutTheme } from './layout';
import { tokenColor, ensureContrast, type ResolvedTheme } from './theme';

/**
 * buildSvg() 가 값 바인딩에 필요로 하는 최소 데이터.
 * renderer.ts 의 RenderContext 와 필드가 같다 — 이 파일은 타입만 복제해
 * renderer.ts 에 대한 import 의존을 만들지 않는다(순환 참조 방지 및
 * "순수 모듈은 다른 모듈을 끌어오지 않는다"는 원칙 유지). renderer.ts 쪽
 * RenderContext 는 이 타입과 구조적으로 호환되므로 그대로 넘길 수 있다.
 */
export interface SvgRenderContext {
  campaign: {
    title: string;
    grantAmount: number;
    guideText?: string | null;
    validFrom: Date;
    validTo: Date;
  };
  coupon: { couponNo: string; redeemToken: string };
  brand?: { name: string; domain: string };
  registerBaseUrl?: string;
  partnerName?: string;
}

/**
 * buildSvg() 의 선택 옵션 — I/O 가 필요한 값을 **주입**받는 통로.
 * 이 파일 자신은 네트워크/파일시스템을 전혀 건드리지 않는다.
 */
export interface BuildSvgOptions {
  /**
   * 완성된 QR 이미지의 data URI(`data:image/png;base64,...`).
   * 없으면(undefined/null) QR 자리에 같은 크기의 자리표시 사각형을 그린다
   * — 드래그 중인 클라이언트 에디터가 쓰는 경로다.
   */
  qrDataUri?: string | null;
  /**
   * 이미지 요소(kind='image')·캔버스 배경 이미지의 원본 경로(src)를 받아
   * 화면에 바로 쓸 수 있는 data URI(또는 URL)를 돌려주는 콜백. 생략하거나
   * null/undefined 를 반환하면 자리표시 사각형으로 폴백한다(기존
   * renderer.ts 의 toDataUri() 실패 시 동작과 동일).
   *
   * 서버(renderer.ts): fetch/fs 기반 toDataUri() 를 그대로 연결한다.
   * 클라이언트(React 에디터): 업로드된 파일의 blob: URL 이나 이미 받아둔
   * data URI 를 그대로 돌려주면 된다 — 네트워크 호출이 필요 없다.
   */
  resolveAsset?: (src: string) => string | null;
}

const DEFAULT_BRAND_DOMAIN = 'sintong.kr';

// ────────────────────────────────────────────── 값 바인딩
function resolveText(el: LayoutElement, ctx: SvgRenderContext): string {
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
    case 'brand.domain': return ctx.brand?.domain ?? DEFAULT_BRAND_DOMAIN;
    case 'coupon.registerUrl': {
      // [renderer.ts 와 동일한 QR_PATH('/coupon')를 쓴다 — 이 상수가
      // 양쪽에서 달라지면 "등록 URL 표시 문구"와 "QR 이 가리키는 주소"가
      // 어긋난다. registerBaseUrl 은 QR·등록URL 생성 전용(brand.domain 은
      // 표시 전용) — renderer.ts RenderContext 주석과 동일한 설계.]
      const base = ctx.registerBaseUrl ?? `https://${DEFAULT_BRAND_DOMAIN}`;
      return `${base}/coupon/${ctx.coupon.redeemToken}`;
    }
    case 'coupon.qr': return '';
    case 'partner.name': return ctx.partnerName ?? '';
    default: return '';
  }
}

// ────────────────────────────────────────────── 텍스트 줄바꿈
/**
 * SVG 는 자동 줄바꿈이 없다. 폭을 추정해 직접 나눈다.
 * 한글/한자/기호 = 1em, 그 외(라틴·숫자) = 0.55em 로 근사한다.
 * [renderer.ts 와 완전히 동일한 알고리즘 — 글자 수 기반 폭 추정이므로
 * 순수 함수로 그대로 옮길 수 있다. renderer.ts 는 이 함수를 re-export 한다.]
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
 * [renderer.ts 와 동일 — layout/theme 만 쓰는 순수 계산이라 그대로 이식.]
 */
function backdropFor(el: LayoutElement, layout: DesignLayout, theme: ResolvedTheme): string {
  const canvasBg = tokenColor(theme, layout.canvas.backgroundToken, layout.canvas.background);
  const boxes = layout.elements
    .filter((e) => e.kind === 'box' && e.visible !== false && e.z < el.z)
    .sort((a, b) => b.z - a.z);
  for (const b of boxes) {
    const w = b.width ?? 0, h = b.height ?? 0;
    if (w > 0 && h > 0 && Math.abs(el.x - b.x) <= w / 2 && Math.abs(el.y - b.y) <= h / 2) {
      return tokenColor(theme, b.fillToken, b.fill ?? theme.tokens.surface);
    }
  }
  return canvasBg;
}

/** 자리표시(placeholder) 사각형 — 자산/QR 이 아직 없을 때 공통으로 쓴다. */
function placeholderRect(
  x: number, y: number, w: number, h: number, rx: number, theme: ResolvedTheme,
  rotate: string, label?: string,
): string {
  const labelSvg = label
    ? `<text x="${x}" y="${y}" text-anchor="middle" dominant-baseline="middle"
        font-size="${Math.max(10, Math.min(w, h) * 0.12)}" fill="${theme.tokens.inkSubtle}">${esc(label)}</text>`
    : '';
  return `<g${rotate}>
    <rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${rx}"
      fill="${theme.tokens.surfaceAlt}" stroke="${theme.tokens.line}" stroke-dasharray="10 8"/>
    ${labelSvg}
  </g>`;
}

function elementSvg(
  el: LayoutElement, ctx: SvgRenderContext, layout: DesignLayout, theme: ResolvedTheme,
  opts: BuildSvgOptions,
): string {
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
      const uri = src ? (opts.resolveAsset?.(src) ?? null) : null;
      if (!uri) {
        // 소스가 없거나(resolveAsset 미주입/실패) 아직 첨부 전 — 자리 표시.
        // [renderer.ts 의 기존 "소스 없으면 자리 표시" 동작과 동일 — 02c §2]
        return `<rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${el.radius ?? 0}"
          fill="${theme.tokens.surfaceAlt}" stroke="${theme.tokens.line}" stroke-dasharray="10 8"${rotate}/>`;
      }
      return `<image x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}"
        preserveAspectRatio="${el.fit === 'cover' ? 'xMidYMid slice' : 'xMidYMid meet'}"
        href="${uri}"${opacity}${rotate}/>`;
    }
    case 'qr': {
      const size = el.width ?? Math.round(layout.canvas.width * 0.42);
      const pad = Math.round(size * 0.06);
      if (!opts.qrDataUri) {
        // [§0-E 지시 — "qrDataUri 없으면 QR 자리에 같은 크기의 자리표시
        // 사각형" — 드래그 중인 클라이언트가 쓰는 경로. 실제 QR 과 혼동되지
        // 않도록 "QR" 라벨을 넣는다.]
        return placeholderRect(x, y, size + pad * 2, size + pad * 2, 24, theme, rotate, 'QR');
      }
      // ★ QR 은 항상 흰 판 위 — 다크 팔레트에서도 스캐너가 읽을 수 있어야 한다
      return `<g${rotate}>
        <rect x="${x - size / 2 - pad}" y="${y - size / 2 - pad}"
              width="${size + pad * 2}" height="${size + pad * 2}" rx="24"
              fill="#ffffff" stroke="${theme.tokens.line}"/>
        <image x="${x - size / 2}" y="${y - size / 2}" width="${size}" height="${size}"
               href="${opts.qrDataUri}"/>
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

/**
 * 순수 SVG 빌더 — 서버 · 클라이언트(React 에디터) 공용.
 * `sharp` · `node:fs` · `qrcode` 를 import 하지 않는다(§0-E 필수 조건).
 *
 * @param opts.qrDataUri  완성된 QR data URI. 없으면 자리표시 사각형.
 * @param opts.resolveAsset  이미지 소스 → data URI(또는 URL) 변환 콜백.
 */
export function buildSvg(
  layout: DesignLayout,
  ctx: SvgRenderContext,
  opts: BuildSvgOptions = {},
): string {
  const { width: W, height: H } = layout.canvas;
  const theme = resolveLayoutTheme(layout);
  const parts: string[] = [];

  const bgSrc = layout.canvas.backgroundAssetUrl;
  const bgUri = bgSrc ? (opts.resolveAsset?.(bgSrc) ?? null) : null;
  parts.push(
    bgUri
      ? `<image x="0" y="0" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice" href="${bgUri}"/>`
      : `<rect width="${W}" height="${H}" fill="${tokenColor(theme, layout.canvas.backgroundToken, layout.canvas.background)}"/>`,
  );

  const ordered = [...layout.elements].sort((a, b) => a.z - b.z);
  for (const el of ordered) parts.push(elementSvg(el, ctx, layout, theme, opts));

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${parts.join('')}</svg>`;
}

// 편의 re-export — renderer.ts/에디터가 "레이아웃 없음" 기본값이 필요할 때
// layout.ts 를 또 import 하지 않아도 되게 한다(선택적 편의, 필수 아님).
export { defaultLayout };
