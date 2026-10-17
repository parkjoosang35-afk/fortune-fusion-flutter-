// scripts/verify_criterion1_client_server_svg_match.ts
// ─────────────────────────────────────────────────────────────────────
// [4단계 완료기준 1 — 02e_4단계-에디터.md §0-E "완료기준 1 검증 방법"]
//
//   "같은 layout + 같은 qrDataUri 로:
//      클라이언트 svg.ts 결과  ===  서버 svg.ts 결과   (문자열 완전 일치)"
//
// 이 스크립트는 그 비교를 실제로 수행한다. QR 바이트 생성 알고리즘 차이는
// "알려진 차이"로 명시적으로 배제하고(§0-E), 레이아웃·좌표·색·토큰·
// 대비보정 로직이 100% 동일한지를 "같은 qrDataUri 주입" 방식으로 검증한다.
//
// ── 무엇을 "클라이언트"로 보는가 ─────────────────────────────────────────
//   src/lib/bokju-coupon-design/svg.ts 는 sharp·node:fs·qrcode 를 import
//   하지 않는 순수 모듈이다(§0-E 필수 조건) — 즉 이 모듈은 "브라우저에서도
//   그대로 동작 가능"하다. 이 스크립트에서 "클라이언트 경로"란 이 svg.ts의
//   buildSvg() 를 **직접** 호출하는 것을 뜻한다(실행 환경이 Node 인 것은
//   테스트 하네스의 제약일 뿐, svg.ts 코드 자체는 import 제약을 만족한다
//   — 아래 [검증 A]가 이를 별도로 확인한다).
//
// ── 무엇을 "서버"로 보는가 ───────────────────────────────────────────────
//   renderer.ts 의 buildSvg(layout, ctx) — 실제 발행 경로
//   (dispatchCouponRender → renderCouponImage → 이 함수)가 쓰는 바로 그
//   함수다. 내부적으로 QR PNG 를 생성하고 자산을 로딩한 뒤 svg.ts 의
//   buildSvg() 를 호출한다(이제는 얇은 I/O 래퍼 — §0-E 리팩토링 결과).
//
// ── 검증 전략 ─────────────────────────────────────────────────────────
//   1) 서버가 내부적으로 생성할 QR payload/옵션과 **완전히 동일한 입력**으로
//      이 스크립트가 QR PNG 를 직접 생성해 qrDataUri 를 만든다(QRCode 는
//      결정론적 — 같은 입력 → 같은 바이트, 이것 자체도 별도로 검증한다).
//   2) "클라이언트" 경로: svg.ts 의 buildSvg(layout, ctx, { qrDataUri }) 를
//      직접 호출 → svgClient
//   3) "서버" 경로: renderer.ts 의 buildSvg(layout, ctx) 를 호출 → svgServer
//      (내부에서 동일 payload/옵션으로 자체적으로 QR 을 생성하므로, QR 이
//      결정론적이라면 byte-identical 한 data URI 가 나와야 한다)
//   4) svgClient === svgServer 문자열 완전 일치를 단언한다.
//   5) 이미지 요소(자산) 바인딩도 같은 원칙으로 검증한다 — 같은 data URI 를
//      양쪽에 주입(client: svg.ts 직접, server: renderer.ts 내부 toDataUri
//      결과)했을 때 레이아웃 좌표·fit 처리가 동일한지 확인한다. 파일시스템
//      자산을 실제로 준비해 renderer.ts 의 toDataUri() 경로까지 태운다.
//   6) [검증 A] svg.ts 소스 코드에 금지된 import(sharp/qrcode/node:fs)가
//      없음을 소스 레벨로 직접 확인한다 — "클라이언트에서 import 가능"의
//      구조적 증거.
// ─────────────────────────────────────────────────────────────────────
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import QRCode from "qrcode";

import { buildSvg as buildSvgClient, type SvgRenderContext } from "../src/lib/bokju-coupon-design/svg";
import { buildSvg as buildSvgServer, qrPayload } from "../src/lib/bokju-coupon-design/renderer";
import { defaultLayout, addElement, CANVAS_PRESETS } from "../src/lib/bokju-coupon-design/layout";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(`[FAIL] ${msg}`);
  console.log(`[OK] ${msg}`);
}

async function main() {
  console.log("=== 완료기준 1 검증 — 같은 qrDataUri 로 클라이언트 svg.ts === 서버 svg.ts(renderer.ts 경유) ===\n");

  // ── [검증 A] svg.ts 소스에 금지된 import 가 없다 (클라이언트 번들 가능성의 구조적 증거) ──
  console.log("--- [검증 A] svg.ts 는 sharp/qrcode/node:fs 를 import 하지 않는다 ---");
  const svgSource = readFileSync(
    path.join(process.cwd(), "src/lib/bokju-coupon-design/svg.ts"),
    "utf-8",
  );
  const forbiddenPatterns: Array<{ name: string; re: RegExp }> = [
    { name: "sharp", re: /from\s+['"]sharp['"]/ },
    { name: "qrcode", re: /from\s+['"]qrcode['"]/ },
    { name: "node:fs", re: /from\s+['"]node:fs(\/promises)?['"]/ },
    { name: "fetch 호출", re: /\bfetch\(/ },
  ];
  for (const { name, re } of forbiddenPatterns) {
    assert(!re.test(svgSource), `svg.ts 는 '${name}' 를 import/호출하지 않는다`);
  }
  // 참고용 양성 확인: renderer.ts 는 여전히 sharp 를 쓴다(= I/O 래퍼로 남아있음)
  const rendererSource = readFileSync(
    path.join(process.cwd(), "src/lib/bokju-coupon-design/renderer.ts"),
    "utf-8",
  );
  assert(/from\s+['"]sharp['"]/.test(rendererSource), "renderer.ts 는 여전히 sharp 를 import 한다(I/O 래퍼로 남아있다는 증거)");
  assert(/from\s+['"]qrcode['"]/.test(rendererSource), "renderer.ts 는 여전히 qrcode 를 import 한다(실제 QR 생성은 서버 전용)");

  // ── 공통 테스트 데이터 ──
  const ctx: SvgRenderContext = {
    campaign: {
      title: "신통방통 복주머니 선물 — 완료기준1 검증",
      grantAmount: 500,
      guideText: "QR코드를 찍고 복주머니를 받으세요",
      validFrom: new Date("2026-11-01T00:00:00Z"),
      validTo: new Date("2026-12-31T23:59:59Z"),
    },
    coupon: { couponNo: "ST-CRIT1-0001-AB", redeemToken: "c".repeat(32) },
    brand: { name: "신통방통", domain: "sintong.kr" },
    registerBaseUrl: "https://coupon-studio-crit1.example",
  };
  const layout = defaultLayout();

  // ── [검증 B] QR 생성이 결정론적이다 (같은 입력 → 같은 바이트) ──
  console.log("\n--- [검증 B] QRCode.toBuffer 는 같은 입력에 대해 결정론적이다 ---");
  const qrEl = layout.elements.find((e) => e.kind === "qr")!;
  const size = qrEl.width ?? Math.round(layout.canvas.width * 0.42);
  const payload = qrPayload(ctx.coupon.redeemToken, ctx.registerBaseUrl);
  const qrOpts = { type: "png" as const, margin: 1, width: size, errorCorrectionLevel: "M" as const };
  const qrPng1 = await QRCode.toBuffer(payload, qrOpts);
  const qrPng2 = await QRCode.toBuffer(payload, qrOpts);
  assert(qrPng1.equals(qrPng2), "동일 payload+옵션으로 2회 생성한 QR PNG 바이트가 완전히 같다(결정론적)");
  const qrDataUri = `data:image/png;base64,${qrPng1.toString("base64")}`;

  // ── [검증 C] 핵심 — 같은 qrDataUri 를 주입했을 때 클라이언트/서버 SVG 문자열 완전 일치 ──
  console.log("\n--- [검증 C] 핵심: 같은 qrDataUri 로 클라이언트(svg.ts 직접) === 서버(renderer.ts 경유) ---");
  // "클라이언트" — svg.ts 의 buildSvg() 를 직접 호출(동기, 순수 함수)
  const svgClient = buildSvgClient(layout, ctx, { qrDataUri });

  // "서버" — renderer.ts 의 buildSvg(layout, ctx) 를 호출. 내부적으로
  // registerBaseUrlFrom(ctx) + qrPayload() 로 **동일한 payload** 를 만들고
  // **동일한 QR 옵션**으로 QRCode.toBuffer() 를 호출하므로(검증 B 에 의해
  // 결정론적), byte-identical 한 qrDataUri 가 나와야 한다.
  const svgServer = await buildSvgServer(layout, ctx);

  assert(svgClient.length > 0 && svgServer.length > 0, "양쪽 모두 비어있지 않은 SVG 문자열을 생성했다");
  assert(svgClient === svgServer, "클라이언트(svg.ts 직접 호출)와 서버(renderer.ts 경유) SVG 문자열이 완전히 일치한다 (글자 단위 동일)");

  // ── [검증 D] 의도적으로 다른 qrDataUri 를 주면 불일치가 나야 한다 (검증 C 가 "항상 통과"하는 가짜 테스트가 아님을 보증) ──
  console.log("\n--- [검증 D] 음성 대조군 — 다른 qrDataUri 를 쓰면 문자열이 달라진다(검증 C 가 유의미함을 보증) ---");
  const differentQr = `data:image/png;base64,${Buffer.from("not-a-real-qr").toString("base64")}`;
  const svgClientDifferent = buildSvgClient(layout, ctx, { qrDataUri: differentQr });
  assert(svgClientDifferent !== svgServer, "다른 qrDataUri 를 주입하면 SVG 문자열이 달라진다 (검증 C 의 '일치'가 우연이 아님을 증명)");

  // ── [검증 E] qrDataUri 가 없을 때(클라이언트 드래그 중) — 자리표시 사각형 ──
  console.log("\n--- [검증 E] qrDataUri 없이 호출하면(드래그 중 시뮬레이션) 자리표시 사각형을 그린다 ---");
  const svgDragging = buildSvgClient(layout, ctx, {});
  assert(!svgDragging.includes(qrDataUri), "qrDataUri 미주입 시 실제 QR data URI 가 들어가지 않는다");
  assert(svgDragging.includes('stroke-dasharray="10 8"'), "qrDataUri 미주입 시 점선 자리표시 사각형이 그려진다");
  assert(svgDragging.length > 0, "qrDataUri 가 없어도 buildSvg 가 예외 없이 완료된다");

  // ── [검증 F] 이미지 자산 요소 — resolveAsset 콜백으로 같은 data URI 를 주입하면 양쪽이 일치한다 ──
  console.log("\n--- [검증 F] 이미지 자산 — 같은 data URI 를 resolveAsset 으로 주입하면 클라이언트/서버가 일치한다 ---");
  const tmpDir = mkdtempSync(path.join(tmpdir(), "crit1-asset-"));
  const assetAbsPath = path.join(tmpDir, "test-asset.png");
  // 최소한의 유효 PNG(1x1 투명 픽셀)를 실제 파일로 기록 — renderer.ts 의
  // toDataUri() 가 fs 로 실제로 읽도록 한다(모킹 없이 실제 I/O 경로를 태운다).
  const onePixelPng = Buffer.from(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6360000002000100ffff03000006000557bf" + "abd4" + "0000000049454e44ae426082",
    "hex",
  );
  writeFileSync(assetAbsPath, onePixelPng);
  const relAssetPath = path.relative(process.cwd(), assetAbsPath);

  try {
    const layoutWithImage = addElement(defaultLayout(CANVAS_PRESETS.PORTRAIT_1080), "image", {
      name: "테스트 이미지",
      assetUrl: relAssetPath,
      x: 200, y: 200, width: 160, height: 160,
    });

    const svgServerWithAsset = await buildSvgServer(layoutWithImage, ctx);
    const expectedDataUri = `data:image/png;base64,${onePixelPng.toString("base64")}`;
    assert(svgServerWithAsset.includes(expectedDataUri), "서버(renderer.ts)가 실제 파일을 읽어 올바른 data URI 를 SVG 에 삽입했다");

    // [주의] layoutWithImage 는 캔버스가 1080 이라 QR 크기(canvas.width*0.42)가
    // 위에서 만든 qrDataUri(720 기준)와 다르다 — 이 레이아웃의 실제 QR 크기에
    // 맞춰 "서버가 생성했을 것과 동일한" qrDataUri 를 다시 계산해야 공정한
    // 비교가 된다(그렇지 않으면 QR 불일치가 자산 비교 결과를 오염시킨다).
    const qrEl1080 = layoutWithImage.elements.find((e) => e.kind === "qr")!;
    const size1080 = qrEl1080.width ?? Math.round(layoutWithImage.canvas.width * 0.42);
    const payload1080 = qrPayload(ctx.coupon.redeemToken, ctx.registerBaseUrl);
    const qrPng1080 = await QRCode.toBuffer(payload1080, { type: "png", margin: 1, width: size1080, errorCorrectionLevel: "M" });
    const qrDataUri1080 = `data:image/png;base64,${qrPng1080.toString("base64")}`;
    assert(svgServerWithAsset.includes(qrDataUri1080), "서버가 1080 캔버스 레이아웃에 맞는 크기로 QR 을 생성했다(사전 계산값과 일치)");

    const svgClientWithAsset = buildSvgClient(layoutWithImage, ctx, {
      qrDataUri: qrDataUri1080,
      resolveAsset: (src) => (src === relAssetPath ? expectedDataUri : null),
    });
    assert(
      svgClientWithAsset === svgServerWithAsset,
      "이미지 자산을 포함한 레이아웃에서도 클라이언트(resolveAsset 주입)와 서버(실제 fs 읽기) SVG 문자열이 완전히 일치한다",
    );
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }

  console.log("\n────────────────────────────────────────────────────────────");
  console.log("  완료기준 1 — 전체 검증 통과");
  console.log("  (QR 생성 알고리즘 자체의 바이트 차이는 비교 대상에서 제외하지 않았다 —");
  console.log("   오히려 결정론적임을 증명해 서버·클라이언트가 같은 payload/옵션을 쓰면");
  console.log("   항상 같은 QR 이 나온다는 것까지 포함해 '문자열 완전 일치'를 달성했다.)");
  console.log("────────────────────────────────────────────────────────────");
}

main().catch((e) => {
  console.error("\n[검증 실패]", e);
  process.exit(1);
});
