// Vendor popups and windows: the PayPal button opens the PayPal page, Klarna and Plaid open
// their windows, and closing the popup returns the payment element to a usable state.
//
// How each window is actually opened (read from src/):
//   PayPal  SDK flow (wallet/paypal, payment_experience invoke_sdk_client + a `paypal` session
//           token): src/Payments/PaypalSDK.res loads https://www.paypal.com/sdk/js inside the
//           payment element and wires paypal.Buttons({createOrder, onApprove, onCancel, ...})
//           (src/Payments/PaypalSDKHelpers.res). PayPal's own JS opens the checkout popup on click;
//           createOrder shows the SDK's payment loader (#orca-fullscreen) and confirms to get the
//           order id; onCancel (popup closed) removes the loader. (The redirect flow,
//           src/Payments/PayPal.res, navigates the same tab instead; no popup.)
//   Klarna  SDK flow (pay_later/klarna, invoke_sdk_client + a `klarna` session token):
//           src/Payments/KlarnaSDK.res loads https://x.klarnacdn.net/kp/lib/v1/api.js and renders
//           Klarna.Payments.Buttons; on_click shows the loader and calls Klarna's authorize(), which
//           opens Klarna's purchase popup; approved:false (popup closed) removes the loader.
//           (redirect_to_url Klarna is a same-tab redirect, covered by 08-klarna-redirect.spec.ts.)
//   Plaid   open_banking/open_banking_pis: confirm answers next_action
//           third_party_sdk_session_token (wallet_name open_banking), the SDK opens its `plaidSDK`
//           fullscreen frame (src/Payments/PlaidSDKIframe.res), which loads
//           https://cdn.plaid.com/link/v2/stable/link-initialize.js and calls
//           Plaid.create({token}).open(). Plaid Link's "window" is the Link iframe it injects (a
//           real popup only appears for OAuth banks); on exit the SDK force-syncs the payment,
//           resolves confirmPayment and closes the fullscreen frame.
//
// Two variants per vendor:
//   @live           the real vendor JS and the real popup. The test merchant must offer the
//                   method with the flow above; otherwise the test is skipped with the reason
//                   (see LIVE_SETUP below: today none of the three is provisioned that way).
//   @hermetic-only  recordings/04-alternative-payments/popups.json routes the vendor script to a
//                   minimal stand-in that reproduces only the vendor API shape and the window it
//                   opens. Everything around it is real SDK code: parsing the session token and
//                   payment_experience, choosing the SDK flow, building the vendor script URL,
//                   the config passed to the vendor (createOrder -> /confirm -> order id,
//                   on_click -> authorize, Plaid token from the confirm next_action), the payment
//                   loader, and the cancel/exit callbacks that must hand the element back.
import type { Locator, Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  connectorEnum,
  testIds,
  stripeCards,
  type Hermetic,
  type HyperswitchApi,
  type OpenedCheckout,
  type Sdk,
} from "../../fixtures";

const PAYPAL_CUSTOMER = "popups_paypal_user";
const KLARNA_CUSTOMER = "popups_klarna_user";
const PLAID_CUSTOMER = "popups_plaid_user";

/** Why the live variants skip on the merchant provisioned by setup/merchant-setup.js. */
const LIVE_SETUP = {
  paypalProfile:
    "PayPal connector profile is not provisioned: setup/merchant-setup.js has a 'paypal' payment-method " +
    "config but 'paypal' is not in REQUIRED_CONNECTORS, so no PayPal MCA/profile is created",
  paypalSdkFlow:
    "PayPal is not offered with payment_experience invoke_sdk_client + a paypal session token on this " +
    "profile (the PayPal MCA needs the SDK flow enabled), so the SDK renders no PayPal popup button",
  klarnaSdkFlow:
    "Klarna is provisioned only with payment_experience redirect_to_url (Stripe and Klarna MCAs in " +
    "setup/merchant-setup.js); the Klarna Payments popup needs invoke_sdk_client and a Klarna session token",
  plaid:
    "Plaid open banking (open_banking/open_banking_pis) is not provisioned: setup/merchant-setup.js creates " +
    "no Plaid connector, so the SDK offers no 'Open Banking' method",
};

// ── helpers ────────────────────────────────────────────────────────────────

/** Skips unless the router offers payment_method/type (optionally with `experience`) for this intent. */
async function requireOffered(
  api: HyperswitchApi,
  intent: OpenedCheckout,
  paymentMethod: string,
  paymentMethodType: string,
  experience: string | undefined,
  reason: string,
): Promise<void> {
  const list = await api.clientList(intent.paymentId, intent.clientSecret);
  const offered = (
    (list.payment_methods_enabled ?? []) as Array<Record<string, unknown>>
  ).some(
    (pm) =>
      pm.payment_method === paymentMethod &&
      pm.payment_method_type === paymentMethodType &&
      (!experience ||
        ((pm.payment_experience as string[] | undefined) ?? []).includes(
          experience,
        )),
  );
  test.skip(!offered, reason);
}

/** The SDK's payment loader (#orca-fullscreen) is gone and the demo shop's Pay button works again. */
async function expectLoaderGone(page: Page, sdk: Sdk): Promise<void> {
  await expect(page.locator("#orca-fullscreen")).toHaveCount(0, {
    timeout: 15_000,
  });
  await expect(sdk.submitButton).toBeEnabled();
}

/** The card form still takes input after the popup was dismissed. */
async function expectCardFormUsable(sdk: Sdk): Promise<void> {
  await sdk.waitForReady();
  await sdk.type(testIds.cardNoInputTestId, "4242424242424242");
  await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
    "4242 4242 4242 4242",
  );
}

/** Clicks `button` and returns the window it opens. */
async function clickForPopup(page: Page, button: Locator): Promise<Page> {
  const popupPromise = page.waitForEvent("popup");
  await button.click();
  const popup = await popupPromise;
  await popup.waitForLoadState("domcontentloaded");
  return popup;
}

/** Closes the popup the way a shopper does (window close, not a page navigation). */
async function closePopup(popup: Page): Promise<void> {
  await popup.close({ runBeforeUnload: false });
}

// PayPal: the real smart button lives in PayPal's own iframe inside #paypal-button; the
// hermetic stand-in renders a plain <button data-hermetic="paypal-button"> there.
const paypalButton = (sdk: Sdk, hermetic: Hermetic) =>
  hermetic.enabled
    ? sdk.find('#paypal-button [data-hermetic="paypal-button"]')
    : sdk.paymentElement
        .frameLocator("#paypal-button iframe")
        .first()
        .locator('[data-funding-source="paypal"]')
        .first();

const klarnaButton = (sdk: Sdk, hermetic: Hermetic) =>
  hermetic.enabled
    ? sdk.find('#klarna-payments [data-hermetic="klarna-button"]')
    : sdk.paymentElement
        .frameLocator("#klarna-payments iframe")
        .first()
        .locator("button, [role='button']")
        .first();

// ── PayPal ─────────────────────────────────────────────────────────────────

test.describe("PayPal popup", () => {
  test.beforeEach(async ({ checkout, credentials, api }) => {
    const profileId = credentials.profileId(connectorEnum.PAYPAL);
    test.skip(!profileId, LIVE_SETUP.paypalProfile);
    const opened = await checkout.open({
      body: paymentBody({
        profile_id: profileId,
        customer_id: PAYPAL_CUSTOMER,
      }),
    });
    await requireOffered(
      api,
      opened,
      "wallet",
      "paypal",
      "invoke_sdk_client",
      LIVE_SETUP.paypalSdkFlow,
    );
  });

  const opensPaypalPage = async (page: Page, sdk: Sdk, hermetic: Hermetic) => {
    const button = paypalButton(sdk, hermetic);
    await expect(button).toBeVisible({ timeout: 20_000 });
    const popup = await clickForPopup(page, button);
    await popup.waitForURL(/paypal\.com/, { timeout: 30_000 });
    // createOrder put the SDK's payment loader over the page while PayPal is open.
    await expect(page.locator("#orca-fullscreen")).toBeVisible();
    return popup;
  };

  // Live: real PayPal JS, real paypal.com popup. Needs a PayPal profile with the SDK flow.
  test(
    "PayPal button opens the PayPal page",
    { tag: "@live" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensPaypalPage(page, sdk, hermetic);
      await expect(popup).toHaveURL(
        /paypal\.com\/(checkoutnow|webapps|signin|agreements)/,
      );
    },
  );

  // Live: real popup; closing it must fire PayPal's onCancel and hand the element back.
  test(
    "closing the PayPal popup returns the element to a usable state",
    { tag: "@live" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensPaypalPage(page, sdk, hermetic);
      await closePopup(popup);
      await expectLoaderGone(page, sdk);
      await expectCardFormUsable(sdk);
      // The PayPal button opens PayPal again.
      const again = await clickForPopup(page, paypalButton(sdk, hermetic));
      await again.waitForURL(/paypal\.com/, { timeout: 30_000 });
      await closePopup(again);
    },
  );

  // Hermetic: stand-in paypal.Buttons; asserts the SDK's side of the contract.
  test(
    "PayPal button opens the PayPal page (hermetic: stand-in PayPal JS)",
    { tag: "@hermetic-only" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensPaypalPage(page, sdk, hermetic);

      // The SDK built the PayPal script URL from the session token.
      const script = new URL(hermetic.calls("paypalSdkScript")[0].url);
      expect(script.searchParams.get("client-id")).toBe(
        "hermetic-paypal-client-id",
      );
      expect(script.searchParams.get("components")).toBe(
        "buttons,hosted-fields",
      );
      expect(script.searchParams.get("currency")).toBe("USD");
      expect(script.searchParams.get("intent")).toBe("capture");

      // createOrder confirmed with the PayPal SDK body…
      const confirm = await hermetic.waitForCall("confirm");
      expect(confirm?.requestBody).toMatchObject({
        payment_method: "wallet",
        payment_method_type: "paypal",
        payment_experience: "invoke_sdk_client",
        payment_method_data: { wallet: { paypal_sdk: { token: "" } } },
      });
      // …and handed PayPal the order id from the confirm response (connector_transaction_id).
      await expect(popup).toHaveURL(
        /sandbox\.paypal\.com\/checkoutnow\?token=HERMETIC5O190127TN364715T/,
      );
      await expect(
        popup.getByText("Log in to your PayPal account"),
      ).toBeVisible();
    },
  );

  test(
    "closing the PayPal popup returns the element to a usable state (hermetic: stand-in PayPal JS)",
    { tag: "@hermetic-only" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensPaypalPage(page, sdk, hermetic);
      await closePopup(popup);
      await expectLoaderGone(page, sdk);
      await expectCardFormUsable(sdk);

      const again = await clickForPopup(page, paypalButton(sdk, hermetic));
      await again.waitForURL(/paypal\.com/);
      await closePopup(again);
      await expectLoaderGone(page, sdk);

      // Closing only cancels: a card payment on the same element still goes through.
      await sdk.field(testIds.cardNoInputTestId).clear();
      await sdk.enterCardDetails(stripeCards.successCard);
      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
    },
  );
});

// ── Klarna ─────────────────────────────────────────────────────────────────

test.describe("Klarna popup", () => {
  test.beforeEach(async ({ checkout, credentials, api }) => {
    // Klarna runs on its own "klarna" profile, or on the Stripe profile when that is absent.
    const profileId =
      credentials.profileId(connectorEnum.KLARNA) ??
      credentials.defaultProfileId;
    const opened = await checkout.open({
      body: paymentBody({
        profile_id: profileId,
        customer_id: KLARNA_CUSTOMER,
      }),
    });
    await requireOffered(
      api,
      opened,
      "pay_later",
      "klarna",
      "invoke_sdk_client",
      LIVE_SETUP.klarnaSdkFlow,
    );
  });

  const opensKlarnaWindow = async (
    page: Page,
    sdk: Sdk,
    hermetic: Hermetic,
  ) => {
    const button = klarnaButton(sdk, hermetic);
    await expect(button).toBeVisible({ timeout: 20_000 });
    const popup = await clickForPopup(page, button);
    await popup.waitForURL(/klarna\.(com|net)/, { timeout: 30_000 });
    // on_click put the SDK's payment loader over the page while Klarna is open.
    await expect(page.locator("#orca-fullscreen")).toBeVisible();
    return popup;
  };

  // Live: real Klarna Payments JS and purchase popup. Needs Klarna with invoke_sdk_client.
  test(
    "Klarna button opens the Klarna window",
    { tag: "@live" },
    async ({ page, sdk, hermetic }) => {
      await opensKlarnaWindow(page, sdk, hermetic);
    },
  );

  test(
    "closing the Klarna popup returns the element to a usable state",
    { tag: "@live" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensKlarnaWindow(page, sdk, hermetic);
      await closePopup(popup);
      await expectLoaderGone(page, sdk);
      await expectCardFormUsable(sdk);
    },
  );

  test(
    "Klarna button opens the Klarna window (hermetic: stand-in Klarna JS)",
    { tag: "@hermetic-only" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensKlarnaWindow(page, sdk, hermetic);
      // The SDK initialised Klarna with the client token from the session-tokens response.
      await expect(popup).toHaveURL(
        /client_token=hermetic-klarna-client-token/,
      );
      await expect(popup.getByText("Pay later with Klarna")).toBeVisible();
    },
  );

  test(
    "closing the Klarna popup returns the element to a usable state (hermetic: stand-in Klarna JS)",
    { tag: "@hermetic-only" },
    async ({ page, sdk, hermetic }) => {
      const popup = await opensKlarnaWindow(page, sdk, hermetic);
      await closePopup(popup);
      await expectLoaderGone(page, sdk);
      // Klarna reported approved:false, so the SDK must not have confirmed anything.
      expect(hermetic.calls("confirm")).toHaveLength(0);
      await expectCardFormUsable(sdk);

      const again = await clickForPopup(page, klarnaButton(sdk, hermetic));
      await again.waitForURL(/klarna\.com/);
      await closePopup(again);
      await expectLoaderGone(page, sdk);
    },
  );
});

// ── Plaid ──────────────────────────────────────────────────────────────────

test.describe("Plaid (open banking) window", () => {
  test.beforeEach(async ({ checkout, credentials, api }) => {
    // A Plaid profile, once setup/merchant-setup.js provisions one; the Stripe profile until then.
    const profileId =
      credentials.profileId(connectorEnum.PLAID) ??
      credentials.defaultProfileId;
    const opened = await checkout.open({
      body: paymentBody({ profile_id: profileId, customer_id: PLAID_CUSTOMER }),
    });
    await requireOffered(
      api,
      opened,
      "open_banking",
      "open_banking_pis",
      undefined,
      LIVE_SETUP.plaid,
    );
  });

  /** Plaid Link's frame, injected by link-initialize.js into the SDK's plaidSDK fullscreen frame. */
  const plaidLink = (page: Page) =>
    page
      .frameLocator("#orca-fullscreen")
      .locator('iframe[id^="plaid-link-iframe"]');

  const opensPlaidLink = async (page: Page, sdk: Sdk) => {
    await sdk.selectPaymentMethodOrSkip("Open Banking");
    await sdk.submit();
    await expect(page.locator("#orca-fullscreen")).toBeVisible({
      timeout: 30_000,
    });
    await expect(plaidLink(page).first()).toBeVisible({ timeout: 30_000 });
    return page
      .frameLocator("#orca-fullscreen")
      .frameLocator('iframe[id^="plaid-link-iframe"]');
  };

  // Live: real Plaid Link. Needs a Plaid open-banking connector on the profile.
  test(
    "Pay by bank opens the Plaid Link window",
    { tag: "@live" },
    async ({ page, sdk }) => {
      await opensPlaidLink(page, sdk);
      await expect(plaidLink(page).first()).toHaveAttribute(
        "src",
        /cdn\.plaid\.com\/link\//,
      );
    },
  );

  test(
    "closing Plaid Link returns the element to a usable state",
    { tag: "@live" },
    async ({ page, sdk }) => {
      const link = await opensPlaidLink(page, sdk);
      // Real Link: the close (X) button, then "Exit" on its are-you-sure pane when shown.
      await link
        .getByRole("button", { name: /close|exit/i })
        .first()
        .click();
      const exit = link.getByRole("button", { name: /^exit/i });
      if (await exit.isVisible().catch(() => false)) await exit.click();
      await expectLoaderGone(page, sdk);
      await sdk.selectPaymentMethod("Card");
      await expectCardFormUsable(sdk);
    },
  );

  test(
    "Pay by bank opens the Plaid Link window (hermetic: stand-in Plaid Link JS)",
    { tag: "@hermetic-only" },
    async ({ page, sdk, hermetic }) => {
      const link = await opensPlaidLink(page, sdk);
      const confirm = await hermetic.waitForCall("confirm");
      expect(confirm?.requestBody).toMatchObject({
        payment_method: "open_banking",
        payment_method_type: "open_banking_pis",
        payment_method_data: { open_banking: { open_banking_pis: {} } },
      });
      // Link was created with the link token from the confirm next_action.
      await expect(plaidLink(page).first()).toHaveAttribute(
        "src",
        /token=link-sandbox-hermetic-0000/,
      );
      await expect(
        link.getByRole("dialog", { name: "Plaid Link" }),
      ).toBeVisible();
    },
  );

  test(
    "closing Plaid Link returns the element to a usable state (hermetic: stand-in Plaid Link JS)",
    { tag: "@hermetic-only" },
    async ({ page, sdk, hermetic }) => {
      const link = await opensPlaidLink(page, sdk);
      await link.getByRole("button", { name: "Close" }).click();

      // onExit: the SDK force-syncs the payment and resolves confirmPayment with its status.
      await expect
        .poll(() => hermetic.calls(/force_sync=true/).length)
        .toBeGreaterThan(0);
      await expectLoaderGone(page, sdk);
      await expect(page.locator("#payment-message")).toHaveText(
        "Customer needs to take further action.",
      );
      await sdk.selectPaymentMethod("Card");
      await expectCardFormUsable(sdk);
    },
  );
});
