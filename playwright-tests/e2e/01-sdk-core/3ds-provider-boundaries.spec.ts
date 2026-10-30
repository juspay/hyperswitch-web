import type { Frame, Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  connectorEnum,
  juspayChallengeTestCard,
  netceteraChallengeTestCard,
  netceteraFrictionlessTestCard,
  redsysCards,
  type Checkout,
  CLIENT_BASE_URL,
  HYPERSWITCH_API_URL,
  SDK_URL,
} from "../../fixtures";

// Match the process isolation used when merchants embed the deployed SDK.
test.use({ launchOptions: { args: ["--site-per-process"] } });

const unrelatedUrl = "https://unrelated-provider.example.test/result";
const providerBody = "<!doctype html><body>Provider stand-in</body>";

const completion = {
  next_action: {
    type: "redirect_to_url",
    url: CLIENT_BASE_URL,
    redirect_mode: "if_required",
  },
};

async function openCrossSiteCheckout(
  page: Page,
  checkout: Checkout,
  body = paymentBody(),
) {
  const intent = await checkout.createPaymentIntent(body);
  // Different localhost ports are still same-site. Isolate the SDK process
  // from the merchant, as it is when embedding the deployed SDK.
  const merchantUrl = new URL(checkout.url(intent));
  merchantUrl.hostname =
    new URL(SDK_URL).hostname === "127.0.0.1" ? "localhost" : "127.0.0.1";
  await page.route(`${merchantUrl.origin}/**`, (route) => route.continue());
  await page.route(`${merchantUrl.origin}/payments/config`, (route) =>
    route.fulfill({ json: { publishableKey: "", profileId: "" } }),
  );
  await page.route(`${merchantUrl.origin}/payments/urls`, (route) =>
    route.fulfill({
      json: { serverUrl: HYPERSWITCH_API_URL, clientUrl: SDK_URL },
    }),
  );
  // The dev server blocks cross-site script tags. Serve its actual loader;
  // the SDK frames still run on their own site.
  const response = await page.request.get(`${SDK_URL}/HyperLoader.js`);
  expect(response.ok()).toBe(true);
  const loader = await response.body();
  await page.route(`${SDK_URL}/HyperLoader.js`, (route) =>
    route.fulfill({
      contentType: "application/javascript",
      body: loader,
    }),
  );
  await page.goto(merchantUrl.href);
  return intent;
}

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
    await openCrossSiteCheckout(page, checkout);
    await sdk.waitForReady();
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
    await openCrossSiteCheckout(page, checkout);
    await sdk.waitForReady();
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

    for (const failure of ["http", "response", "network"] as const) {
      test(`reports a 3DS authentication ${failure} error before closing its cross-site frame`, async ({
        checkout,
        credentials,
        sdk,
        page,
        hermetic,
      }) => {
        const errorMessage = "Authentication could not be completed";
        if (failure === "network") {
          await page.route("**/3ds/authentication", (route) =>
            route.abort("failed"),
          );
        } else {
          hermetic.override("threeDsAuthentication", (route) => ({
            ...route,
            status: failure === "http" ? 400 : 200,
            body: {
              error: { type: "authentication_failed", message: errorMessage },
            },
          }));
        }
        await openCrossSiteCheckout(
          page,
          checkout,
          paymentBody({
            profile_id: credentials.profileId(connectorEnum.NETCETERA),
            request_external_three_ds_authentication: true,
            authentication_type: "three_ds",
          }),
        );
        await sdk.waitForReady();
        await sdk.enterCardDetails({
          cardNo: netceteraChallengeTestCard,
          card_exp_month: "04",
          card_exp_year: "44",
          cvc: "1234",
        });
        const authRequest = page.waitForRequest((request) =>
          request.url().includes("/3ds/authentication"),
        );
        await sdk.submit();
        await authRequest;
        if (failure !== "network")
          await expect(
            page.getByText(errorMessage, { exact: true }),
          ).toBeVisible();
        await expect(
          page.getByRole("button", { name: "Pay now", exact: true }),
        ).toBeEnabled();
        await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
      });
    }

    for (const challenge of [true, false]) {
      test(`completes ${challenge ? "challenge" : "frictionless"} authentication after a cross-site method frame`, async ({
        checkout,
        credentials,
        sdk,
        page,
        hermetic,
      }) => {
        await openCrossSiteCheckout(
          page,
          checkout,
          paymentBody({
            profile_id: credentials.profileId(connectorEnum.NETCETERA),
            request_external_three_ds_authentication: true,
            authentication_type: "three_ds",
          }),
        );
        const cardNo = challenge
          ? netceteraChallengeTestCard
          : netceteraFrictionlessTestCard;
        // Exercise the method-enabled confirmation for both card scenarios.
        hermetic.override("confirm", (route) => ({
          ...route,
          match: {
            body: {
              payment_method_data: { card: { card_number: cardNo } },
            },
          },
          intentPatch: {
            ...route.intentPatch,
            hermetic_3ds: challenge ? "challenge" : "frictionless",
          },
        }));
        await sdk.waitForReady();
        await sdk.enterCardDetails({
          cardNo,
          card_exp_month: "04",
          card_exp_year: "44",
          cvc: "1234",
        });
        await sdk.submit();
        const auth = await hermetic.waitForCall("threeDsAuthentication");
        expect(auth?.requestBody).toMatchObject({
          threeds_method_comp_ind: "Y",
        });
        if (challenge) {
          const acs = await sdk.nestedIFrame("#threeDsAuthFrame");
          await acs.locator('input[name="otp"]').fill("1234");
          await acs.getByRole("button", { name: "Pay", exact: true }).click();
        }
        await expect(page.getByText("Thanks for your order!")).toBeVisible();
      });
    }

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
        await openCrossSiteCheckout(
          page,
          checkout,
          paymentBody({
            profile_id: credentials.profileId(connectorEnum.NETCETERA),
            request_external_three_ds_authentication: true,
            authentication_type: "three_ds",
          }),
        );
        await sdk.waitForReady();
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

  test("reports redirect-modal cancellation before closing its cross-site frame", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    const popupUrl = "https://redirect-provider.example.test/challenge";
    await servePage(page, popupUrl);
    hermetic.override("confirm", {
      status: "requires_customer_action",
      next_action: {
        type: "redirect_inside_popup",
        popup_url: popupUrl,
        redirect_response_url: "",
      },
    });
    await openCrossSiteCheckout(page, checkout);
    await sdk.waitForReady();
    await sdk.enterCardDetails(stripeCards.successCard);
    await sdk.submit();
    const overlay = page.frameLocator("#orca-fullscreen");
    await expect(
      overlay.frameLocator("#threeDsRedirectFrame").locator("body"),
    ).toHaveText("Provider stand-in");
    await overlay.locator("div.cursor-pointer").click();
    await expect(
      page.getByText("Something went wrong.", { exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Pay now", exact: true }),
    ).toBeEnabled();
    await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
  });

  test.describe("Redsys method completion", () => {
    test.use({ hermeticFixtures: ["05-external-3ds/01-redsys-3ds.json"] });

    for (const outcome of ["challenge", "frictionless", "error"] as const) {
      test(`delivers the Redsys ${outcome} result from a cross-site frame`, async ({
        checkout,
        credentials,
        sdk,
        page,
        hermetic,
      }) => {
        const errorMessage = "Redsys authorization could not be completed";
        if (outcome === "error") {
          hermetic.override("completeAuthorize", (route) => ({
            ...route,
            status: 400,
            body: {
              error: { type: "authorization_failed", message: errorMessage },
            },
          }));
        }
        await openCrossSiteCheckout(
          page,
          checkout,
          paymentBody({
            profile_id: credentials.profileId(connectorEnum.REDSYS),
            request_external_three_ds_authentication: true,
            authentication_type: "three_ds",
            currency: "EUR",
          }),
        );
        await sdk.waitForReady();
        await sdk.enterCardDetails(
          outcome === "frictionless"
            ? redsysCards.threedsInvokeFrictionlessTestCard
            : redsysCards.threedsInvokeChallengeTestCard,
        );
        await sdk.submit();
        const auth = await hermetic.waitForCall("completeAuthorize");
        expect(auth?.requestBody).toMatchObject({
          threeds_method_comp_ind: "Y",
        });
        if (outcome === "challenge") {
          await page.waitForURL(/sis-d\.redsys\.es/, { waitUntil: "commit" });
        } else {
          await expect(
            page.getByText(
              outcome === "error" ? errorMessage : "Thanks for your order!",
              { exact: true },
            ),
          ).toBeVisible();
          await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
          if (outcome === "error")
            await expect(
              page.getByRole("button", { name: "Pay now", exact: true }),
            ).toBeEnabled();
        }
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
      await openCrossSiteCheckout(
        page,
        checkout,
        paymentBody({
          profile_id: credentials.profileId(connectorEnum.JUSPAY),
          request_external_three_ds_authentication: true,
          authentication_type: "three_ds",
        }),
      );
      await sdk.waitForReady();
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
