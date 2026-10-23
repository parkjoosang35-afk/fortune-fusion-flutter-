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
        await page.mouse.click(156, 862); await page.wait_for_timeout(3000)
        await page.mouse.click(207, 793); await page.wait_for_timeout(3000)
        await page.mouse.click(358, 71); await page.wait_for_timeout(3000)
        await page.mouse.click(207, 810); await page.wait_for_timeout(3000)
        await page.mouse.click(207, 703); await page.wait_for_timeout(5000)
        # 설정 -> 움직임 줄이기 ON
        await page.mouse.click(378, 27); await page.wait_for_timeout(1200)
        await page.mouse.click(364, 568); await page.wait_for_timeout(800)
        # 시트 닫기 (바깥 탭)
        await page.mouse.click(207, 150); await page.wait_for_timeout(1000)
        await page.screenshot(path="/tmp/run3_00_reduce_on.png")
        # 동의하고 명부 옮기기
        await page.mouse.click(207, 712); await page.wait_for_timeout(4000)
        await page.screenshot(path="/tmp/run3_01_after_connect.png")
        print("errors:", errors)
        await page.context.storage_state(path="/tmp/shrine_logged_in_state.json")
        await browser.close()

asyncio.run(main())
