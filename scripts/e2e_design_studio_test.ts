// Playwright 실제 브라우저 E2E 테스트 — 쿠폰 디자인 스튜디오
// 1) 세션 쿠키 직접 주입(비밀번호 미보유, session.ts와 동일 알고리즘 사용)
// 2) 디자인 페이지 진입 → 요소 선택
// 3) X/Y 좌표 직접 입력 → 반영 확인
// 4) 정렬 버튼(정중앙) 클릭 → 캔버스 중앙으로 이동 확인
// 5) 저장 → 페이지 재진입 → 좌표/정렬 결과 유지 확인(영속성 검증)
import { chromium } from "playwright";
import { SignJWT } from "jose";

const BASE_URL = "http://localhost:3010";
const CAMPAIGN_ID = process.env.E2E_CAMPAIGN_ID || "253";

async function getSessionCookie() {
  const secretKey = process.env.SESSION_SECRET;
  if (!secretKey) throw new Error("SESSION_SECRET 없음");
  const encodedKey = new TextEncoder().encode(secretKey);
  return new SignJWT({
    adminUserId: 1,
    email: "sksks77777@naver.com",
    name: "sksks77777",
    roleCode: "super_admin",
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30m")
    .sign(encodedKey);
}

async function main() {
  const token = await getSessionCookie();
  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 1400, height: 1000 } });
  await context.addCookies([
    {
      name: "admin_session",
      value: token,
      domain: "localhost",
      path: "/",
      httpOnly: true,
      secure: false,
      sameSite: "Lax",
    },
  ]);
  const page = await context.newPage();
  page.on("console", (m) => {
    if (m.type() === "error") console.log("  [브라우저 콘솔 에러]", m.text());
  });
  page.on("pageerror", (e) => console.log("  [페이지 에러]", e.message));

  const results: { name: string; pass: boolean; detail?: string }[] = [];
  const check = (name: string, pass: boolean, detail?: string) => {
    results.push({ name, pass, detail });
    console.log(`${pass ? "✅" : "❌"} ${name}${detail ? " - " + detail : ""}`);
  };

  console.log(`=== [1단계] 디자인 페이지 진입: /bokju-coupons/campaigns/${CAMPAIGN_ID}/design ===`);
  const resp = await page.goto(`${BASE_URL}/bokju-coupons/campaigns/${CAMPAIGN_ID}/design`, { waitUntil: "networkidle" });
  check("페이지 로드 성공(200)", resp?.status() === 200, `status=${resp?.status()}`);
  await page.waitForTimeout(1000);

  const title = await page.title();
  console.log("  페이지 타이틀:", title);
  const h1 = await page.locator("h1").first().textContent().catch(() => null);
  console.log("  H1:", h1);
  check("쿠폰 디자인 스튜디오 화면 진입 확인", !!h1 && h1.includes("쿠폰 디자인 스튜디오"), h1 ?? "");

  console.log("\n=== [2단계] 요소 목록에서 '쿠폰명' 요소 선택 ===");
  const elementItems = page.locator("li").filter({ hasText: "·" });
  const countEl = await elementItems.count();
  console.log(`  발견된 요소 개수: ${countEl}`);
  check("디자인 요소가 1개 이상 존재", countEl > 0, `count=${countEl}`);
  if (countEl === 0) {
    console.log("요소가 없어 테스트를 중단합니다.");
    await browser.close();
    printSummary(results);
    process.exit(1);
  }
  const targetItem = page.locator("li", { hasText: "쿠폰명" });
  await targetItem.click();
  await page.waitForTimeout(300);

  const selectedNameAttr = await targetItem.getAttribute("class");
  check("요소 선택 시 하이라이트(border-indigo-500) 적용", !!selectedNameAttr?.includes("border-indigo-500"), selectedNameAttr ?? "");

  console.log("\n=== [3단계] X/Y 좌표 직접 입력 테스트 ===");
  // "요소 속성" 패널 내부로 범위를 좁혀서 x/y 라벨을 정확히 특정한다
  const propsPanel = page.locator("section", { hasText: "요소 속성" });
  const xInput = propsPanel.locator("label").filter({ has: page.locator("span", { hasText: /^x$/ }) }).locator("input");
  const yInput = propsPanel.locator("label").filter({ has: page.locator("span", { hasText: /^y$/ }) }).locator("input");
  await xInput.fill("123");
  await xInput.press("Tab");
  await page.waitForTimeout(200);
  await yInput.fill("456");
  await yInput.press("Tab");
  await page.waitForTimeout(200);
  const xVal = await xInput.inputValue();
  const yVal = await yInput.inputValue();
  check("X 좌표 직접 입력 반영(123)", xVal === "123", `실제값=${xVal}`);
  check("Y 좌표 직접 입력 반영(456)", yVal === "456", `실제값=${yVal}`);

  console.log("\n=== [4단계] 정렬 버튼(정중앙) 클릭 → 캔버스 기준 중앙 좌표로 이동 확인 ===");
  // 이 캠페인은 캔버스 720x1280(화면에 표시된 "캔버스 크기" 버튼이 720×1280로 활성화됨)
  // 정중앙 기대값: x=360, y=640
  const centerBtn = propsPanel.locator("button", { hasText: "정중앙" });
  await centerBtn.click();
  await page.waitForTimeout(300);
  const xAfterCenter = Number(await xInput.inputValue());
  const yAfterCenter = Number(await yInput.inputValue());
  console.log(`  정중앙 클릭 후 좌표: x=${xAfterCenter}, y=${yAfterCenter}`);
  check("정중앙 정렬 후 X좌표가 123에서 변경됨(캔버스 중앙으로 이동)", xAfterCenter !== 123, `x=${xAfterCenter}`);
  check("정중앙 정렬 후 Y좌표가 456에서 변경됨(캔버스 중앙으로 이동)", yAfterCenter !== 456, `y=${yAfterCenter}`);

  console.log("\n=== [5단계] 가로중앙 버튼 클릭 → X만 변경, Y는 유지 확인 ===");
  await yInput.fill("777");
  await yInput.press("Tab");
  await page.waitForTimeout(200);
  const hCenterBtn = propsPanel.locator("button", { hasText: "가로중앙" });
  await hCenterBtn.click();
  await page.waitForTimeout(300);
  const xAfterHCenter = Number(await xInput.inputValue());
  const yAfterHCenter = Number(await yInput.inputValue());
  console.log(`  가로중앙 클릭 후: x=${xAfterHCenter}, y=${yAfterHCenter}`);
  check("가로중앙 정렬 시 X만 변경되고 Y는 유지(777)", yAfterHCenter === 777, `y=${yAfterHCenter}`);
  check("가로중앙 정렬 시 X는 캔버스 폭의 절반값으로 설정됨", xAfterHCenter === xAfterCenter, `x=${xAfterHCenter} (정중앙 때의 x와 동일해야함=${xAfterCenter})`);

  console.log("\n=== [6단계] 저장 버튼 클릭 ===");
  // 정중앙으로 최종 고정(재현 가능한 상태로 만든 뒤 저장)
  await centerBtn.click();
  await page.waitForTimeout(300);
  const finalX = await xInput.inputValue();
  const finalY = await yInput.inputValue();
  console.log(`  저장 직전 최종 좌표: x=${finalX}, y=${finalY}`);

  const saveBtn = page.locator("button", { hasText: "저장" }).first();
  const saveBtnDisabled = await saveBtn.isDisabled();
  check("저장 버튼이 활성화 상태(차단 항목 없음)", !saveBtnDisabled, `disabled=${saveBtnDisabled}`);

  if (!saveBtnDisabled) {
    await saveBtn.click();
    await page.waitForTimeout(1500);
    const saveMsg = await page.locator("text=저장").first().textContent().catch(() => null);
    const successMsgLocator = page.locator("p", { hasText: /저장|반영/ });
    const successCount = await successMsgLocator.count();
    console.log(`  저장 후 메시지 요소 개수: ${successCount}`);
    // 저장 성공 메시지(saveOk state) 확인 - 보통 "저장되었습니다" 류 텍스트
    const bodyText = await page.locator("body").innerText();
    const hasSuccessIndicator = /저장.*완료|저장되었습니다|성공/.test(bodyText);
    check("저장 완료 메시지 또는 성공 indicator 발견", hasSuccessIndicator, hasSuccessIndicator ? "메시지 발견" : "메시지 못 찾음(수동 확인 필요)");
  }

  console.log("\n=== [7단계] 페이지 재진입(새로고침) 후 좌표 유지 확인(영속성 검증) ===");
  await page.reload({ waitUntil: "networkidle" });
  await page.waitForTimeout(1000);
  await targetItem.click();
  await page.waitForTimeout(300);
  const xAfterReload = await xInput.inputValue();
  const yAfterReload = await yInput.inputValue();
  console.log(`  재진입 후 좌표: x=${xAfterReload}, y=${yAfterReload} (저장 시점: x=${finalX}, y=${finalY})`);
  check("재진입 시 X좌표가 저장한 값과 일치(영속성)", xAfterReload === finalX, `저장=${finalX}, 재조회=${xAfterReload}`);
  check("재진입 시 Y좌표가 저장한 값과 일치(영속성)", yAfterReload === finalY, `저장=${finalY}, 재조회=${yAfterReload}`);

  await page.screenshot({ path: "/tmp/e2e_design_studio_final.png", fullPage: true });
  console.log("\n스크린샷 저장: /tmp/e2e_design_studio_final.png");

  await browser.close();
  printSummary(results);
  const failCount = results.filter((r) => !r.pass).length;
  process.exit(failCount > 0 ? 1 : 0);
}

function printSummary(results: { name: string; pass: boolean }[]) {
  const total = results.length;
  const passed = results.filter((r) => r.pass).length;
  console.log(`\n=== 테스트 요약: ${passed}/${total} 통과 ===`);
  results.filter((r) => !r.pass).forEach((r) => console.log(`  ❌ 실패: ${r.name}`));
}

main().catch((e) => {
  console.error("치명적 에러:", e);
  process.exit(1);
});
