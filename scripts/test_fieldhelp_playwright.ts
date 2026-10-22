// [2026-10-22] FieldHelp(❓ 도움말 아이콘) 기능 Playwright 검증 — §Request#2 4단계 중 3단계.
// 로컬 개발서버(3100) 대상, admin_session 쿠키를 직접 주입해 로그인 과정을 생략한다.
// 대상 화면 3곳: 캠페인 생성 폼 / 캠페인 상세 화면 / 쿠폰 디자인 스튜디오.
// 각 화면에서: (1) FieldHelp 버튼이 존재하는지, (2) 클릭하면 팝오버가 열리는지,
// (3) 바깥을 클릭하면 닫히는지를 확인한다.
import { chromium } from "playwright";

const BASE_URL = process.env.TEST_BASE_URL || "http://localhost:3100";
const SESSION_TOKEN = process.env.SESSION_TOKEN;

if (!SESSION_TOKEN) {
  console.error("SESSION_TOKEN 환경변수가 필요합니다.");
  process.exit(1);
}

async function main() {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const url = new URL(BASE_URL);
  await context.addCookies([
    {
      name: "admin_session",
      value: SESSION_TOKEN!,
      domain: url.hostname,
      path: "/",
      httpOnly: true,
      sameSite: "Lax",
    },
  ]);
  const page = await context.newPage();

  const results: { screen: string; pass: boolean; detail: string }[] = [];

  // ── 1) 캠페인 생성 폼 (쿠폰 목록 화면에서 "+ 새 쿠폰 캠페인 만들기" 클릭 후 폼 노출) ──
  try {
    await page.goto(`${BASE_URL}/bokju-coupons/campaigns`, { waitUntil: "networkidle" });
    const createBtn = page.getByRole("button", { name: /새 쿠폰 캠페인 만들기/ });
    await createBtn.click({ timeout: 10000 });
    const helpButtons = page.getByRole("button", { name: "도움말" });
    const count = await helpButtons.count();
    if (count === 0) throw new Error("FieldHelp 버튼이 하나도 없음");
    const first = helpButtons.first();
    await first.click();
    const tooltip = page.getByRole("tooltip").first();
    await tooltip.waitFor({ state: "visible", timeout: 3000 });
    const tooltipText = await tooltip.textContent();
    // 바깥 클릭 시 닫히는지
    await page.mouse.click(5, 5);
    await tooltip.waitFor({ state: "hidden", timeout: 3000 });
    results.push({
      screen: "캠페인 생성 폼",
      pass: true,
      detail: `도움말 버튼 ${count}개 발견, 첫 팝오버 텍스트 일부: "${(tooltipText || "").slice(0, 30)}...", 바깥클릭 시 정상 닫힘`,
    });
  } catch (e) {
    results.push({ screen: "캠페인 생성 폼", pass: false, detail: e instanceof Error ? e.message : String(e) });
  }

  // ── 2) 캠페인 상세 화면 (알려진 테스트 캠페인 id=272로 직접 이동) ──
  try {
    await page.goto(`${BASE_URL}/bokju-coupons/campaigns/272`, { waitUntil: "networkidle" });
    const helpButtons = page.getByRole("button", { name: "도움말" });
    const count = await helpButtons.count();
    if (count === 0) throw new Error("FieldHelp 버튼이 하나도 없음");
    const first = helpButtons.first();
    await first.scrollIntoViewIfNeeded();
    await first.click();
    const tooltip = page.getByRole("tooltip").first();
    await tooltip.waitFor({ state: "visible", timeout: 3000 });
    const tooltipText = await tooltip.textContent();
    await page.mouse.click(5, 5);
    await tooltip.waitFor({ state: "hidden", timeout: 3000 });
    results.push({
      screen: "캠페인 상세 화면",
      pass: true,
      detail: `도움말 버튼 ${count}개 발견, 첫 팝오버 텍스트 일부: "${(tooltipText || "").slice(0, 30)}...", 바깥클릭 시 정상 닫힘`,
    });
  } catch (e) {
    results.push({ screen: "캠페인 상세 화면", pass: false, detail: e instanceof Error ? e.message : String(e) });
  }

  // ── 3) 쿠폰 디자인 스튜디오 (알려진 테스트 캠페인 id=272 → /design 직접 이동) ──
  try {
    await page.goto(`${BASE_URL}/bokju-coupons/campaigns/272/design`, { waitUntil: "networkidle" });
    await page.waitForTimeout(1500); // 레이아웃/카탈로그 비동기 로드 대기
    const helpButtons = page.getByRole("button", { name: "도움말" });
    const count = await helpButtons.count();
    if (count === 0) throw new Error("FieldHelp 버튼이 하나도 없음(스튜디오 로드 실패 가능성 포함)");
    const first = helpButtons.first();
    await first.click();
    const tooltip = page.getByRole("tooltip").first();
    await tooltip.waitFor({ state: "visible", timeout: 3000 });
    const tooltipText = await tooltip.textContent();
    await page.mouse.click(5, 5);
    await tooltip.waitFor({ state: "hidden", timeout: 3000 });
    results.push({
      screen: "쿠폰 디자인 스튜디오",
      pass: true,
      detail: `도움말 버튼 ${count}개 발견, 첫 팝오버 텍스트 일부: "${(tooltipText || "").slice(0, 30)}...", 바깥클릭 시 정상 닫힘`,
    });
  } catch (e) {
    results.push({ screen: "쿠폰 디자인 스튜디오", pass: false, detail: e instanceof Error ? e.message : String(e) });
  }

  await browser.close();

  console.log("\n===== FieldHelp Playwright 테스트 결과 =====");
  let allPass = true;
  for (const r of results) {
    console.log(`[${r.pass ? "PASS" : "FAIL"}] ${r.screen}: ${r.detail}`);
    if (!r.pass) allPass = false;
  }
  console.log("=============================================\n");
  process.exit(allPass ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
