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
        await page.mouse.click(207, 703); await page.wait_for_timeout(8000)
        await page.mouse.click(95, 712); await page.wait_for_timeout(4000)
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.mouse.click(207, 785); await page.wait_for_timeout(3000)
        await page.mouse.click(207, 450); await page.wait_for_timeout(2000)
        await page.mouse.click(207, 450); await page.wait_for_timeout(2000)
        # click "나의 정통사주 펼치기" button
        await page.mouse.click(95, 826); await page.wait_for_timeout(5000)
        await page.screenshot(path="/tmp/run9_00_saju.png")
        await page.wait_for_timeout(3000)
        await page.screenshot(path="/tmp/run9_01_saju2.png")
        print("errors:", errors)
        await page.context.storage_state(path="/tmp/shrine_logged_in_state.json")
        await browser.close()

asyncio.run(main())
