import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--explicitly-allowed-ports=5060"])
        context = await browser.new_context(viewport={"width": 414, "height": 896}, storage_state="/tmp/shrine_logged_in_state.json")
        page = await context.new_page()
        errors = []
        page.on("pageerror", lambda exc: errors.append(f"pageerror: {exc}"))
        await page.goto("http://localhost:5060", wait_until="load", timeout=60000)
        await page.wait_for_timeout(45000)
        # 홈 -> 신당부적 탭
        await page.mouse.click(156, 862)
        await page.wait_for_timeout(3000)
        # EntryScreen -> 지금 신당으로 들어가기
        await page.mouse.click(207, 793)
        await page.wait_for_timeout(3000)
        # Door SKIP
        await page.mouse.click(358, 71)
        await page.wait_for_timeout(3000)
        # Hall -> 제단 앞으로 다가가기
        await page.mouse.click(207, 810)
        await page.wait_for_timeout(3000)
        await page.screenshot(path="/tmp/run1_01_gate.png")
        # 결과보기 시트: 복주머니로 보기 (10013개 보유, 100개 차감 예상)
        await page.mouse.click(207, 703)
        await page.wait_for_timeout(5000)
        await page.screenshot(path="/tmp/run1_02_connect.png")
        print("after pouch click, errors:", errors)
        await page.context.storage_state(path="/tmp/shrine_logged_in_state.json")
        await browser.close()

asyncio.run(main())
