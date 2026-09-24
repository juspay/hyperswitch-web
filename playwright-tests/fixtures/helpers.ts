// ---------------------------------------------------------------------------
// Spec helpers shared by more than one e2e group (re-exported from fixtures/index.ts).
//
//   Card entry + confirm   typeCard, waitForConfirm, expectConfirmedWith, slowConfirm
//   Redirect flows         submitAndCaptureConfirm, payAndCaptureConfirm, expectConfirmRequest,
//                          expectRedirectedTo, expectRedirectedToNextAction
//   Page checks            expectCheckoutTitle, expectPaymentElementLoaded, captureConsoleErrors
//
// Every `hermetic`-only check is a no-op on the live projects, so a spec can call
// these unconditionally.
// ---------------------------------------------------------------------------
import { expect, type Page, type Response } from "@playwright/test";
import { CLIENT_BASE_URL } from "./env";
import { testIds } from "./test-ids";
import type { CardDetails } from "./cards";
import type { Hermetic } from "./hermetic";
import { PAYMENT_ELEMENT_IFRAME, type Sdk } from "./sdk";

const DEMO_SHOP_ORIGIN = new URL(CLIENT_BASE_URL).origin;

// ── Card entry + confirm ────────────────────────────────────────────────────

/**
 * Types card number, expiry month, expiry year and CVC key by key, one field
 * at a time, without clearing. (`sdk.enterCardDetails()` clears each field
 * first and types the expiry in one go.)
 */
export async function typeCard(sdk: Sdk, card: CardDetails): Promise<void> {
  await sdk.type(testIds.cardNoInputTestId, card.cardNo);
  await sdk.type(testIds.expiryInputTestId, card.card_exp_month);
  await sdk.type(testIds.expiryInputTestId, card.card_exp_year);
  await sdk.type(testIds.cardCVVInputTestId, card.cvc);
}

/** True for the SDK's POST /payments/:id/confirm response. */
export const isConfirmResponse = (r: Response): boolean =>
  r.request().method() === "POST" &&
  /\/payments\/[^/]+\/confirm$/.test(new URL(r.url()).pathname);

/** Resolves with the SDK's POST /payments/:id/confirm response (both tiers). Start it before submitting. */
export function waitForConfirm(
  page: Page,
  { timeout = 30_000 } = {},
): Promise<Response> {
  return page.waitForResponse(isConfirmResponse, { timeout });
}

/**
 * Hermetic only (no-op live): the confirm request carried every `fragment`
 * (whitespace stripped, e.g. a typed card number, or `"card_cvc":"1234"`), so a
 * synthetic router answer can't hide the SDK sending the wrong thing.
 */
export async function expectConfirmedWith(
  hermetic: Hermetic,
  ...fragments: string[]
): Promise<void> {
  if (!hermetic.enabled) return;
  const confirm = await hermetic.waitForCall("confirm");
  const sent = JSON.stringify(confirm?.requestBody);
  for (const f of fragments) expect(sent).toContain(f.replace(/\s/g, ""));
}

/**
 * Hermetic only (no-op live): hold the confirm response for `ms`, so the
 * "processing" state (disabled Pay button) is observable as it is against a
 * real router.
 */
export const slowConfirm = (hermetic: Hermetic, ms: number): Hermetic =>
  hermetic.override("confirm", (route) => ({ ...route, delayMs: ms }));

// ── Redirect flows ──────────────────────────────────────────────────────────
//
// The split between the tiers:
//   - SDK side (both tiers): the payment method is offered and selectable, the
//     submit sends the right confirm body, and the browser leaves the demo shop
//     for the connector's host.
//   - Hermetic extra: the SDK navigated to exactly the fixture's
//     next_action.redirect_to_url, and that page was requested.
//   - Live only: anything that looks at the real third-party page.

/** A confirm call as the browser made it. */
export interface ConfirmExchange {
  /** Parsed JSON request body the SDK sent. */
  request: any; // eslint-disable-line @typescript-eslint/no-explicit-any
  /** HTTP status of the router's answer. */
  status: number;
  /** Parsed JSON response body (undefined if the browser discarded it). */
  body: any; // eslint-disable-line @typescript-eslint/no-explicit-any
}

/**
 * Runs `submit` and returns the confirm call it triggers. Works in both tiers:
 * the request comes from the browser, the response body from the browser (live)
 * or from the hermetic engine's call log (hermetic).
 */
export async function submitAndCaptureConfirm(
  page: Page,
  hermetic: Hermetic,
  submit: () => Promise<void>,
  { timeout = 30_000 } = {},
): Promise<ConfirmExchange> {
  let bodyPromise: Promise<unknown> = Promise.resolve(undefined);
  const responsePromise = page.waitForResponse(
    (r) => {
      if (!isConfirmResponse(r)) return false;
      // Start reading right away: the SDK navigates the page as soon as it has
      // parsed the answer, after which the browser may drop the body.
      bodyPromise = r.json().catch(() => undefined);
      return true;
    },
    { timeout },
  );
  await submit();
  const response = await responsePromise;
  const request = response.request().postDataJSON();
  let body = await bodyPromise;
  if (hermetic.enabled) {
    const call = await hermetic.waitForCall("confirm");
    body ??= call?.responseBody;
  }
  return { request, status: response.status(), body };
}

/** Clicks the demo shop's "Pay now" and returns the confirm call. */
export async function payAndCaptureConfirm(
  page: Page,
  sdk: Sdk,
  hermetic: Hermetic,
): Promise<ConfirmExchange> {
  return submitAndCaptureConfirm(page, hermetic, () => sdk.submit());
}

/**
 * The confirm body carried this payment method. `payment_method_data` is matched
 * partially (toMatchObject): on live the SDK may add superposition-driven fields
 * (e.g. payment_method_data.billing) next to the method's own entry.
 */
export function expectConfirmRequest(
  confirm: ConfirmExchange,
  expected: {
    payment_method: string;
    payment_method_type: string;
    payment_method_data?: unknown;
  },
): void {
  expect(confirm.request.payment_method).toBe(expected.payment_method);
  expect(confirm.request.payment_method_type).toBe(
    expected.payment_method_type,
  );
  if ("payment_method_data" in expected) {
    expect(confirm.request.payment_method_data).toMatchObject(
      expected.payment_method_data as Record<string, unknown>,
    );
  }
}

/**
 * Waits for the browser to leave the demo shop for a URL matching `urlPattern`.
 * `urlPattern` holds on both tiers (hermetic fixtures redirect to the same host). URLs on the
 * demo shop never count: its query string carries the profile id, which in
 * hermetic mode is e.g. `pro_hermetic_adyen` and would satisfy /adyen/ before
 * any redirect. In hermetic mode it additionally checks the SDK navigated to
 * exactly the fixture's next_action.redirect_to_url and that the fixture's
 * `redirectPage` route served it.
 */
export async function expectRedirectedTo(
  page: Page,
  hermetic: Hermetic,
  urlPattern: RegExp,
  confirm?: ConfirmExchange,
  { timeout = 30_000 } = {},
): Promise<void> {
  await page.waitForURL(
    (url) => url.origin !== DEMO_SHOP_ORIGIN && urlPattern.test(url.href),
    {
      timeout,
      waitUntil: "commit",
    },
  );
  if (hermetic.enabled) {
    const redirectUrl = confirm?.body?.next_action?.redirect_to_url;
    expect(
      redirectUrl,
      "hermetic confirm fixture returns next_action.redirect_to_url",
    ).toEqual(expect.any(String));
    await expect(page).toHaveURL(redirectUrl);
    await hermetic.waitForCall("redirectPage");
  }
}

/**
 * Hermetic only (no-op live): the confirm response asked for a redirect and the
 * SDK navigated the top-level page to exactly that `next_action.redirect_to_url`
 * (served by a fixture route or by the blank-document stub; both are in the call log).
 */
export async function expectRedirectedToNextAction(
  hermetic: Hermetic,
): Promise<void> {
  if (!hermetic.enabled) return;
  const confirm = await hermetic.waitForCall("confirm");
  const body = confirm?.responseBody as {
    status?: string;
    next_action?: { redirect_to_url?: string };
  };
  expect(body?.status).toBe("requires_customer_action");
  const redirectUrl = body?.next_action?.redirect_to_url;
  expect(
    redirectUrl,
    "fixture confirm has next_action.redirect_to_url",
  ).toBeTruthy();
  await expect
    .poll(() => hermetic.calls(/^GET /).some((c) => c.url === redirectUrl), {
      message: `SDK navigated to ${redirectUrl}`,
      timeout: 15_000,
    })
    .toBe(true);
}

// ── Page checks ─────────────────────────────────────────────────────────────

/** The demo shop's "Hyperswitch Unified Checkout" heading is visible. */
export async function expectCheckoutTitle(page: Page): Promise<void> {
  await expect(page.getByText("Hyperswitch Unified Checkout")).toBeVisible();
}

/** The payment element iframe is visible and its document has a body. */
export async function expectPaymentElementLoaded(
  page: Page,
  sdk: Sdk,
): Promise<void> {
  await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();
  await expect(sdk.paymentElement.locator("body")).toBeAttached();
}

declare global {
  interface Window {
    __pwConsoleErrors?: string[];
  }
}

/**
 * Wraps `console.error` in the top window: records every explicit
 * `console.error(...)` call made by page JavaScript (HyperLoader, the demo
 * shop) in the top-level document. Unlike `page.on("console")` it does not see
 * browser-generated messages ("Failed to load resource", SRI mismatches of
 * stubbed third-party scripts) or iframe logs, so an assertion on it only
 * fails on errors the SDK or merchant page actually reported. Call before
 * `page.goto()`.
 */
export async function captureConsoleErrors(
  page: Page,
): Promise<() => Promise<string[]>> {
  await page.addInitScript(() => {
    if (window !== window.top) return;
    const errors: string[] = [];
    window.__pwConsoleErrors = errors;
    const original = console.error.bind(console);
    console.error = (...args: unknown[]) => {
      errors.push(
        args
          .map((a) =>
            a instanceof Error
              ? a.message
              : typeof a === "string"
                ? a
                : JSON.stringify(a),
          )
          .join(" "),
      );
      original(...args);
    };
  });
  return () =>
    page.evaluate(() => [...(window.__pwConsoleErrors ?? [])]).catch(() => []);
}
