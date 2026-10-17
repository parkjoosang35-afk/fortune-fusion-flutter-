// 검증용 임시 스크립트 — 02g §필수3 요청에 대한 응답.
// classic 템플릿 · PORTRAIT_720(720×1280) · 팔레트 bok-red · 고정 qrDataUri로
// buildSvg() 출력을 만들어 preview-classic-720.svg로 저장한다.
// 검증 후 삭제 가능(운영 코드 아님).
import { writeFileSync } from "node:fs";
import { buildTemplate } from "../src/lib/bokju-coupon-design/templates";
import { CANVAS_PRESETS } from "../src/lib/bokju-coupon-design/layout";
import { resolveTheme } from "../src/lib/bokju-coupon-design/theme";
import { buildSvg, type SvgRenderContext } from "../src/lib/bokju-coupon-design/svg";

// 고정 테스트 QR data URI (매번 동일 — 비교 가능하도록 실제 PNG 인코딩 없이
// 1x1 투명 PNG를 고정 문자열로 사용. 기하 비교에는 자리값이면 충분)
const FIXED_TEST_QR_DATA_URI =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";

const theme = resolveTheme({ paletteId: "bok-red" });
const layout = buildTemplate("classic", theme, CANVAS_PRESETS.PORTRAIT_720);

const ctx: SvgRenderContext = {
  campaign: {
    title: "검증용 고정 캠페인",
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

writeFileSync("preview-classic-720.svg", svg);
console.log("WROTE preview-classic-720.svg, length =", svg.length);
console.log("canvas:", layout.canvas);
