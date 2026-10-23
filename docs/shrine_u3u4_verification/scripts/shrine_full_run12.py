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
        await page.mouse.click(95, 826); await page.wait_for_timeout(5000)
        await page.wait_for_timeout(3000)
        await page.mouse.wheel(0, 800); await page.wait_for_timeout(1500)
        await page.mouse.wheel(0, 800); await page.wait_for_timeout(1500)
        await page.mouse.wheel(0, 800); await page.wait_for_timeout(1500)
        await page.mouse.click(207, 753); await page.wait_for_timeout(3000)
        # click "「붉은 방울」·사랑과 인연으로 들어가기"
        await page.mouse.click(207, 807); await page.wait_for_timeout(3000)
        await page.screenshot(path="/tmp/run12_00_story1.png")
        # advance story dialogue a few times
        await page.mouse.click(207, 450); await page.wait_for_timeout(2000)
        await page.screenshot(path="/tmp/run12_01_story2.png")
        await page.mouse.click(207, 450); await page.wait_for_timeout(2000)
        await page.screenshot(path="/tmp/run12_02_story3.png")
        await page.mouse.click(207, 450); await page.wait_for_timeout(2000)
        await page.screenshot(path="/tmp/run12_03_story4.png")
        print("errors:", errors)
        await page.context.storage_state(path="/tmp/shrine_logged_in_state.json")
        await browser.close()

asyncio.run(main())
