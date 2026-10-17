// 검증용 임시 스크립트 — 02i §검증우회 요청에 대한 응답.
// "qr=false + decoration=true" 조합(경계가 드러나는 조합)으로
// convertVisibilityToLayout()의 결과 layout JSON 전체와, 그 layout을
// buildSvg()로 렌더한 SVG 문자열을 각각 파일로 dump한다.
// dump-preview-svg.ts(02g §필수3)와 동일한 패턴을 재사용한다.
// 검증 후 삭제 가능(운영 코드 아님).
import { writeFileSync } from "node:fs";
import { convertVisibilityToLayout } from "../src/lib/bokju-coupon-design/legacy-convert";
import { validateLayout, CANVAS_PRESETS } from "../src/lib/bokju-coupon-design/layout";
import { buildSvg, type SvgRenderContext } from "../src/lib/bokju-coupon-design/svg";
import { DEFAULT_VISIBILITY } from "../src/lib/bokju-coupon-visibility";

// 고정 테스트 QR data URI (dump-preview-svg.ts와 동일 — 비교 가능하도록
// 매번 동일한 1x1 투명 PNG 고정 문자열 사용. 단, 이 조합은 qr=false이므로
// 실제로는 qrDataUri가 사용되지 않아야 정상 — layout에 qr 요소가 없다.)
const FIXED_TEST_QR_DATA_URI =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";

// ── 입력: 레거시 11토글 중 qr만 false, decoration만 true, 나머지는 기본값(true) ──
const rawVisibility = {
  ...DEFAULT_VISIBILITY,
  qr: false,
  decoration: true,
};

console.log("=== 입력 visibility (qr=false, decoration=true, 나머지 기본값) ===");
console.log(JSON.stringify(rawVisibility, null, 2));

// ── 변환 실행 ──
const layout = convertVisibilityToLayout(rawVisibility, CANVAS_PRESETS.PORTRAIT_720);

console.log("\n=== 변환된 layout.elements 요소 목록 (id/kind/z 순) ===");
for (const el of layout.elements) {
  console.log(`  id=${el.id.padEnd(14)} kind=${el.kind.padEnd(6)} z=${el.z}`);
}

// ── ① layout JSON 전체 dump ──
const layoutJsonPath = "dump-convert-qrfalse-decoration.layout.json";
writeFileSync(layoutJsonPath, JSON.stringify(layout, null, 2));
console.log(`\nWROTE ${layoutJsonPath}`);

// ── validateLayout() 재검증 (studio-api.ts의 convertLegacyDesign과 동일 절차) ──
const validation = validateLayout(layout);
console.log("\n=== validateLayout() 결과 ===");
console.log("ok:", validation.ok);
console.log("issues:", JSON.stringify(validation.issues, null, 2));

// ── ② buildSvg() SVG 문자열 dump ──
const ctx: SvgRenderContext = {
  campaign: {
    title: "검증용 고정 캠페인(qr=false,decoration=true)",
    grantAmount: 100,
    guideText: "검증용 고정 안내문구",
    validFrom: new Date("2026-01-01T00:00:00.000Z"),
    validTo: new Date("2027-01-01T00:00:00.000Z"),
  },
  coupon: {
    couponNo: "0000-0000-0000",
    redeemToken: "0".repeat(32),
  },
};

const svg = buildSvg(layout, ctx, {
  qrDataUri: FIXED_TEST_QR_DATA_URI,
  resolveAsset: (src) => src || null,
});

const svgPath = "dump-convert-qrfalse-decoration.svg";
writeFileSync(svgPath, svg);
console.log(`\nWROTE ${svgPath}, length =`, svg.length);
console.log("canvas:", layout.canvas);
console.log("redeemMode:", layout.redeemMode);

// ── layout.elements 배열 자체로 qr/deco 요소 존재 여부를 직접 검증한다
// (SVG 출력에는 id가 속성으로 남지 않으므로 — svg.ts elementSvg는 id를
// 렌더링하지 않는다 — 소스가 되는 layout.elements 배열로 확인하는 것이
// 더 정확하다. SVG 문자열 쪽은 <image>/<rect> 개수로 교차검증한다.)
const hasQrElement = layout.elements.some((el) => el.id === 'qr');
const decoElements = layout.elements.filter((el) => el.id.startsWith('deco'));
console.log("\nlayout.elements 내 id='qr' 요소 존재 여부 (false이어야 정상 — qr=false로 drop됨):", hasQrElement);
console.log("layout.elements 내 id가 'deco'로 시작하는 요소 개수 (3이어야 정상 — decoFrame/decoCircleA/decoCircleB):", decoElements.length);
console.log("deco 요소 id 목록:", decoElements.map((el) => el.id));

// SVG 쪽 <image> 태그 개수(qr=false이면 logo 등 image 요소가 없는 한 0이어야 함 — classic 템플릿은 logo를 image로 안 쓰므로 0 기대)
const imageTagCount = (svg.match(/<image /g) || []).length;
console.log("\nSVG 내 <image> 태그 개수 (qr가 빠졌으므로 0 기대 — classic엔 다른 image 요소 없음):", imageTagCount);
