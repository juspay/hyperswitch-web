import type { Frame, Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  connectorEnum,
  juspayChallengeTestCard,
  netceteraChallengeTestCard,
  CLIENT_BASE_URL,
} from "../../fixtures";

const unrelatedUrl = "https://unrelated-provider.example.test/result";
const providerBody = "<!doctype html><body>Provider stand-in</body>";

const completion = {
  next_action: {
    type: "redirect_to_url",
    url: CLIENT_BASE_URL,
    redirect_mode: "if_required",
  },
};

async function servePage(page: Page, url: string) {
  await page.route(url, (route) =>
    route.fulfill({
      contentType: "text/html",
      body: providerBody,
    }),
  );
}

// Client-side navigation preserves the WindowProxy while changing the document
// and its browser-provided origin. It also keeps every request inside the route
// harness (HTTP 3xx follow-up requests bypass Playwright interception).
async function serveRedirect(page: Page, from: string, to: string) {
  await servePage(page, to);
  await page.route(from, (route) =>
    route.fulfill({
      contentType: "text/html",
      body: `<!doctype html><script>location.replace(${JSON.stringify(to)})</script>`,
    }),
  );
}

// Drain the receiving window's message queue using a real transferred port.
// No fabricated MessageEvent.origin/source values are used by these tests.
async function postAndDrain(frame: Frame, payload: unknown) {
  await frame.evaluate(async (payload) => {
    const channel = new MessageChannel();
    const delivered = new Promise<void>((resolve) => {
      channel.port1.onmessage = () => resolve();
    });
    parent.postMessage(payload, "*");
    parent.postMessage({ providerBoundaryBarrier: true }, "*", [channel.port2]);
    await delivered;
    channel.port1.close();
  }, payload);
}

test.describe("Provider navigation contracts @hermetic-only", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      window.addEventListener("message", (event) => {
        if (event.data?.providerBoundaryBarrier)
          event.ports[0]?.postMessage(true);
      });
    });
  });

  test("DDC accepts a same-origin redirect and its final completion message", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    const providerUrl = "https://ddc-provider.example.test/start";
    const resultUrl = new URL("/result", providerUrl).href;
    await serveRedirect(page, providerUrl, resultUrl);
    hermetic.override("confirm", {
      status: "requires_customer_action",
      next_action: {
        type: "invoke_ddc",
        ddc_data: { iframe_url: providerUrl, timeout_ms: 30_000 },
      },
    });
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await sdk.enterCardDetails(stripeCards.successCard);
    await sdk.submit();
    await expect(
      sdk.paymentElement.frameLocator("#ddc-iframe").locator("body"),
    ).toHaveText("Provider stand-in");
    const ddc = page.frames().find((frame) => frame.url() === resultUrl)!;
    expect(ddc.url()).not.toBe(providerUrl);
    hermetic.setIntent({ status: "succeeded" });
    await ddc.evaluate(
      (payload) => parent.postMessage(payload, "*"),
      completion,
    );
    await expect(page.getByText("Thanks for your order!")).toBeVisible();
    await expect(sdk.paymentElement.locator("#ddc-iframe")).toHaveCount(0);
  });

  test("DDC rejects the same iframe after a foreign redirect and fails cleanly on timeout", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    await page.clock.install();
    const providerUrl = "https://ddc-provider.example.test/start";
    const foreignResult = unrelatedUrl;
    await serveRedirect(page, providerUrl, foreignResult);
    hermetic.override("confirm", {
      status: "requires_customer_action",
      next_action: {
        type: "invoke_ddc",
        ddc_data: { iframe_url: providerUrl, timeout_ms: 30_000 },
      },
    });
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await sdk.enterCardDetails(stripeCards.successCard);
    await sdk.submit();
    await expect(
      sdk.paymentElement.frameLocator("#ddc-iframe").locator("body"),
    ).toHaveText("Provider stand-in");
    // A forged completion would resolve successfully if the origin check failed.
    hermetic.setIntent({ status: "succeeded" });
    await postAndDrain(
      page.frames().find((frame) => frame.url() === foreignResult)!,
      completion,
    );
    await expect(sdk.paymentElement.locator("#ddc-iframe")).toHaveCount(1);
    await page.clock.fastForward(30_001);
    await expect(
      page.getByText("Something went wrong", { exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Pay now", exact: true }),
    ).toBeEnabled();
    await expect(sdk.paymentElement.locator("#ddc-iframe")).toHaveCount(0);
    await expect(page.getByText("Thanks for your order!")).not.toBeVisible();
  });

  test.describe("3DS method callback", () => {
    test.use({ hermeticFixtures: ["05-external-3ds/02-netcetera-3ds.json"] });

    for (const sendsCompletion of [true, false]) {
      test(`method ${sendsCompletion ? "accepts only its expected frame's completion" : "times out and continues with method indicator N"}`, async ({
        checkout,
        credentials,
        sdk,
        page,
        hermetic,
      }) => {
        if (!sendsCompletion) await page.clock.install();
        const methodUrl = "https://method-provider.example.test/start";
        const resultUrl = new URL("/result", methodUrl).href;
        await serveRedirect(page, methodUrl, resultUrl);
        hermetic.override("confirm", {
          next_action: {
            three_ds_data: {
              three_ds_method_details: {
                three_ds_method_data_submission: true,
                consume_post_message_for_three_ds_method_completion: true,
                three_ds_method_url: methodUrl,
              },
            },
          },
        });
        await checkout.open({
          body: paymentBody({
            profile_id: credentials.profileId(connectorEnum.NETCETERA),
            request_external_three_ds_authentication: true,
            authentication_type: "three_ds",
          }),
          waitForReady: true,
        });
        await sdk.enterCardDetails({
          cardNo: netceteraChallengeTestCard,
          card_exp_month: "04",
          card_exp_year: "44",
          cvc: "1234",
        });
        await sdk.submit();
        const method = page
          .frameLocator("#orca-fullscreen")
          .frameLocator("#threeDsInvisibleIframe");
        await expect(method.locator("body")).toHaveText("Provider stand-in");
        expect(hermetic.calls("threeDsAuthentication")).toHaveLength(0);
        if (sendsCompletion) {
          // A second frame on the same provider origin still cannot complete the method.
          await page
            .frameLocator("#orca-fullscreen")
            .locator("body")
            .evaluate((_el, url) => {
              const sibling = document.createElement("iframe");
              sibling.id = "method-impostor";
              sibling.src = url;
              document.body.appendChild(sibling);
            }, resultUrl);
          await expect(
            page
              .frameLocator("#orca-fullscreen")
              .frameLocator("#method-impostor")
              .locator("body"),
          ).toHaveText("Provider stand-in");
          const providerFrames = page
            .frames()
            .filter((frame) => frame.url() === resultUrl);
          await postAndDrain(
            providerFrames.find(
              (frame) => frame.name() !== "threeDsInvisibleIframe",
            )!,
            { methodComplete: true },
          );
          expect(hermetic.calls("threeDsAuthentication")).toHaveLength(0);
          await providerFrames
            .find((frame) => frame.name() === "threeDsInvisibleIframe")!
            .evaluate(() => parent.postMessage({ methodComplete: true }, "*"));
        } else {
          await page.clock.fastForward(16_000);
        }
        const auth = await hermetic.waitForCall("threeDsAuthentication");
        expect(auth?.requestBody).toMatchObject({
          threeds_method_comp_ind: sendsCompletion ? "Y" : "N",
        });
        const acs = await sdk.nestedIFrame("#threeDsAuthFrame");
        await expect(acs.locator('input[name="otp"]')).toBeVisible();
        await acs.locator('input[name="otp"]').fill("1234");
        await acs.getByRole("button", { name: "Pay", exact: true }).click();
        await expect(page.getByText("Thanks for your order!")).toBeVisible();
      });
    }
  });

  test.describe("ACS callback after navigation", () => {
    test.use({ hermeticFixtures: ["05-external-3ds/03-juspay-3ds.json"] });

    test("rejects a foreign document in the ACS frame then accepts the configured backend return origin", async ({
      checkout,
      credentials,
      sdk,
      page,
      hermetic,
    }) => {
      await servePage(page, unrelatedUrl);
      await checkout.open({
        body: paymentBody({
          profile_id: credentials.profileId(connectorEnum.JUSPAY),
          request_external_three_ds_authentication: true,
          authentication_type: "three_ds",
        }),
        waitForReady: true,
      });
      await sdk.enterCardDetails({
        cardNo: juspayChallengeTestCard,
        card_exp_month: "04",
        card_exp_year: "44",
        cvc: "1234",
      });
      await sdk.submit();
      const acs = await sdk.nestedIFrame("#threeDsAuthFrame");
      await expect(acs.locator("#otp")).toBeVisible();
      const confirm = await hermetic.waitForCall("confirm");
      const returnUrl = (
        confirm?.responseBody as {
          next_action: { three_ds_data: { three_ds_authorize_url: string } };
        }
      ).next_action.three_ds_data.three_ds_authorize_url;
      await servePage(page, returnUrl);
      const child = page
        .frames()
        .find((frame) => frame.name() === "threeDsAuthFrame")!;
      const acsOrigin = new URL(child.url()).origin;
      expect(new URL(returnUrl).origin).not.toBe(acsOrigin);
      await child.goto(unrelatedUrl);
      const retrieveCount = hermetic.calls("retrieve").length;
      hermetic.setIntent({ status: "succeeded" });
      await postAndDrain(child, { openurl_if_required: CLIENT_BASE_URL });
      await expect(page.locator("#orca-fullscreen")).toHaveCount(1);
      expect(hermetic.calls("retrieve")).toHaveLength(retrieveCount);
      await expect(page.getByText("Thanks for your order!")).not.toBeVisible();
      await child.goto(returnUrl);
      await child.evaluate(
        (url) => parent.postMessage({ openurl_if_required: url }, "*"),
        CLIENT_BASE_URL,
      );
      await expect(page.getByText("Thanks for your order!")).toBeVisible();
      expect(hermetic.calls("retrieve").length).toBeGreaterThan(retrieveCount);
    });
  });
});
