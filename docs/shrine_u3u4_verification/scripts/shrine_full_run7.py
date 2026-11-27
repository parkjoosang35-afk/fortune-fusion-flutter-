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
        await page.mouse.click(156, 862); await page.wait_for_timeout(3000)  # shrine tab
        await page.mouse.click(207, 793); await page.wait_for_timeout(3000)  # entry
        await page.mouse.click(358, 71); await page.wait_for_timeout(3000)   # door skip
        await page.mouse.click(207, 810); await page.wait_for_timeout(3000)  # hall enter altar
        await page.mouse.click(207, 703); await page.wait_for_timeout(8000)  # pouch pay
        await page.mouse.click(95, 712); await page.wait_for_timeout(4000)   # connect: 동의하고 명부 옮기기 (corrected coord)
        await page.screenshot(path="/tmp/run7_00_talk1.png")
        # Talk dialogue step 1/4 -> click 다음 button (right side)
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.screenshot(path="/tmp/run7_01_talk2.png")
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.screenshot(path="/tmp/run7_02_talk3.png")
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.screenshot(path="/tmp/run7_03_talk4.png")
        await page.mouse.click(316, 833); await page.wait_for_timeout(2500)
        await page.screenshot(path="/tmp/run7_04_afterTalk.png")
        print("errors:", errors)
        await page.context.storage_state(path="/tmp/shrine_logged_in_state.json")
        await browser.close()

asyncio.run(main())
