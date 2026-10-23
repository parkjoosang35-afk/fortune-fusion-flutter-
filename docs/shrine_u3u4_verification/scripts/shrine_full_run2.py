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
        # 설정 열어 "움직임 줄이기" 켜기 (속도 향상)
        await page.mouse.click(378, 27); await page.wait_for_timeout(1500)
        await page.screenshot(path="/tmp/run2_00_settings.png")
        await browser.close()

asyncio.run(main())
