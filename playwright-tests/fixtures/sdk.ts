// ---------------------------------------------------------------------------
// Payment-element helpers: frame lookup, card entry, payment method selection,
// overlays and dynamic fields inside the SDK iframes.
//
// Frame layout of the demo shop:
//   page
//   ├─ #orca-payment-element-iframeRef-orca-elements-payment-element-payment-element  (paymentElement)
//   │    payment method tabs/list/dropdown, billing & dynamic fields, saved methods, "Add new card"
//   │  └─ iframe[id^="orca-payment-element-iframeRef-"][src*="componentName=paymentMethodsSDK"]
//   │       (cardFields, the "vault" iframe) card number / expiry / CVC inputs and their
//   │       ".Error.pt-1" messages; saved-card CVC lives in a second such iframe
//   └─ #orca-fullscreen (3DS / QR / voucher overlays)  -> nestedIFrame(selector)
//
// Some elements render in the outer frame or the card frame depending on the
// payment method and layout. Playwright cannot put frame locators inside
// Locator.or(), so:
//   sdk.field(testId)       sync; routes card-input test ids to cardFields, the rest to paymentElement
//   sdk.cardErrors          ".Error.pt-1" inside the card iframe
//   await sdk.locate(sel)   async; resolves a CSS selector in whichever frame has it (either frame)
//   await sdk.locateTestId(id)  same for a data-testid
// ---------------------------------------------------------------------------
import {
  expect,
  test,
  type FrameLocator,
  type Locator,
  type Page,
} from "@playwright/test";
import type { CardDetails } from "./cards";
import type { CustomerData } from "./types";
import { testIds } from "./test-ids";

export const PAYMENT_ELEMENT_IFRAME =
  "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
export const CARD_FIELDS_IFRAME =
  'iframe[id^="orca-payment-element-iframeRef-"][src*="componentName=paymentMethodsSDK"]';
export const FULLSCREEN_IFRAME = "#orca-fullscreen";

/** Display name -> <select data-testid="paymentMethodsSelect"> option value. */
export const PAYMENT_METHOD_SELECT_VALUES: Record<string, string> = {
  iDEAL: "ideal",
  EPS: "eps",
  Blik: "blik",
  Interac: "interac",
  Mifinity: "mifinity",
  Crypto: "crypto_currency",
  "Cash / Voucher": "classic",
  "E-Voucher": "evoucher",
  AlipayHK: "ali_pay_hk",
  DuitNow: "duit_now",
  "Bancontact Card": "bancontact_card",
  "SEPA Bank Transfer": "sepa_bank_transfer",
  "Online Banking Fpx": "online_banking_fpx",
  "Pay by Bank": "open_banking_uk",
  Klarna: "klarna",
  Trustly: "trustly",
  Card: "card",
};

export const PAYMENT_METHOD_WAIT_MS = 15_000;

/** data-testids rendered inside the card ("vault") iframe rather than the outer payment element. */
export const CARD_FRAME_TEST_IDS: ReadonlySet<string> = new Set([
  testIds.cardNoInputTestId,
  testIds.expiryInputTestId,
  testIds.cardCVVInputTestId,
]);

export interface SelectOrSkipOptions {
  /** How long to wait for the method to be offered before skipping. Default 15 s. */
  timeout?: number;
  /** Called before skipping, e.g. to log the payment_methods_enabled the router returned. */
  onMissing?: (visibleText: string) => Promise<void> | void;
}

export class Sdk {
  /** Outer payment element iframe. */
  readonly paymentElement: FrameLocator;
  /** Inner card-fields iframe (card number / expiry / CVC live here). */
  readonly cardFields: FrameLocator;

  /**
   * @param debugPaymentMethods optional: returns a one-line summary of the router's
   *   payment_methods_enabled, logged when selectPaymentMethodOrSkip() skips
   *   (wired by the `sdk` fixture).
   */
  constructor(
    readonly page: Page,
    private readonly debugPaymentMethods?: () => Promise<string>,
  ) {
    this.paymentElement = page.frameLocator(PAYMENT_ELEMENT_IFRAME);
    // First *visible* inner iframe: the new-card form, or the saved-card CVC
    // iframe when the saved-methods screen is showing.
    this.cardFields = this.paymentElement
      .locator(CARD_FIELDS_IFRAME)
      .filter({ visible: true })
      .first()
      .contentFrame();
  }

  // ── Lookup ───────────────────────────────────────────────────────────────

  /**
   * Element with data-testid=`testId`. Card number/expiry/CVC resolve in the
   * card iframe, everything else in the outer payment element. Use
   * `locateTestId()` when you don't know which frame renders it.
   */
  field(testId: string): Locator {
    return CARD_FRAME_TEST_IDS.has(testId)
      ? this.cardFields.getByTestId(testId)
      : this.paymentElement.getByTestId(testId);
  }

  /** CSS selector in the outer payment element. */
  find(selector: string): Locator {
    return this.paymentElement.locator(selector);
  }

  /** CSS selector in the card iframe. */
  findInCard(selector: string): Locator {
    return this.cardFields.locator(selector);
  }

  /** Text in the outer payment element. */
  text(text: string | RegExp, options?: { exact?: boolean }): Locator {
    return this.paymentElement.getByText(text, options);
  }

  /**
   * "Either frame" lookup: polls both frames until one contains
   * `selector` and returns that frame's locator. Falls back to the outer frame
   * after `timeout` so a following assertion fails with a readable message (and
   * `not.toBeVisible()` style assertions still work).
   */
  async locate(selector: string, { timeout = 10_000 } = {}): Promise<Locator> {
    const candidates = [
      this.cardFields.locator(selector),
      this.paymentElement.locator(selector),
    ];
    const deadline = Date.now() + timeout;
    for (;;) {
      for (const c of candidates) {
        if ((await c.count().catch(() => 0)) > 0) return c;
      }
      if (Date.now() >= deadline) return candidates[1];
      await new Promise((r) => setTimeout(r, 100));
    }
  }

  /** `locate()` for a data-testid. */
  async locateTestId(
    testId: string,
    opts?: { timeout?: number },
  ): Promise<Locator> {
    return this.locate(`[data-testid="${testId}"]`, opts);
  }

  /** Card-field validation messages (".Error.pt-1" inside the card iframe). */
  get cardErrors(): Locator {
    return this.cardFields.locator(".Error.pt-1");
  }

  /** Validation messages of non-card fields (".Error.pt-1" in the outer frame, e.g. billing). */
  get formErrors(): Locator {
    return this.paymentElement.locator(".Error.pt-1");
  }

  /** The demo shop's "Pay now" button (top-level page, not inside the SDK). */
  get submitButton(): Locator {
    return this.page.locator("#submit");
  }

  // ── Readiness ────────────────────────────────────────────────────────────

  /** Waits until the outer iframe, the inner card iframe and the card number input exist. */
  async waitForReady({ timeout = 15_000 } = {}): Promise<void> {
    await expect(this.page.locator(PAYMENT_ELEMENT_IFRAME)).toBeAttached({
      timeout,
    });
    await expect(
      this.cardFields.getByTestId(testIds.cardNoInputTestId),
    ).toBeAttached({ timeout });
  }

  // ── Typing ───────────────────────────────────────────────────────────────

  /** Types key by key into the field, appending to what is there (no clearing). */
  async type(testId: string, text: string, { delay = 0 } = {}): Promise<void> {
    await this.field(testId).pressSequentially(text, { delay });
  }

  /** Waits until visible and enabled, clears, then types with a 50 ms key delay. */
  async safeType(
    testId: string,
    text: string,
    { delay = 50 } = {},
  ): Promise<void> {
    const f = this.field(testId);
    await expect(f).toBeVisible();
    await expect(f).toBeEnabled();
    await f.clear();
    await f.pressSequentially(text, { delay });
  }

  /** Card number, expiry (MMYY) and CVC, each via safeType() (clears first). */
  async enterCardDetails(card: CardDetails): Promise<void> {
    await this.safeType(testIds.cardNoInputTestId, card.cardNo);
    await this.safeType(
      testIds.expiryInputTestId,
      card.card_exp_month + card.card_exp_year,
    );
    await this.safeType(testIds.cardCVVInputTestId, card.cvc);
  }

  /** Clicks the demo shop's "Pay now" (#submit). */
  async submit(): Promise<void> {
    await this.submitButton.click();
  }

  /** waitForReady() + enterCardDetails() + submit(). Assert the outcome in the test. */
  async payWithCard(card: CardDetails): Promise<void> {
    await this.waitForReady();
    await this.enterCardDetails(card);
    await this.submit();
  }

  // ── Payment method selection ─────────────────────────────────────────────

  /** Clicks "Add new card" if the saved-methods screen is showing. */
  async clickAddNewCardIfPresent(): Promise<boolean> {
    const addNew = this.field(testIds.addNewCardIcon);
    if (await addNew.count()) {
      await addNew.first().click();
      return true;
    }
    return false;
  }

  /**
   * If saved cards are shown, clicks "Add new card" first; then clicks the
   * payment method by its visible name.
   */
  async selectPaymentMethod(methodName: string): Promise<void> {
    await this.clickAddNewCardIfPresent();
    await this.text(methodName).first().click();
  }

  /**
   * Waits up to 15 s for `methodName` to be
   * offered; if it never appears the test is SKIPPED (not failed) with a named
   * reason. When offered, clicks the tab (`button.Tab`) or, when the method sits
   * in the "more" dropdown, selects it in `paymentMethodsSelect` via the
   * display-name -> value map.
   */
  async selectPaymentMethodOrSkip(
    methodName: string,
    opts: SelectOrSkipOptions = {},
  ): Promise<void> {
    const timeout = opts.timeout ?? PAYMENT_METHOD_WAIT_MS;
    await this.clickAddNewCardIfPresent();

    const bodyText = async () => {
      const texts = await Promise.all([
        this.paymentElement
          .locator("body")
          .textContent({ timeout: 1_000 })
          .catch(() => ""),
        this.cardFields
          .locator("body")
          .textContent({ timeout: 1_000 })
          .catch(() => ""),
      ]);
      return texts.map((t) => t ?? "").join(" ");
    };

    let offered = false;
    try {
      await expect
        .poll(async () => (await bodyText()).includes(methodName), {
          timeout,
          intervals: [500],
        })
        .toBe(true);
      offered = true;
    } catch {
      offered = false;
    }

    if (!offered) {
      const visible = (await bodyText())
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 300);
      console.log(
        `[skip] "${methodName}" not found after ${timeout}ms. SDK iframe text: "${visible}"`,
      );
      if (this.debugPaymentMethods) {
        const summary = await this.debugPaymentMethods().catch(
          (e) => `(unavailable: ${e})`,
        );
        console.log(`[debug] payment_methods_enabled: ${summary}`);
      }
      await opts.onMissing?.(visible);
      test.skip(
        true,
        `Payment method "${methodName}" is not offered by the SDK for this profile/amount`,
      );
      return;
    }

    const tab = this.paymentElement
      .locator("button.Tab")
      .filter({ hasText: methodName });
    if (await tab.count()) {
      await this.text(methodName).first().click({ force: true });
      return;
    }
    const value =
      PAYMENT_METHOD_SELECT_VALUES[methodName] ?? methodName.toLowerCase();
    const select = this.field(testIds.paymentMethodDropDownTestId);
    await expect(select).toBeAttached();
    await select.selectOption(value, { force: true });
  }

  // ── Overlays ─────────────────────────────────────────────────────────────

  /** A frame inside #orca-fullscreen (3DS / QR / voucher overlays), once it is visible and has content. */
  async nestedIFrame(
    selector: string,
    { timeout = 15_000 } = {},
  ): Promise<FrameLocator> {
    await expect(this.page.locator(FULLSCREEN_IFRAME)).toBeVisible({ timeout });
    const fullscreen = this.page.frameLocator(FULLSCREEN_IFRAME);
    await expect(fullscreen.locator(selector)).toBeVisible({ timeout });
    const nested = fullscreen.frameLocator(selector);
    await expect(nested.locator("body")).not.toBeEmpty({ timeout });
    return nested;
  }

  // ── Dynamic fields ───────────────────────────────────────────────────────

  /**
   * Fills every field the router lists as required
   * for card/debit (legacy `required_fields` of /account/payment_methods), with
   * State moved after Country. `requiredFields` comes from
   * `api.accountPaymentMethods(clientSecret)` (see fixtures/api.ts).
   */
  async testDynamicFields(
    customerData: CustomerData,
    requiredFields: Record<string, unknown>,
    testIdsToRemove: string[] = [],
    isThreeDSEnabled = false,
  ): Promise<void> {
    const mapping: Record<string, string> = {
      [testIds.cardNoInputTestId]: customerData.cardNo,
      [testIds.expiryInputTestId]: customerData.cardExpiry,
      [testIds.cardCVVInputTestId]: customerData.cardCVV,
      [testIds.fullNameInputTestId]: customerData.cardHolderName,
      [testIds.cardHolderNameInputTestId]: customerData.cardHolderName,
      [testIds.emailInputTestId]: customerData.email,
      [testIds.addressLine1InputTestId]: customerData.address,
      [testIds.cityInputTestId]: customerData.city,
      [testIds.countryDropDownTestId]: customerData.country,
      [testIds.stateDropDownTestId]: customerData.state,
      [testIds.postalCodeInputTestId]: customerData.postalCode,
    };
    if (isThreeDSEnabled)
      mapping[testIds.cardNoInputTestId] = customerData.threeDSCardNo;

    const fieldMap = testIds.fieldTestIdMapping as Record<string, string>;
    let ids = Object.keys(requiredFields)
      .map((k) => fieldMap[k])
      .filter((x): x is string => !!x);
    const countryIndex = ids.indexOf("Country");
    const stateIndex = ids.indexOf("State");
    if (countryIndex !== -1 && stateIndex !== -1 && stateIndex < countryIndex) {
      ids.splice(stateIndex, 1);
      ids.splice(countryIndex, 0, "State");
    }
    ids = [...new Set(ids)].filter((id) => !testIdsToRemove.includes(id));

    for (const id of ids) {
      const f = this.field(id);
      await expect(f).toBeVisible();
      if (id === "Country" || id === "State") {
        await f.selectOption(mapping[id]);
      } else {
        await f.pressSequentially(mapping[id] ?? "");
      }
    }
  }
}
