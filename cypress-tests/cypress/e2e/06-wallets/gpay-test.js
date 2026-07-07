const puppeteer = require('puppeteer-core');
const { spawn } = require('child_process');

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
    const PROFILE_DIR = `${process.env.HOME}/puppeteer-chrome-profile`;
    const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    const DEMO_URL = 'https://hyperswitch-demo-store.netlify.app';

    const chrome = spawn(
        CHROME_PATH,
        [
            `--user-data-dir=${PROFILE_DIR}`,
            '--profile-directory=Default',
            '--remote-debugging-port=9222',
            '--no-first-run',
            '--no-default-browser-check',
            '--disable-popup-blocking',
            '--window-size=1920,1080',
            '--start-maximized',
        ],
        { stdio: 'ignore' },
    );

    try {
        await delay(5000);

        const browser = await puppeteer.connect({ browserURL: 'http://127.0.0.1:9222' });
        const page = await browser.newPage();
        await page.setViewport({ width: 1920, height: 980 });

        await page.goto(DEMO_URL, { waitUntil: 'domcontentloaded' });

        const sdkFrameSelector = 'iframe[name="orca-payment-element-iframeRef-orca-elements-payment-element-paymentElement"]';
        await page.waitForSelector(sdkFrameSelector, { timeout: 30000 });
        const iframeEl = await page.$(sdkFrameSelector);
        const sdkFrame = await iframeEl.contentFrame();

        await (await sdkFrame.waitForSelector('[data-testid="addNewCard"]', { timeout: 10000, visible: true })).click();

        const gpayButton = await sdkFrame.waitForSelector('#gpay-button-online-api-id', { timeout: 10000, visible: true });
        await gpayButton.click();

        await delay(4000);
        const target = await browser.waitForTarget(
            (t) => t.type() === 'page' && t.url().includes('pay.google.com/gp/p/ui/pay'),
            { timeout: 30000 },
        );
        const gpayPage = await target.asPage();

        const gpayIframeEl = await gpayPage.$('iframe[name="sM432dIframe"]');
        const gpayIframe = await gpayIframeEl.contentFrame();

        await gpayIframe.waitForSelector('[class="VfPpkd-vQzf8d"]', { timeout: 15000 });
        await gpayIframe.click('[class="VfPpkd-vQzf8d"]');

        await page.waitForSelector('[class="font-semibold text-xl capitalize"]', { timeout: 10000, visible: true });
        const statusText = await page.$eval('[class="font-semibold text-xl capitalize"]', (el) => el.textContent?.trim() || '');
        if (!statusText.toLowerCase().includes('payment succeeded')) {
            throw new Error(`Expected "Payment succeeded" but got "${statusText}"`);
        }
        await delay(3000);
        console.log('GPay payment succeeded');
        await browser.disconnect();
    } catch (err) {
        console.error('GPay test failed:', err);
        process.exitCode = 1;
    } finally {
        chrome.kill();
    }
})();
